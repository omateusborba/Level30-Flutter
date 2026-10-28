package com.level30.api.demo;

import java.time.LocalDate;
import java.util.List;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Operações do seed da demo que só existem do lado Oracle: limpar a réplica, ajustar o estado depois de
 * reexecutar o histórico e contar linhas para a checagem de paridade. Só existe com
 * {@code level30.oracle.enabled=true}; toda operação destrutiva reconfere a URL ({@link DemoGuard}).
 */
@Component
@ConditionalOnProperty(prefix = "level30.oracle", name = "enabled", havingValue = "true")
public class OracleDemoSupport {

    private final JdbcTemplate oracle;
    private final String url;

    public OracleDemoSupport(@Qualifier("oracleJdbcTemplate") JdbcTemplate oracle,
                             @Value("${level30.oracle.datasource.url:}") String url) {
        this.oracle = oracle;
        this.url = url;
    }

    public String url() {
        return url;
    }

    /** Apaga a réplica inteira (ordem respeita as FKs). Só em banco local/demo. */
    public void resetar() {
        DemoGuard.exigir("Oracle", url);
        for (String tabela : List.of("l30_alerts", "l30_engagement_reports", "l30_completions", "l30_challenges",
                "l30_users", "l30_audit_log", "l30_execution_log")) {
            oracle.update("DELETE FROM " + tabela);
        }
    }

    /**
     * Depois de reexecutar o histórico pela procedure: (1) alinha {@code last_activity_at} à última conclusão
     * real (a procedure grava SYSTIMESTAMP); (2) reavalia o alerta de adesão de cada aluno pela MESMA regra da
     * trigger; (3) deixa abertos só os "streak reiniciado" recentes; (4) zera o log de auditoria e de execução,
     * para a demonstração começar limpa.
     */
    public void finalizar() {
        DemoGuard.exigir("Oracle", url);
        oracle.update("""
                UPDATE l30_challenges c
                   SET last_activity_at = (SELECT FROM_TZ(CAST(MAX(cc.completed_on) AS TIMESTAMP)
                                                          + NUMTODSINTERVAL(19, 'HOUR'), 'America/Sao_Paulo')
                                             FROM l30_completions cc WHERE cc.challenge_id = c.id)
                """);
        for (String userId : oracle.queryForList("SELECT id FROM l30_users", String.class)) {
            oracle.update("BEGIN pkg_l30_engajamento.pr_avaliar_alerta_adesao(?); END;", userId);
        }
        oracle.update("""
                UPDATE l30_alerts a
                   SET resolved = 1, resolved_at = SYSTIMESTAMP
                 WHERE a.alert_type = 'STREAK_REINICIADO' AND a.resolved = 0
                   AND (a.id <> (SELECT MAX(b.id) FROM l30_alerts b
                                  WHERE b.user_id = a.user_id AND b.alert_type = 'STREAK_REINICIADO')
                        OR (SELECT MAX(cc.completed_on) FROM l30_completions cc
                             WHERE cc.challenge_id = a.challenge_id) < TRUNC(SYSDATE) - 7)
                """);
    }

    /** Roda depois de {@code PR_VERIFICAR_INATIVIDADE}; zera auditoria/log gerados pelo próprio seed. */
    public void limparRastroDoSeed() {
        DemoGuard.exigir("Oracle", url);
        oracle.update("DELETE FROM l30_audit_log");
        oracle.update("DELETE FROM l30_execution_log");
    }

    public long usuarios() {
        return count("SELECT COUNT(*) FROM l30_users");
    }

    public long desafios() {
        return count("SELECT COUNT(*) FROM l30_challenges");
    }

    public long conclusoesDesde(LocalDate desde) {
        Long n = oracle.queryForObject(
                "SELECT COUNT(*) FROM l30_completions WHERE completed_on >= ?", Long.class, java.sql.Date.valueOf(desde));
        return n == null ? 0 : n;
    }

    public long xpTotal() {
        return count("SELECT NVL(SUM(total_xp), 0) FROM l30_users");
    }

    private long count(String sql) {
        Long n = oracle.queryForObject(sql, Long.class);
        return n == null ? 0 : n;
    }
}
