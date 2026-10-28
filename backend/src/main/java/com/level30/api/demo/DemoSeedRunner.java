package com.level30.api.demo;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ApplicationContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * Executa o seed completo (reset + população dos dois bancos) quando {@code level30.demo.seed.run=true}.
 * É o que {@code scripts/demo-seed.sh} usa. Com {@code level30.demo.seed.exit-after=true} encerra a JVM com
 * código 0 (sucesso) ou 1 (recusa da trava ou paridade divergente).
 */
@Component
@Order(11)   // depois do DataSeeder (10), que garante o admin
@ConditionalOnProperty(prefix = "level30.demo.seed", name = "run", havingValue = "true")
public class DemoSeedRunner implements CommandLineRunner {

    private final DemoSeedService seed;
    private final ApplicationContext ctx;
    private final boolean exitAfter;

    public DemoSeedRunner(DemoSeedService seed, ApplicationContext ctx,
                          @Value("${level30.demo.seed.exit-after:false}") boolean exitAfter) {
        this.seed = seed;
        this.ctx = ctx;
        this.exitAfter = exitAfter;
    }

    @Override
    public void run(String... args) {
        int codigo = 0;
        try {
            var r = seed.executar();
            System.out.println("DEMO-SEED OK: " + r);
        } catch (RuntimeException e) {
            System.err.println("DEMO-SEED FALHOU: " + e.getMessage());
            codigo = 1;
            if (!exitAfter) {
                throw e;
            }
        }
        if (exitAfter) {
            int saida = codigo;
            System.exit(SpringApplication.exit(ctx, () -> saida));
        }
    }
}
