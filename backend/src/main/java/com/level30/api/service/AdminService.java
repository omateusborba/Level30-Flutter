package com.level30.api.service;

import com.level30.api.domain.Leveling;
import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.RiskLevel;
import com.level30.api.dto.response.AdminChallengeResponse;
import com.level30.api.dto.response.AdminUserResponse;
import com.level30.api.dto.response.IndicadoresResponse;
import com.level30.api.dto.response.IndicadoresResponse.ContagemPorChave;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Consultas do painel administrativo. Desde B1 o nível de risco é
 * <b>materializado</b> em {@code challenges.risk_score/risk_level} (mantido pelo
 * {@link RiskMaterializationService}), então filtragem, ordenação e agregação
 * acontecem no banco — sem {@code findAll()} em memória (achado D7).
 */
@Service
@Transactional(readOnly = true)
public class AdminService {

    private static final List<RiskLevel> EM_RISCO = List.of(RiskLevel.HIGH, RiskLevel.CRITICAL);

    private final UserRepository users;
    private final ChallengeRepository challenges;

    public AdminService(UserRepository users, ChallengeRepository challenges) {
        this.users = users;
        this.challenges = challenges;
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

    public Page<AdminChallengeResponse> desafios(RiskLevel riskLevel, Category category,
                                                String busca, Pageable pageable) {
        String like = (busca == null || busca.isBlank())
                ? null : "%" + busca.trim().toLowerCase() + "%";
        return challenges.pageForAdmin(riskLevel, category, like, pageable).map(this::toAdminChallenge);
    }

    public IndicadoresResponse indicadores() {
        long totalUsuarios = users.count();
        long totalDesafios = challenges.count();
        long xpTotal = users.somaTotalXp();

        Map<Category, Long> porCategoria = toMap(challenges.contagemPorCategoria());
        Map<RiskLevel, Long> porRisco = toMapRisk(challenges.contagemPorRisco());

        return new IndicadoresResponse(
                totalUsuarios,
                totalDesafios,
                challenges.countConcluidos(),
                challenges.countByRiskLevelIn(EM_RISCO),
                totalUsuarios == 0 ? 0 : xpTotal / totalUsuarios,
                challenges.melhorStreak(),
                porCategoria.entrySet().stream()
                        .map(e -> new ContagemPorChave(e.getKey().toJson(), e.getValue()))
                        .sorted((a, b) -> Long.compare(b.quantidade(), a.quantidade()))
                        .toList(),
                porRisco.entrySet().stream()
                        .map(e -> new ContagemPorChave(e.getKey().toJson(), e.getValue()))
                        .toList()
        );
    }

    private AdminChallengeResponse toAdminChallenge(Challenge c) {
        return new AdminChallengeResponse(
                c.getId().toString(),
                c.getTitle(),
                c.getCategory(),
                c.getUser().getName(),
                c.getUser().getEmail(),
                c.getCurrentDay(),
                c.getTotalDays(),
                c.getStreak(),
                c.getRiskScore(),
                c.getRiskLevel(),
                c.isCompleted(),
                c.getReplanCount()
        );
    }

    @SuppressWarnings("unchecked")
    private Map<Category, Long> toMap(List<ChallengeRepository.ContagemView> rows) {
        return rows.stream().collect(Collectors.toMap(
                r -> (Category) r.getChave(), ChallengeRepository.ContagemView::getQuantidade));
    }

    @SuppressWarnings("unchecked")
    private Map<RiskLevel, Long> toMapRisk(List<ChallengeRepository.ContagemView> rows) {
        return rows.stream().collect(Collectors.toMap(
                r -> (RiskLevel) r.getChave(), ChallengeRepository.ContagemView::getQuantidade));
    }
}
