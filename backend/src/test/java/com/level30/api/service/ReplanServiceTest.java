package com.level30.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

/** C2 · replanejamento assistido por IA (fallback determinístico no perfil test). */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ReplanServiceTest {

    @Autowired
    ReplanService replan;
    @Autowired
    UserRepository users;
    @Autowired
    ChallengeRepository challenges;

    private Challenge novo(int totalDays, int currentDay, int xpReward) {
        User u = users.save(User.create("r" + UUID.randomUUID() + "@t.com", "x", "R", Role.USER));
        Challenge c = Challenge.create(u, "Ler", Category.STUDY, "d", totalDays, xpReward);
        c.setCurrentDay(currentDay);
        return challenges.save(c);
    }

    @Test
    void sugestao_naoMutaEProponeMaisDias() {
        Challenge c = novo(30, 6, 300);
        var s = replan.sugestao(c.getUser().getId(), c.getId());

        assertThat(s.sugestaoDias()).isGreaterThan(30);
        assertThat(s.replanejamentosRestantes()).isEqualTo(2);
        assertThat(s.mensagem()).isNotBlank();
        assertThat(challenges.findById(c.getId()).orElseThrow().getTotalDays()).isEqualTo(30);
    }

    @Test
    void aplicar_estendeDuracaoEReescalaXpParaBaixo() {
        Challenge c = novo(30, 6, 300);
        var res = replan.aplicar(c.getUser().getId(), c.getId(), 45);

        assertThat(res.totalDays()).isEqualTo(45);
        assertThat(res.xpReward()).isEqualTo(450); // 300 * 45 / 30
        assertThat(res.replanCount()).isEqualTo(1);
    }

    @Test
    void aplicar_terceiraVez_recusa() {
        Challenge c = novo(30, 3, 300);
        replan.aplicar(c.getUser().getId(), c.getId(), 40);
        replan.aplicar(c.getUser().getId(), c.getId(), 50);
        assertThatThrownBy(() -> replan.aplicar(c.getUser().getId(), c.getId(), 60))
                .isInstanceOf(RegraNegocioException.class);
    }

    @Test
    void aplicar_menorQueProgresso_recusa() {
        Challenge c = novo(30, 20, 300);
        assertThatThrownBy(() -> replan.aplicar(c.getUser().getId(), c.getId(), 15))
                .isInstanceOf(RegraNegocioException.class);
    }
}
