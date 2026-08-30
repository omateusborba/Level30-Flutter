package com.level30.api.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.dto.response.CompleteResponse;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ChallengeServiceTest {

    @Autowired
    ChallengeService challengeService;
    @Autowired
    UserRepository users;
    @Autowired
    ChallengeRepository challenges;

    private User newUser() {
        return users.save(User.create("u" + UUID.randomUUID() + "@test.com", "x", "User", Role.USER));
    }

    private Challenge newChallenge(User user, int currentDay, int streak, Instant lastActivityAt) {
        Challenge c = Challenge.create(user, "Leitura", Category.STUDY, "desc", 30, 300);
        c.setCurrentDay(currentDay);
        c.setStreak(streak);
        c.setLastActivityAt(lastActivityAt);
        return challenges.save(c);
    }

    @Test
    void completarDia_incrementaDia_streakEXpDelta() {
        User user = newUser();
        Challenge c = newChallenge(user, 4, 2, Instant.now().minus(1, ChronoUnit.DAYS));

        CompleteResponse res = challengeService.completeDay(user.getId(), c.getId());

        assertThat(res.challenge().currentDay()).isEqualTo(5);
        assertThat(res.challenge().streak()).isEqualTo(3);
        // earnedXp(5,30,300)=50, earnedXp(4,30,300)=40
        assertThat(res.xpDelta()).isEqualTo(10);
        assertThat(res.totalXp()).isEqualTo(10);
        assertThat(users.findById(user.getId()).orElseThrow().getTotalXp()).isEqualTo(10);
    }

    @Test
    void completarDia_segundaVezNoMesmoDia_retorna409() {
        User user = newUser();
        Challenge c = newChallenge(user, 4, 2, Instant.now().minus(1, ChronoUnit.DAYS));

        challengeService.completeDay(user.getId(), c.getId());

        RegraNegocioException ex = catchThrowableOfType(
                () -> challengeService.completeDay(user.getId(), c.getId()),
                RegraNegocioException.class);
        assertThat(ex).isNotNull();
        assertThat(ex.getStatus()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void completarDia_retomadaAposDoisDias_reiniciaStreak() {
        User user = newUser();
        Challenge c = newChallenge(user, 10, 6, Instant.now().minus(3, ChronoUnit.DAYS));

        CompleteResponse res = challengeService.completeDay(user.getId(), c.getId());

        assertThat(res.challenge().streak()).isEqualTo(1);
    }

    @Test
    void completarDia_retomadaNoDiaSeguinte_incrementaStreak() {
        User user = newUser();
        Challenge c = newChallenge(user, 10, 6, Instant.now().minus(1, ChronoUnit.DAYS));

        CompleteResponse res = challengeService.completeDay(user.getId(), c.getId());

        assertThat(res.challenge().streak()).isEqualTo(7);
    }

    @Test
    void completarDia_desafioDeOutroUsuario_retorna404() {
        User dono = newUser();
        User intruso = newUser();
        Challenge c = newChallenge(dono, 1, 0, null);

        assertThatThrownBy(() -> challengeService.completeDay(intruso.getId(), c.getId()))
                .isInstanceOf(RecursoNaoEncontradoException.class);
    }

    @Test
    void completarDia_desafioJaConcluido_retorna400() {
        User user = newUser();
        Challenge c = newChallenge(user, 30, 30, Instant.now().minus(1, ChronoUnit.DAYS));

        RegraNegocioException ex = catchThrowableOfType(
                () -> challengeService.completeDay(user.getId(), c.getId()),
                RegraNegocioException.class);
        assertThat(ex).isNotNull();
        assertThat(ex.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
