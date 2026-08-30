package com.level30.api.config;

import com.level30.api.repository.ChallengeRepository;
import com.level30.api.service.RiskMaterializationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * B1 · No primeiro boot após a V6, calcula {@code risk_score/risk_level} dos
 * desafios que ainda estão com o default. No-op quando todos já têm risco.
 */
@Component
@Order(30) // depois do DataSeeder (20) e do CompletionBackfill
public class RiskBackfill implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(RiskBackfill.class);

    private final ChallengeRepository challenges;
    private final RiskMaterializationService risk;

    public RiskBackfill(ChallengeRepository challenges, RiskMaterializationService risk) {
        this.challenges = challenges;
        this.risk = risk;
    }

    @Override
    public void run(String... args) {
        if (challenges.existsByRiskUpdatedAtIsNull()) {
            log.info("RiskBackfill: materializando risco dos desafios existentes...");
            risk.recomputeAll();
        }
    }
}
