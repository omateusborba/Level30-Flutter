package com.level30.api.service;

import com.level30.api.domain.Leveling;
import com.level30.api.domain.engine.RiskEngine;
import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.response.AdminChallengeResponse;
import com.level30.api.dto.response.AdminUserResponse;
import com.level30.api.dto.response.IndicadoresResponse;
import com.level30.api.dto.response.IndicadoresResponse.ContagemPorChave;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Consultas do painel administrativo. O nível de risco não é persistido —
 * é recalculado pelo {@link RiskEngine} sobre o conjunto (tamanho de seed),
 * então a filtragem/agregação por risco acontece em memória, de propósito.
 */
@Service
@Transactional(readOnly = true)
public class AdminService {

    private final UserRepository users;
    private final ChallengeRepository challenges;
    private final RiskEngine riskEngine;

    public AdminService(UserRepository users, ChallengeRepository challenges, RiskEngine riskEngine) {
        this.users = users;
        this.challenges = challenges;
        this.riskEngine = riskEngine;
    }

    public Page<AdminUserResponse> usuarios(Pageable pageable) {
        return users.findAll(pageable).map(u -> new AdminUserResponse(
                u.getId().toString(),
                u.getName(),
                u.getEmail(),
                u.getTotalXp(),
                Leveling.level(u.getTotalXp()),
                Leveling.rank(u.getTotalXp()),
                challenges.countByUserId(u.getId())
        ));
    }

    public Page<AdminChallengeResponse> desafios(RiskLevel riskLevel, Category category, Pageable pageable) {
        List<AdminChallengeResponse> all = challenges.findAll().stream()
                .filter(c -> category == null || c.getCategory() == category)
                .map(this::toAdminChallenge)
                .filter(r -> riskLevel == null || r.riskLevel() == riskLevel)
                .sorted(Comparator.comparingDouble(AdminChallengeResponse::riskScore).reversed())
                .toList();

        int from = (int) Math.min(pageable.getOffset(), all.size());
        int to = Math.min(from + pageable.getPageSize(), all.size());
        return new PageImpl<>(all.subList(from, to), pageable, all.size());
    }

    public IndicadoresResponse indicadores() {
        List<Challenge> all = challenges.findAll();
        long totalUsuarios = users.count();

        long concluidos = all.stream().filter(Challenge::isCompleted).count();

        Map<RiskLevel, Long> porRisco = new EnumMap<>(RiskLevel.class);
        Map<Category, Long> porCategoria = new EnumMap<>(Category.class);
        long emRisco = 0;
        int melhorStreak = 0;

        for (Challenge c : all) {
            RiskLevel level = riskEngine.scoreToLevel(riskEngine.calculateScore(c));
            porRisco.merge(level, 1L, Long::sum);
            porCategoria.merge(c.getCategory(), 1L, Long::sum);
            if (level == RiskLevel.HIGH || level == RiskLevel.CRITICAL) {
                emRisco++;
            }
            melhorStreak = Math.max(melhorStreak, c.getStreak());
        }

        long xpTotal = users.findAll().stream().mapToLong(u -> u.getTotalXp()).sum();
        long xpMedio = totalUsuarios == 0 ? 0 : xpTotal / totalUsuarios;

        return new IndicadoresResponse(
                totalUsuarios,
                all.size(),
                concluidos,
                emRisco,
                xpMedio,
                melhorStreak,
                porCategoria.entrySet().stream()
                        .map(e -> new ContagemPorChave(e.getKey().toJson(), e.getValue()))
                        .sorted(Comparator.comparingLong(ContagemPorChave::quantidade).reversed())
                        .toList(),
                porRisco.entrySet().stream()
                        .map(e -> new ContagemPorChave(e.getKey().toJson(), e.getValue()))
                        .toList()
        );
    }

    private AdminChallengeResponse toAdminChallenge(Challenge c) {
        double score = riskEngine.calculateScore(c);
        RiskLevel level = riskEngine.scoreToLevel(score);
        return new AdminChallengeResponse(
                c.getId().toString(),
                c.getTitle(),
                c.getCategory(),
                c.getUser().getName(),
                c.getUser().getEmail(),
                c.getCurrentDay(),
                c.getTotalDays(),
                c.getStreak(),
                score,
                level,
                c.isCompleted()
        );
    }
}
