package com.level30.api.config;

import com.level30.api.domain.model.Category;
import com.level30.api.domain.model.Challenge;
import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.repository.ChallengeRepository;
import com.level30.api.repository.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Popula dados de demonstração no primeiro boot (base vazia). Desligável com
 * {@code SEED_ENABLED=false}. Cobre os cenários de risco que o dashboard precisa mostrar.
 */
@Component
@ConditionalOnProperty(name = "app.seed.enabled", havingValue = "true", matchIfMissing = true)
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UserRepository users;
    private final ChallengeRepository challenges;
    private final PasswordEncoder passwordEncoder;
    private final String adminEmail;
    private final String adminPassword;

    public DataSeeder(UserRepository users, ChallengeRepository challenges,
                      PasswordEncoder passwordEncoder,
                      @org.springframework.beans.factory.annotation.Value(
                              "${app.seed.admin-email:admin@level30.app}") String adminEmail,
                      @org.springframework.beans.factory.annotation.Value(
                              "${app.seed.admin-password:admin1234}") String adminPassword) {
        this.users = users;
        this.challenges = challenges;
        this.passwordEncoder = passwordEncoder;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (users.count() > 0) {
            return;
        }
        log.info("Seed: base vazia, criando dados de demonstracao.");

        User admin = save(adminEmail, adminPassword, "Coordenacao", Role.ADMIN);

        User ana = save("ana@level30.app", "estudante1", "Ana Souza", Role.USER);
        challenge(ana, "Leitura diaria", Category.STUDY, "Ler 20 paginas por dia", 30, 12, 12, daysAgo(0));
        challenge(ana, "Corrida matinal", Category.FITNESS, "5km toda manha", 30, 3, 0, daysAgo(4));
        challenge(ana, "Meditacao", Category.MINDFULNESS, "10 min de respiracao", 21, 21, 21, daysAgo(0));

        User bruno = save("bruno@level30.app", "estudante1", "Bruno Lima", Role.USER);
        challenge(bruno, "Revisao de calculo", Category.STUDY, "1h de exercicios", 30, 7, 7, daysAgo(0));
        challenge(bruno, "Sono regular", Category.HEALTH, "Dormir antes das 23h", 30, 1, 0, daysAgo(9));

        User carla = save("carla@level30.app", "estudante1", "Carla Dias", Role.USER);
        challenge(carla, "Pomodoro de foco", Category.PRODUCTIVITY, "4 blocos por dia", 14, 9, 6, daysAgo(1));

        log.info("Seed concluido: 1 admin + 3 estudantes + 7 desafios. Login admin: {}",
                admin.getEmail());
    }

    private User save(String email, String senha, String nome, Role role) {
        return users.save(User.create(email, passwordEncoder.encode(senha), nome, role));
    }

    private void challenge(User user, String title, Category category, String description,
                           int totalDays, int currentDay, int streak, Instant lastActivityAt) {
        Challenge c = Challenge.create(user, title, category, description, totalDays, 300);
        c.setCurrentDay(currentDay);
        c.setStreak(streak);
        c.setLastActivityAt(lastActivityAt);
        challenges.save(c);
    }

    private Instant daysAgo(int days) {
        return Instant.now().minus(days, ChronoUnit.DAYS);
    }
}
