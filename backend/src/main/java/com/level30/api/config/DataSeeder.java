package com.level30.api.config;

import com.level30.api.demo.DemoSeedService;
import com.level30.api.domain.model.Role;
import com.level30.api.domain.model.User;
import com.level30.api.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * No boot:
 * <ul>
 *   <li>garante SEMPRE que existe um usuário ADMIN (conta de operação — não é "dado de demo");</li>
 *   <li>com {@code SEED_ENABLED=true} (default) e nenhum estudante ainda, executa o seed ÚNICO da demo
 *       ({@link DemoSeedService}), que popula PostgreSQL/H2 e, se ligado, o Oracle, com as mesmas pessoas.
 *       O seed se recusa a rodar fora de ambiente local/demo.</li>
 * </ul>
 * {@code @Order(10)}: roda ANTES dos backfills (20 e 30). Sem ordem explícita ele rodava por último e os
 * backfills enxergavam o banco vazio — causa do risco zerado no dashboard.
 * Para um ambiente limpo: {@code SEED_ENABLED=false} → só o admin é criado.
 */
@Component
@Order(10)
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UserRepository users;
    private final DemoSeedService demoSeed;
    private final PasswordEncoder passwordEncoder;
    private final String adminEmail;
    private final String adminPassword;
    private final boolean demoEnabled;

    public DataSeeder(UserRepository users, DemoSeedService demoSeed,
                      PasswordEncoder passwordEncoder,
                      @Value("${app.seed.admin-email:admin@level30.app}") String adminEmail,
                      @Value("${app.seed.admin-password:admin1234}") String adminPassword,
                      @Value("${app.seed.enabled:true}") boolean demoEnabled) {
        this.users = users;
        this.demoSeed = demoSeed;
        this.passwordEncoder = passwordEncoder;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
        this.demoEnabled = demoEnabled;
    }

    @Override
    public void run(String... args) {
        ensureAdmin();
        if (demoEnabled) {
            demoSeed.executarSeVazio();
        }
    }

    private void ensureAdmin() {
        var existing = users.findByEmail(adminEmail);
        if (existing.isPresent()) {
            // Reconcilia a senha: se SEED_ADMIN_PASSWORD mudou (rotacao de credencial),
            // o hash em banco e atualizado no proximo boot. Sem isso, trocar a env var
            // nao surtia efeito em conta ja criada.
            User admin = existing.get();
            if (!passwordEncoder.matches(adminPassword, admin.getPasswordHash())) {
                admin.setPasswordHash(passwordEncoder.encode(adminPassword));
                users.save(admin);
                log.warn("Admin {}: senha reconciliada a partir de SEED_ADMIN_PASSWORD.", adminEmail);
            }
            if (admin.getRole() != Role.ADMIN) {
                admin.setRole(Role.ADMIN);
                users.save(admin);
            }
            return;
        }
        users.save(User.create(adminEmail, passwordEncoder.encode(adminPassword), "Coordenação", Role.ADMIN));
        log.info("Admin criado: {}", adminEmail);
    }
}
