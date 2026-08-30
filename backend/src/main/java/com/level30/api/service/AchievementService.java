package com.level30.api.service;

import com.level30.api.domain.model.Achievement;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.User;
import com.level30.api.domain.model.UserAchievement;
import com.level30.api.dto.response.AchievementResponse;
import com.level30.api.repository.ChallengeCompletionRepository;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserAchievementRepository;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * F4 · Avalia o catálogo de conquistas a cada conclusão de dia. Roda dentro da
 * transação de {@code completeDay} — a PK composta de {@code user_achievements}
 * garante que nada é concedido duas vezes.
 */
@Service
public class AchievementService {

    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    private final UserAchievementRepository unlocked;
    private final ChallengeRepository challenges;
    private final ChallengeCompletionRepository completions;

    public AchievementService(UserAchievementRepository unlocked,
                              ChallengeRepository challenges,
                              ChallengeCompletionRepository completions) {
        this.unlocked = unlocked;
        this.challenges = challenges;
        this.completions = completions;
    }

    /** @return conquistas desbloqueadas NESTA ação (vazio se nenhuma). */
    @Transactional
    public List<AchievementResponse> avaliar(User user) {
        UUID userId = user.getId();
        Set<String> jaTem = unlocked.idsByUser(userId);
        Set<Achievement> alvo = EnumSet.noneOf(Achievement.class);

        List<Challenge> desafios = challenges.findByUserIdOrderByCreatedAtDesc(userId);
        long totalCompletions = completions.countByUserId(userId);

        if (totalCompletions >= 1) {
            alvo.add(Achievement.PRIMEIRO_PASSO);
        }
        int maxStreak = desafios.stream().mapToInt(Challenge::getStreak).max().orElse(0);
        if (maxStreak >= 7) {
            alvo.add(Achievement.SEMANA_CHEIA);
        }
        if (maxStreak >= 21) {
            alvo.add(Achievement.CONSTANCIA);
        }
        if (desafios.stream().anyMatch(Challenge::isCompleted)) {
            alvo.add(Achievement.MARATONISTA);
        }
        long categoriasAtivas = desafios.stream()
                .filter(c -> !c.isCompleted())
                .map(Challenge::getCategory)
                .distinct()
                .count();
        if (categoriasAtivas >= 3) {
            alvo.add(Achievement.POLIGLOTA);
        }
        long madrugadas = completions.findByUserId(userId).stream()
                .filter(c -> LocalTime.ofInstant(c.getCreatedAt(), ZONE).getHour() < 8)
                .count();
        if (madrugadas >= 5) {
            alvo.add(Achievement.MADRUGADOR);
        }
        // streak == 1 com progresso acumulado = retomada após zerar
        if (desafios.stream().anyMatch(c -> c.getStreak() == 1 && c.getCurrentDay() >= 3)) {
            alvo.add(Achievement.RESILIENTE);
        }
        if (user.getTotalXp() / 500 + 1 >= 5) {
            alvo.add(Achievement.VETERANO);
        }

        List<AchievementResponse> novas = new ArrayList<>();
        for (Achievement a : alvo) {
            if (!jaTem.contains(a.id())) {
                unlocked.save(UserAchievement.of(userId, a));
                novas.add(AchievementResponse.of(a, true));
            }
        }
        return novas;
    }

    @Transactional(readOnly = true)
    public List<AchievementResponse> listar(UUID userId) {
        Set<String> jaTem = unlocked.idsByUser(userId);
        List<AchievementResponse> out = new ArrayList<>();
        for (Achievement a : Achievement.values()) {
            out.add(AchievementResponse.of(a, jaTem.contains(a.id())));
        }
        return out;
    }
}
