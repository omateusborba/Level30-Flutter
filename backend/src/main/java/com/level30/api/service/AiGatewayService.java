package com.level30.api.service;

import com.level30.api.domain.engine.RiskEngine;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.request.ChatRequest;
import com.level30.api.dto.response.ChatResponse;
import com.level30.api.dto.response.RecommendationResponse;
import com.level30.api.exception.AiIndisponivelException;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Ponte para o Cloudflare Worker, que continua sendo o único caminho até o Workers AI
 * (só acessível de dentro do runtime da Cloudflare).
 *
 * <p>Quando {@code app.ai.worker-url} está vazio (dev/test/CI), opera em <b>modo fallback</b>:
 * a recomendação usa a mensagem determinística do {@link RiskEngine}; o chat responde 502.
 * O racional de manter o Worker como gateway está documentado em
 * {@code specs/003-fase-5/backlog-po.md} (US-009).
 */
@Service
public class AiGatewayService {

    private static final Logger log = LoggerFactory.getLogger(AiGatewayService.class);
    private static final Set<Integer> MILESTONES = Set.of(7, 14, 21, 30);

    private final RiskEngine riskEngine;
    private final String workerUrl;
    private final String serviceToken;
    private final RestClient restClient;

    public AiGatewayService(RiskEngine riskEngine,
                            @Value("${app.ai.worker-url:}") String workerUrl,
                            @Value("${app.ai.service-token:}") String serviceToken,
                            @Value("${app.ai.timeout-seconds:15}") long timeoutSeconds) {
        this.riskEngine = riskEngine;
        this.workerUrl = workerUrl == null ? "" : workerUrl.trim();
        this.serviceToken = serviceToken == null ? "" : serviceToken.trim();

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(5));
        factory.setReadTimeout(Duration.ofSeconds(timeoutSeconds));
        this.restClient = RestClient.builder().requestFactory(factory).build();
    }

    private boolean gatewayConfigured() {
        return !workerUrl.isEmpty();
    }

    public RecommendationResponse recommendation(Challenge c) {
        double score = riskEngine.calculateScore(c);
        RiskLevel level = riskEngine.scoreToLevel(score);

        if (gatewayConfigured()) {
            try {
                Map<?, ?> body = restClient.post()
                        .uri(workerUrl + "/internal/recommendation")
                        .header("X-Service-Token", serviceToken)
                        .body(Map.of(
                                "title", c.getTitle(),
                                "category", c.getCategory().toJson(),
                                "currentDay", c.getCurrentDay(),
                                "totalDays", c.getTotalDays(),
                                "streak", c.getStreak(),
                                "riskLevel", level.toJson()))
                        .retrieve()
                        .body(Map.class);
                Object message = body == null ? null : body.get("message");
                if (message instanceof String s && !s.isBlank()) {
                    return new RecommendationResponse(s.trim(), score, level, true);
                }
                log.warn("Gateway de IA respondeu sem 'message'; caindo no fallback.");
            } catch (Exception ex) {
                log.warn("Gateway de IA falhou em /recommendation: {}", ex.getMessage());
            }
        }
        return new RecommendationResponse(fallbackMessage(c, level), score, level, false);
    }

    public record AiText(String message, boolean aiGenerated) {}

    /** C2 — frase de apoio ao replanejamento. Nunca lança: cai no texto determinístico. */
    public AiText replanText(Challenge c, int novosDias) {
        String fallback = "Sem pressa — estender \"" + c.getTitle() + "\" para " + novosDias
                + " dias te dá fôlego pra retomar o ritmo. O que importa e nao parar.";
        if (!gatewayConfigured()) {
            return new AiText(fallback, false);
        }
        try {
            Map<?, ?> body = restClient.post()
                    .uri(workerUrl + "/internal/chat")
                    .header("X-Service-Token", serviceToken)
                    .body(Map.of(
                            "system", "Voce e o Guia do Level30, um mentor de habitos. "
                                    + "Responda em 1 ou 2 frases, tom encorajador, em portugues do Brasil.",
                            "message", "O aluno esta no dia " + c.getCurrentDay() + " de "
                                    + c.getTotalDays() + " do desafio \"" + c.getTitle()
                                    + "\" e quer replanejar para " + novosDias
                                    + " dias. Escreva uma mensagem curta apoiando essa decisao.",
                            "history", List.of()))
                    .retrieve()
                    .body(Map.class);
            Object message = body == null ? null : body.get("message");
            if (message instanceof String s && !s.isBlank()) {
                return new AiText(s.trim(), true);
            }
        } catch (Exception ex) {
            log.warn("Gateway de IA falhou em replanText: {}", ex.getMessage());
        }
        return new AiText(fallback, false);
    }

    public ChatResponse chat(String systemContext, ChatRequest req) {
        if (!gatewayConfigured()) {
            throw new AiIndisponivelException("Assistente indisponivel no momento. Tente novamente.");
        }
        try {
            List<Map<String, String>> history = (req.history() == null ? List.<ChatRequest.Turn>of() : req.history())
                    .stream()
                    .filter(t -> t != null && t.role() != null && t.content() != null)
                    .filter(t -> t.role().equals("user") || t.role().equals("assistant"))
                    .map(t -> Map.of("role", t.role(), "content", t.content()))
                    .toList();

            Map<?, ?> body = restClient.post()
                    .uri(workerUrl + "/internal/chat")
                    .header("X-Service-Token", serviceToken)
                    .body(Map.of(
                            "system", systemContext,
                            "message", req.message().trim(),
                            "history", history))
                    .retrieve()
                    .body(Map.class);

            Object message = body == null ? null : body.get("message");
            if (message instanceof String s && !s.isBlank()) {
                return new ChatResponse(s.trim());
            }
            throw new AiIndisponivelException("Resposta vazia do assistente.");
        } catch (AiIndisponivelException ex) {
            throw ex;
        } catch (Exception ex) {
            log.warn("Gateway de IA falhou em /chat: {}", ex.getMessage());
            throw new AiIndisponivelException("Nao consegui responder agora. Tente novamente.");
        }
    }

    private String fallbackMessage(Challenge c, RiskLevel level) {
        if (MILESTONES.contains(c.getCurrentDay())) {
            return "Marco atingido! Voce e incrivel!";
        }
        return switch (level) {
            case LOW -> "Continue assim! Voce esta indo muito bem.";
            case MEDIUM -> "Nao esqueca do seu desafio de hoje!";
            case HIGH -> "Voce chegou ate aqui - nao desista agora!";
            case CRITICAL -> "Que tal reajustar o ritmo? Recomecar e vencer.";
        };
    }
}
