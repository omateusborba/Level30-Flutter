package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.exception.RegraNegocioException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.Locale;
import java.util.UUID;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.oracle.OracleContainer;

/**
 * Fase 6 — teste de integração real do {@link OracleEngajamentoGateway} contra um Oracle de
 * verdade (Testcontainers, {@code gvenzl/oracle-free}). Roda {@code 01_ddl.sql} e
 * {@code 03_plsql.sql} antes dos testes (ver {@code db/oracle/README.md} para a ordem completa —
 * {@code 02_carga_simulada.sql} não é necessário aqui: {@code pr_registrar_conclusao} provisiona
 * usuário e desafio sozinha via MERGE).
 *
 * <p><strong>Marcado {@code @Tag("oracle")} e excluído do build padrão</strong> (ver
 * {@code excludedGroups} no {@code pom.xml}) — a imagem é pesada e exige Docker. Rode com:
 * {@code mvn verify -Poracle-it}.
 *
 * <p><strong>Nota de quem escreveu este teste:</strong> não havia Docker disponível no ambiente
 * onde esta Fase 6 foi implementada, então esta classe não foi executada contra um Oracle real —
 * só revisada manualmente e com o parser de script (ver {@link #rodarScript}) validado à parte
 * contra o conteúdo real de {@code 01_ddl.sql}/{@code 03_plsql.sql} (divide corretamente em 6
 * blocos PL/SQL + 1 SELECT final, e 27 statements simples, sem nenhum CREATE TABLE/CREATE
 * SEQUENCE perdido). Rode localmente com Docker antes de confiar neste teste em CI.
 */
@Tag("oracle")
@Testcontainers
class OracleEngajamentoGatewayIT {

    @Container
    static final OracleContainer ORACLE = new OracleContainer("gvenzl/oracle-free:slim-faststart");

    private static DataSource dataSource;
    private static JdbcTemplate jdbcTemplate;
    private static OracleEngajamentoGateway gateway;

    @BeforeAll
    static void subirSchema() throws IOException, SQLException {
        dataSource = DataSourceBuilder.create()
                .url(ORACLE.getJdbcUrl())
                .username(ORACLE.getUsername())
                .password(ORACLE.getPassword())
                .driverClassName("oracle.jdbc.OracleDriver")
                .build();
        jdbcTemplate = new JdbcTemplate(dataSource);

        Path pastaScripts = Path.of("..", "db", "oracle");
        rodarScript(pastaScripts.resolve("01_ddl.sql"));
        rodarScript(pastaScripts.resolve("03_plsql.sql"));

        gateway = new OracleEngajamentoGateway(jdbcTemplate, dataSource);
    }

    @AfterAll
    static void limpar() {
        if (dataSource instanceof AutoCloseable closeable) {
            try {
                closeable.close();
            } catch (Exception ignored) {
                // pool de teste, sem problema se o close falhar
            }
        }
    }

    @Test
    void registrarConclusao_gravaCompletionsELogDeSucesso() {
        DesafioConcluidoEvent evento = eventoValido();

        int alertas = gateway.registrarConclusao(evento);

        assertThat(alertas).isZero(); // primeira conclusão do desafio: sem alerta de streak/adesão
        Integer completions = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM l30_completions WHERE challenge_id = ?",
                Integer.class, evento.challengeId().toString());
        assertThat(completions).isEqualTo(1);

        Integer sucessos = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM l30_execution_log WHERE routine = 'PR_REGISTRAR_CONCLUSAO' AND status = 'SUCESSO'",
                Integer.class);
        assertThat(sucessos).isGreaterThanOrEqualTo(1);
    }

    @Test
    void reenviarMesmaConclusao_naoDuplica() {
        DesafioConcluidoEvent evento = eventoValido();

        gateway.registrarConclusao(evento);
        gateway.registrarConclusao(evento); // reentrega do mesmo evento

        Integer completions = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM l30_completions WHERE challenge_id = ?",
                Integer.class, evento.challengeId().toString());
        assertThat(completions).isEqualTo(1);
    }

    @Test
    void diaForaDoIntervalo_lancaRegraNegocioException422() {
        DesafioConcluidoEvent invalido = new DesafioConcluidoEvent(
                UUID.randomUUID(), "Aluno Teste", 0,
                UUID.randomUUID(), "Desafio inválido",
                LocalDate.now().minusDays(40), 99, 1,
                LocalDate.now(), 10);

        assertThatThrownBy(() -> gateway.registrarConclusao(invalido))
                .isInstanceOf(RegraNegocioException.class);
    }

    private static DesafioConcluidoEvent eventoValido() {
        LocalDate inicio = LocalDate.now().minusDays(11);
        return new DesafioConcluidoEvent(
                UUID.randomUUID(), "Aluno Teste", 100,
                UUID.randomUUID(), "Desafio de teste",
                inicio, 12, 1,
                LocalDate.now(), 10);
    }

    // ---------------------------------------------------------------
    // Executor de script SQL*Plus-like: blocos PL/SQL terminados por uma linha só com "/",
    // statements simples terminados por ";". Validado (sem Docker) contra o conteúdo real dos
    // scripts — ver nota da classe.
    // ---------------------------------------------------------------

    private static void rodarScript(Path arquivo) throws IOException, SQLException {
        String conteudo = Files.readString(arquivo);
        try (Connection conn = dataSource.getConnection()) {
            for (String bloco : conteudo.split("(?m)^\\s*/\\s*$")) {
                String trimmed = bloco.strip();
                if (trimmed.isEmpty()) {
                    continue;
                }
                if (ehBlocoPlsql(trimmed)) {
                    executar(conn, trimmed);
                } else {
                    for (String stmt : trimmed.split(";")) {
                        String s = stmt.strip();
                        if (!s.isEmpty()) {
                            executar(conn, s);
                        }
                    }
                }
            }
        }
    }

    private static boolean ehBlocoPlsql(String bloco) {
        String upper = bloco.toUpperCase(Locale.ROOT);
        return upper.contains("CREATE OR REPLACE") || upper.startsWith("DECLARE") || upper.startsWith("BEGIN");
    }

    private static void executar(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement()) {
            st.execute(sql);
        }
    }
}
