package com.level30.api.service;

import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.User;
import com.level30.api.dto.request.ChallengeRequest;
import com.level30.api.dto.response.ChallengeResponse;
import com.level30.api.dto.response.CompleteResponse;
import com.level30.api.dto.response.RecommendationResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChallengeService {

    /** Fuso do produto — a virada de "dia" acontece à meia-noite de São Paulo, não em UTC. */
    static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    private final ChallengeRepository challenges;
    private final UserRepository users;
    private final AiGatewayService aiGateway;

    public ChallengeService(ChallengeRepository challenges, UserRepository users,
                            AiGatewayService aiGateway) {
        this.challenges = challenges;
        this.users = users;
        this.aiGateway = aiGateway;
    }

    @Transactional(readOnly = true)
    public List<ChallengeResponse> listForUser(UUID userId) {
        return challenges.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(ChallengeResponse::from)
                .toList();
    }

    @Transactional
    public ChallengeResponse create(UUID userId, ChallengeRequest req) {
        User user = users.findById(userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Usuario nao encontrado."));
        Challenge challenge = Challenge.create(
                user,
                req.title().trim(),
                req.category(),
                req.description().trim(),
                req.totalDays(),
                req.xpReward()
        );
        challenges.save(challenge);
        return ChallengeResponse.from(challenge);
    }

    @Transactional
    public CompleteResponse completeDay(UUID userId, UUID challengeId) {
        Challenge c = ownedOrNotFound(userId, challengeId);

        if (c.isCompleted()) {
            throw new RegraNegocioException("Desafio ja concluido.");
        }

        Instant now = Instant.now();
        LocalDate hoje = LocalDate.now(ZONE);

        if (c.getLastActivityAt() != null) {
            LocalDate ultima = LocalDate.ofInstant(c.getLastActivityAt(), ZONE);
            if (ultima.isEqual(hoje)) {
                throw new RegraNegocioException(
                        "Voce ja concluiu este desafio hoje.", HttpStatus.CONFLICT);
            }
        }

        int xpBefore = c.earnedXp();
        c.setCurrentDay(c.getCurrentDay() + 1);
        c.setStreak(nextStreak(c, hoje));
        c.setLastActivityAt(now);
        int xpAfter = c.earnedXp();
        int xpDelta = xpAfter - xpBefore;

        User user = c.getUser();
        user.setTotalXp(user.getTotalXp() + xpDelta);

        // Ambas as escritas fecham na mesma transação (@Transactional).
        challenges.save(c);
        users.save(user);

        return new CompleteResponse(ChallengeResponse.from(c), xpDelta, user.getTotalXp());
    }

    @Transactional
    public void delete(UUID userId, UUID challengeId) {
        Challenge c = ownedOrNotFound(userId, challengeId);
        challenges.delete(c);
    }

    @Transactional(readOnly = true)
    public RecommendationResponse recommendation(UUID userId, UUID challengeId) {
        Challenge c = ownedOrNotFound(userId, challengeId);
        return aiGateway.recommendation(c);
    }

    /**
     * Regra de streak (corrige o backend antigo, que sempre incrementava):
     * <ul>
     *   <li>sem atividade anterior → 1</li>
     *   <li>última atividade = ontem → streak + 1</li>
     *   <li>última atividade ≥ 2 dias atrás → 1 (reinicia)</li>
     * </ul>
     * O caso "mesmo dia" já foi barrado com 409 antes daqui.
     */
    private int nextStreak(Challenge c, LocalDate hoje) {
        if (c.getLastActivityAt() == null) {
            return 1;
        }
        LocalDate ultima = LocalDate.ofInstant(c.getLastActivityAt(), ZONE);
        long dias = ChronoUnit.DAYS.between(ultima, hoje);
        return dias == 1 ? c.getStreak() + 1 : 1;
    }

    private Challenge ownedOrNotFound(UUID userId, UUID challengeId) {
        return challenges.findByIdAndUserId(challengeId, userId)
                .orElseThrow(() -> new RecursoNaoEncontradoException("Desafio nao encontrado."));
    }
}
