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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * No boot:
 * <ul>
 *   <li>garante SEMPRE que existe um usuário ADMIN (conta de operação — não é "dado de demo");</li>
 *   <li>com {@code SEED_ENABLED=true} (default) e nenhum estudante ainda, cria os dados de
 *       demonstração (Ana/Bruno/Carla + desafios) cobrindo os cenários de risco do dashboard.</li>
 * </ul>
 * Para um ambiente limpo: {@code SEED_ENABLED=false} → só o admin é criado.
 */
@Component
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UserRepository users;
    private final ChallengeRepository challenges;
    private final PasswordEncoder passwordEncoder;
    private final String adminEmail;
    private final String adminPassword;
    private final boolean demoEnabled;

    public DataSeeder(UserRepository users, ChallengeRepository challenges,
                      PasswordEncoder passwordEncoder,
                      @Value("${app.seed.admin-email:admin@level30.app}") String adminEmail,
                      @Value("${app.seed.admin-password:admin1234}") String adminPassword,
                      @Value("${app.seed.enabled:true}") boolean demoEnabled) {
        this.users = users;
        this.challenges = challenges;
        this.passwordEncoder = passwordEncoder;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
        this.demoEnabled = demoEnabled;
    }

    @Override
    @Transactional
    public void run(String... args) {
        ensureAdmin();
        if (demoEnabled) {
            seedDemoData();
        }
    }

    private void ensureAdmin() {
        if (users.findByEmail(adminEmail).isPresent()) {
            return;
        }
        users.save(User.create(adminEmail, passwordEncoder.encode(adminPassword), "Coordenacao", Role.ADMIN));
        log.info("Admin criado: {}", adminEmail);
    }

    private void seedDemoData() {
        boolean hasStudents = users.findAll().stream().anyMatch(u -> u.getRole() == Role.USER);
        if (hasStudents) {
            return;
        }
        log.info("Seed: criando dados de demonstracao (SEED_ENABLED=true).");

        User ana = save("ana@level30.app", "estudante1", "Ana Souza");
        challenge(ana, "Leitura diaria", Category.STUDY, "Ler 20 paginas por dia", 30, 12, 12, daysAgo(0));
        challenge(ana, "Corrida matinal", Category.FITNESS, "5km toda manha", 30, 3, 0, daysAgo(4));
        challenge(ana, "Meditacao", Category.MINDFULNESS, "10 min de respiracao", 21, 21, 21, daysAgo(0));

        User bruno = save("bruno@level30.app", "estudante1", "Bruno Lima");
        challenge(bruno, "Revisao de calculo", Category.STUDY, "1h de exercicios", 30, 7, 7, daysAgo(0));
        challenge(bruno, "Sono regular", Category.HEALTH, "Dormir antes das 23h", 30, 1, 0, daysAgo(9));

        User carla = save("carla@level30.app", "estudante1", "Carla Dias");
        challenge(carla, "Pomodoro de foco", Category.PRODUCTIVITY, "4 blocos por dia", 14, 9, 6, daysAgo(1));

        log.info("Seed concluido: 3 estudantes + 7 desafios.");
    }

    private User save(String email, String senha, String nome) {
        return users.save(User.create(email, passwordEncoder.encode(senha), nome, Role.USER));
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
