package com.level30.api.service;

import com.level30.api.domain.engine.RiskEngine;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.domain.model.RiskSnapshot;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.RiskSnapshotRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * B1 — mantém {@code challenges.risk_score / risk_level} em dia. O {@link RiskEngine}
 * continua sendo a única fonte da fórmula; aqui só gravamos o resultado.
 *
 * <ul>
 *   <li>{@link #refresh(Challenge)} — na transação de {@code create}/{@code completeDay}.</li>
 *   <li>{@link #recomputeAll()} — job diário: o risco cresce com o tempo mesmo sem
 *       ação do usuário, e grava o snapshot da distribuição do dia.</li>
 * </ul>
 */
@Service
public class RiskMaterializationService {

    private static final Logger log = LoggerFactory.getLogger(RiskMaterializationService.class);

    private final RiskEngine engine;
    private final ChallengeRepository challenges;
    private final RiskSnapshotRepository snapshots;

    public RiskMaterializationService(RiskEngine engine, ChallengeRepository challenges,
                                      RiskSnapshotRepository snapshots) {
        this.engine = engine;
        this.challenges = challenges;
        this.snapshots = snapshots;
    }

    /** Atualiza o risco de um desafio na entidade gerenciada (o flush vem com a tx do chamador). */
    public void refresh(Challenge c) {
        double score = engine.calculateScore(c);
        c.setRiskScore(round3(score));
        c.setRiskLevel(engine.scoreToLevel(score));
        c.setRiskUpdatedAt(Instant.now());
    }

    @Scheduled(cron = "0 5 0 * * *")
    @Transactional
    public void recomputeAll() {
        List<Challenge> all = challenges.findAll();
        Map<RiskLevel, Integer> dist = new EnumMap<>(RiskLevel.class);
        for (Challenge c : all) {
            refresh(c);
            if (!c.isCompleted()) {
                dist.merge(c.getRiskLevel(), 1, Integer::sum);
            }
        }
        challenges.saveAll(all);

        LocalDate hoje = LocalDate.now(ChallengeService.ZONE);
        RiskSnapshot snap = snapshots.findById(hoje).orElseGet(RiskSnapshot::new);
        snap.setSnapshotOn(hoje);
        snap.apply(dist);
        snapshots.save(snap);
        log.info("Risco recalculado para {} desafios; snapshot {} gravado.", all.size(), hoje);
    }

    static double round3(double v) {
        return Math.round(v * 1000.0) / 1000.0;
    }
}
