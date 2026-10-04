package com.level30.api.config;

import com.zaxxer.hikari.HikariDataSource;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Fase 6 — datasource e {@link JdbcTemplate} dedicados à camada Oracle PL/SQL
 * (indicadores, alertas e relatórios de engajamento; ver {@code db/oracle/}).
 *
 * <p>Só existe quando {@code level30.oracle.enabled=true}. Com a flag desligada (padrão — é o que
 * roda em produção hoje), nenhum destes beans é criado e a aplicação se comporta exatamente como
 * antes da Fase 6.
 */
@Configuration
@ConditionalOnProperty(prefix = "level30.oracle", name = "enabled", havingValue = "true")
public class OracleConfig {

    @Bean
    @ConfigurationProperties("level30.oracle.datasource")
    public DataSourceProperties oracleDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean(name = "oracleDataSource")
    @ConfigurationProperties("level30.oracle.datasource.hikari")
    public HikariDataSource oracleDataSource(
            @Qualifier("oracleDataSourceProperties") DataSourceProperties oracleDataSourceProperties) {
        return oracleDataSourceProperties.initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Bean(name = "oracleJdbcTemplate")
    public JdbcTemplate oracleJdbcTemplate(@Qualifier("oracleDataSource") DataSource oracleDataSource) {
        return new JdbcTemplate(oracleDataSource);
    }
}
