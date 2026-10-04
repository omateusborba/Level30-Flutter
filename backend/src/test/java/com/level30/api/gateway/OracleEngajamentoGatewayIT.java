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
 * verdade (Testcontainers, {@code gvenzl/oracle-free}). Roda, nesta ordem, {@code 01_ddl.sql},
 * {@code 02_carga_simulada.sql} e {@code 03_plsql.sql} antes dos testes (mesma ordem de
 * {@code db/oracle/README.md}; só {@code 00_drop.sql} — desnecessário em container novo — e
 * {@code 04}/{@code 05} — passo manual/opcional — ficam de fora).
 *
 * <p><strong>Marcado {@code @Tag("oracle")} e excluído do build padrão</strong> (ver
 * {@code excludedGroups} no {@code pom.xml}) — a imagem é pesada e exige Docker. Rode com:
 * {@code mvn verify -Poracle-it}.
 *
 * <p><strong>Nota de quem escreveu este teste:</strong> não havia Docker disponível no ambiente
 * onde esta Fase 6 foi implementada, então esta classe não foi executada contra um Oracle real —
 * só revisada manualmente. O parser de script ({@link #rodarScript}) foi validado à parte (sem
 * Docker, com um script Python equivalente rodado contra os 3 arquivos reais) e corrigido depois
 * dessa validação: a primeira versão classificava blocos PL/SQL por palavra-chave
 * ({@code DECLARE}/{@code BEGIN}/{@code CREATE OR REPLACE}) e **errava** no bloco
 * {@code DECLARE} de {@code 02_carga_simulada.sql}, porque ele começa com linhas de comentário e
 * {@code SET SERVEROUTPUT ON} antes do {@code DECLARE} — o heurístico não reconhecia o bloco como
 * PL/SQL e tentava fatiá-lo por {@code ;}, o que teria quebrado a carga inteira. A versão atual
 * não inspeciona o conteúdo: qualquer trecho terminado por uma linha só com {@code /} É um bloco
 * PL/SQL (é exatamente o que esse delimitador significa no SQL*Plus) — executado inteiro, numa
 * só instrução; só o que sobra depois do último {@code /} (ou o arquivo inteiro, se não houver
 * nenhum) é SQL simples, daí sim fatiado por {@code ;}. Com isso: {@code 01_ddl.sql} → 0 blocos
 * PL/SQL, 27 statements simples; {@code 02_carga_simulada.sql} → 1 bloco PL/SQL (o
 * {@code DECLARE}), 1 statement simples (o SELECT de conferência); {@code 03_plsql.sql} → 6
 * blocos PL/SQL (as 6 {@code CREATE OR REPLACE}), 1 statement simples (o SELECT final de
 * verificação). {@code SET SERVEROUTPUT ON} é removido antes de tudo — é diretiva do cliente
 * SQL*Plus, inválida via JDBC puro. Rode localmente com Docker antes de confiar neste teste em CI.
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
        rodarScript(pastaScripts.resolve("02_carga_simulada.sql"));
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
        // "SET SERVEROUTPUT ON" é diretiva do cliente SQL*Plus, inválida via JDBC puro.
        conteudo = conteudo.replaceAll("(?im)^\\s*SET\\s+SERVEROUTPUT\\b.*$", "");

        String[] partes = conteudo.split("(?m)^\\s*/\\s*$");
        try (Connection conn = dataSource.getConnection()) {
            // Tudo ANTES do último "/" é um bloco PL/SQL inteiro (CREATE OR REPLACE ou
            // DECLARE/BEGIN) — é exatamente o que esse delimitador significa no SQL*Plus.
            // Executa cada bloco como uma única instrução, sem inspecionar o conteúdo.
            for (int i = 0; i < partes.length - 1; i++) {
                String bloco = partes[i].strip();
                if (!bloco.isEmpty()) {
                    executar(conn, bloco);
                }
            }
            // O que sobra depois do último "/" (ou o arquivo inteiro, se não houver nenhum "/",
            // caso de 01_ddl.sql) é SQL simples terminado por ";" — um statement por vez.
            String resto = partes[partes.length - 1];
            for (String stmt : resto.split(";")) {
                String s = stmt.strip();
                if (!s.isEmpty() && !ehSoComentario(s)) {
                    executar(conn, s);
                }
            }
        }
    }

    private static boolean ehSoComentario(String statement) {
        for (String linha : statement.split("\n")) {
            String l = linha.strip();
            if (!l.isEmpty() && !l.startsWith("--")) {
                return false;
            }
        }
        return true;
    }

    private static void executar(Connection conn, String sql) throws SQLException {
        try (Statement st = conn.createStatement()) {
            st.execute(sql);
        }
    }
}
