package com.level30.api.service;

import com.level30.api.domain.model.Challenge;
import com.level30.api.dto.response.ChallengeResponse;
import com.level30.api.dto.response.ReplanSugestaoResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.ChallengeRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * C2 · Replanejamento assistido por IA (F2). Ativa o caminho
 * {@code SuggestedAction.SUGGEST_REPLAN}, que ate agora era testado e nunca executado.
 *
 * <p>Regras: no maximo 2 replanejamentos por desafio; a nova duracao fica entre
 * {@code max(7, currentDay+1)} e 90; o {@code xpReward} e recalculado
 * proporcionalmente <b>arredondado pra baixo</b> (mantem o XP-por-dia constante).
 */
@Service
public class ReplanService {

    static final int MAX_REPLANS = 2;

    private final ChallengeRepository challenges;
    private final RiskMaterializationService risk;
    private final AiGatewayService ai;

    public ReplanService(ChallengeRepository challenges, RiskMaterializationService risk,
                         AiGatewayService ai) {
        this.challenges = challenges;
        this.risk = risk;
        this.ai = ai;
    }

    @Transactional(readOnly = true)
    public ReplanSugestaoResponse sugestao(UUID userId, UUID challengeId) {
        Challenge c = owned(userId, challengeId);
        int sugestao = sugerirDias(c);
        var texto = ai.replanText(c, sugestao);
        return new ReplanSugestaoResponse(
                c.getTotalDays(),
                c.getCurrentDay(),
                sugestao,
                Math.max(7, c.getCurrentDay() + 1),
                90,
                Math.max(0, MAX_REPLANS - c.getReplanCount()),
                texto.message(),
                texto.aiGenerated());
    }

    @Transactional
    public ChallengeResponse aplicar(UUID userId, UUID challengeId, int novosDias) {
        Challenge c = owned(userId, challengeId);

        if (c.getReplanCount() >= MAX_REPLANS) {
            throw new RegraNegocioException("Voce ja replanejou este desafio 2 vezes.");
        }
        if (c.isCompleted()) {
            throw new RegraNegocioException("Desafio ja concluido.");
        }
        if (novosDias < 7 || novosDias > 90) {
            throw new RegraNegocioException("A duracao deve ficar entre 7 e 90 dias.");
        }
        if (novosDias <= c.getCurrentDay()) {
            throw new RegraNegocioException(
                    "A nova duracao precisa ser maior que os dias ja concluidos.");
        }

        long novoXp = Math.clamp(
                (long) c.getXpReward() * novosDias / c.getTotalDays(), 100, 1000);
        c.setXpReward((int) novoXp);
        c.setTotalDays(novosDias);
        c.setReplanCount(c.getReplanCount() + 1);

        risk.refresh(c);
        challenges.save(c);
        return ChallengeResponse.from(c);
    }

    private int sugerirDias(Challenge c) {
        int restantes = Math.max(1, c.getTotalDays() - c.getCurrentDay());
        int extra = Math.max(7, (int) Math.ceil(restantes * 0.5));
        return Math.min(90, c.getTotalDays() + extra);
    }

    private Challenge owned(UUID userId, UUID challengeId) {
        return challenges.findByIdAndUserId(challengeId, userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Desafio nao encontrado."));
    }
}
