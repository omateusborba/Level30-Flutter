package com.level30.api.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

/**
 * Fase 6 — declara explicitamente o datasource do PostgreSQL/H2 (o mesmo que a autoconfiguração
 * do Spring Boot já montava a partir de {@code spring.datasource.*}).
 *
 * <p>Necessário porque, a partir do momento em que {@link OracleConfig} declara um segundo bean
 * {@link javax.sql.DataSource} (condicional, para o Oracle), a autoconfiguração padrão do Spring
 * Boot recua — ela só age quando não há nenhum {@code DataSource} manual no contexto. Sem este
 * bean marcado {@code @Primary}, JPA e Flyway perderiam o datasource principal e a aplicação não
 * subiria.
 */
@Configuration
public class DataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties primaryDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource.hikari")
    public HikariDataSource dataSource(DataSourceProperties primaryDataSourceProperties) {
        return primaryDataSourceProperties.initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }
}
