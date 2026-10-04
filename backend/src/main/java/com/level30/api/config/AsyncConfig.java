package com.level30.api.config;

import java.util.concurrent.RejectedExecutionHandler;
import java.util.concurrent.ThreadPoolExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Fase 6 — executor dedicado à replicação de eventos no Oracle ({@code oracleExecutor}).
 *
 * <p>Separado do pool padrão do Spring para que uma lentidão/indisponibilidade do Oracle nunca
 * compita por threads com o resto da aplicação. Fila cheia descarta a tarefa mais antiga com um
 * log de aviso — nunca {@link ThreadPoolExecutor.CallerRunsPolicy}, que bloquearia a requisição
 * do aluno que está só tentando concluir o dia no app.
 */
@Configuration
@EnableAsync
public class AsyncConfig {

    private static final Logger log = LoggerFactory.getLogger(AsyncConfig.class);

    @Bean(name = "oracleExecutor")
    public ThreadPoolTaskExecutor oracleExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(2);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("oracle-");
        executor.setRejectedExecutionHandler(discardComAviso());
        executor.initialize();
        return executor;
    }

    private RejectedExecutionHandler discardComAviso() {
        return (task, pool) -> log.warn(
                "oracleExecutor: fila cheia (capacidade {}), descartando replicação pendente no Oracle.",
                pool.getQueue().size());
    }
}
