package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.level30.api.demo.DemoGuard;
import com.level30.api.domain.engajamento.DirecaoOrdenacao;
import com.level30.api.domain.engajamento.EngajamentoFiltrado;
import com.level30.api.domain.engajamento.FiltroEngajamento;
import com.level30.api.domain.engajamento.OrdenacaoEngajamento;
import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.exception.RegraNegocioException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import javax.sql.DataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.oracle.OracleContainer;

/**
 * Fase 6 — teste de integração real do {@link OracleEngajamentoGateway} contra um Oracle de
 * verdade (Testcontainers, {@code gvenzl/oracle-free}). Roda, nesta ordem, {@code 01_ddl.sql},
 * {@code 02_carga_simulada.sql} e {@code 03_plsql.sql} antes dos testes (mesma ordem de
 * {@code db/oracle/README.md}; só {@code 00_drop.sql} — desnecessário em container novo — e
 * {@code 04}/{@code 05} — passo manual/opcional — ficam de fora), usando {@link OracleScriptParser}
 * para dividir cada arquivo nos statements que a Fase 2 executa via JDBC.
 *
 * <p><strong>Marcado {@code @Tag("oracle")} e excluído do build padrão</strong> (ver
 * {@code excludedGroups} no {@code pom.xml}) — a imagem é pesada e exige Docker. Rode com:
 * {@code mvn verify -Poracle-it}
 * (Docker 29+ local: acrescente {@code -DargLine=-Dapi.version=1.44}).
 *
 * <p><strong>Nota de quem escreveu este teste:</strong> não havia Docker disponível no ambiente
 * onde esta Fase 6 foi implementada, então esta classe (a parte que fala com Oracle de verdade)
 * não foi executada. O parser em si ({@link OracleScriptParser}) tem cobertura própria que roda
 * sem Docker — {@code OracleScriptParserTest}, contra o conteúdo real dos 3 arquivos. Rode
 * {@code mvn verify -Poracle-it} localmente (com Docker) antes de confiar nesta classe em CI.
 */
@Tag("oracle")
class OracleEngajamentoGatewayIT {

    /**
     * Banco do teste. Por padrão sobe um Oracle descartável via Testcontainers. Se
     * {@code ORACLE_IT_URL}/{@code ORACLE_IT_USER}/{@code ORACLE_IT_PASSWORD} estiverem definidos
     * (caso do CI, que já tem um service container Oracle), usa esse banco e começa por
     * {@code 00_drop.sql} para partir de um schema limpo.
     */
    private static OracleContainer oracle;
    private static boolean bancoExterno;

    private static DataSource dataSource;
    private static JdbcTemplate jdbcTemplate;
    private static OracleEngajamentoGateway gateway;

    @BeforeAll
    static void subirSchema() throws IOException, SQLException {
        String urlExterna = System.getenv("ORACLE_IT_URL");
        bancoExterno = urlExterna != null && !urlExterna.isBlank();
        if (!bancoExterno) {
            oracle = new OracleContainer("gvenzl/oracle-free:23-slim-faststart");
            oracle.start();
        }
        dataSource = DataSourceBuilder.create()
                .url(bancoExterno ? urlExterna : oracle.getJdbcUrl())
                .username(bancoExterno ? System.getenv("ORACLE_IT_USER") : oracle.getUsername())
                .password(bancoExterno ? System.getenv("ORACLE_IT_PASSWORD") : oracle.getPassword())
                .driverClassName("oracle.jdbc.OracleDriver")
                .build();
        jdbcTemplate = new JdbcTemplate(dataSource);

        Path pastaScripts = Path.of("..", "db", "oracle");
        if (bancoExterno) {
            // 00_drop apaga o schema inteiro: só roda em banco local/de demo/descartável
            DemoGuard.exigir("Oracle (IT)", urlExterna);
            rodarScript(pastaScripts.resolve("00_drop.sql"));
        }
        rodarScript(pastaScripts.resolve("01_ddl.sql"));
        rodarScript(pastaScripts.resolve("02_carga_simulada.sql"));
        rodarScript(pastaScripts.resolve("03_plsql.sql"));
        // Fase 7: packages, triggers e consolidação (mesma ordem de db/oracle/README.md)
        rodarScript(pastaScripts.resolve("06_pkg_engajamento.sql"));
        rodarScript(pastaScripts.resolve("07_trg_audit_conclusao.sql"));
        rodarScript(pastaScripts.resolve("08_trg_status_alerta.sql"));
        rodarScript(pastaScripts.resolve("09_pkg_consultas.sql"));
        rodarScript(pastaScripts.resolve("10_consolidacao.sql"));

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
        if (oracle != null) {
            oracle.stop();
        }
    }

    /**
     * Os testes nunca deixam dados: todo aluno criado aqui tem nome ZZ_TESTE_*, e este método remove
     * usuários (cascata), auditoria e log de execução gerados por eles, mesmo quando o teste falha.
     */
    @AfterEach
    void limparDadosDoTeste() {
        List<String> usuarios = jdbcTemplate.queryForList(
                "SELECT id FROM l30_users WHERE name LIKE 'ZZ\\_TESTE\\_%' ESCAPE '\\'", String.class);
        List<String> desafios = jdbcTemplate.queryForList(
                "SELECT id FROM l30_challenges WHERE user_id IN (SELECT id FROM l30_users WHERE name LIKE 'ZZ\\_TESTE\\_%' ESCAPE '\\')",
                String.class);
        jdbcTemplate.update("DELETE FROM l30_users WHERE name LIKE 'ZZ\\_TESTE\\_%' ESCAPE '\\'");
        for (String id : usuarios) {
            jdbcTemplate.update("DELETE FROM l30_audit_log WHERE JSON_VALUE(dados_novos, '$.user_id') = ? "
                    + "OR JSON_VALUE(dados_antigos, '$.user_id') = ?", id, id);
        }
        for (String id : desafios) {
            jdbcTemplate.update("DELETE FROM l30_execution_log WHERE detail LIKE ?", "%" + id + "%");
        }
        jdbcTemplate.update("DELETE FROM l30_execution_log WHERE status = 'ERRO' AND detail LIKE '%dia 99 fora do intervalo%'");
    }

    @Test
    void registrarConclusao_gravaCompletionsELogDeSucesso() {
        DesafioConcluidoEvent evento = eventoValido();

        int alertas = gateway.registrarConclusao(evento);

        // streak=1 no dia 12 => a procedure gera STREAK_REINICIADO; o alerta de adesão é da trigger
        assertThat(alertas).isEqualTo(1);
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
                UUID.randomUUID(), "ZZ_TESTE_Aluno", 0,
                UUID.randomUUID(), "Desafio inválido",
                LocalDate.now().minusDays(40), 99, 1,
                LocalDate.now(), 10);

        assertThatThrownBy(() -> gateway.registrarConclusao(invalido))
                .isInstanceOf(RegraNegocioException.class);
    }

    // ----------------------------------------------------------------
    // Fase 7 — os três fluxos: auditoria, alerta (trigger composta) e Dynamic SQL
    // ----------------------------------------------------------------

    @Test
    void conclusao_geraLinhaDeAuditoriaEmJson() {
        DesafioConcluidoEvent evento = eventoValido();

        gateway.registrarConclusao(evento);

        var auditoria = gateway.listarAuditoria(500).stream()
                .filter(a -> a.dadosNovos() != null && a.dadosNovos().contains(evento.userId().toString()))
                .toList();
        assertThat(auditoria).hasSize(1);
        assertThat(auditoria.get(0).operacao()).isEqualTo("I");
        assertThat(auditoria.get(0).tabela()).isEqualTo("L30_COMPLETIONS");
        assertThat(auditoria.get(0).dadosNovos()).contains("\"challenge_id\"");
        assertThat(auditoria.get(0).usuarioBanco()).isNotBlank();
    }

    @Test
    void adesaoBaixa_abreAlertaEConclusoesSuficientesFecham() {
        // desafio de 11 dias com 1 conclusão => ~9% (< 50): a trigger abre ADESAO_BAIXA
        UUID usuario = UUID.randomUUID();
        UUID desafio = UUID.randomUUID();
        LocalDate inicio = LocalDate.now().minusDays(10);

        gateway.registrarConclusao(evento(usuario, desafio, inicio, 1));
        assertThat(alertasAbertosDeAdesao(usuario)).isEqualTo(1);

        gateway.registrarConclusao(evento(usuario, desafio, inicio, 2));
        assertThat(alertasAbertosDeAdesao(usuario)).as("sem duplicar enquanto aberto").isEqualTo(1);

        for (int dia = 3; dia <= 11; dia++) {
            gateway.registrarConclusao(evento(usuario, desafio, inicio, dia));
        }
        assertThat(alertasAbertosDeAdesao(usuario)).as("adesao 100% fecha o alerta").isZero();
        Integer resolvidos = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM l30_alerts WHERE user_id = ? AND alert_type = 'ADESAO_BAIXA' "
                        + "AND resolved = 1 AND resolved_at IS NOT NULL",
                Integer.class, usuario.toString());
        assertThat(resolvidos).isEqualTo(1);
    }

    @Test
    void consultaFiltrada_respeitaFiltrosEOrdenacao() {
        var todos = gateway.consultarEngajamento(filtro(null, null, OrdenacaoEngajamento.NOME, DirecaoOrdenacao.ASC));
        assertThat(todos).isNotEmpty();
        assertThat(todos).extracting(EngajamentoFiltrado::nome).isSorted();

        var nivel2 = gateway.consultarEngajamento(filtro(2, null, OrdenacaoEngajamento.NIVEL, DirecaoOrdenacao.DESC));
        assertThat(nivel2).allSatisfy(l -> assertThat(l.nivel()).isGreaterThanOrEqualTo(2));
        assertThat(nivel2).extracting(EngajamentoFiltrado::nivel).isSortedAccordingTo(java.util.Comparator.reverseOrder());

        var adesao = gateway.consultarEngajamento(
                filtro(null, java.math.BigDecimal.valueOf(50), OrdenacaoEngajamento.ADESAO, DirecaoOrdenacao.DESC));
        assertThat(adesao).allSatisfy(l -> assertThat(l.adesaoPercentual()).isGreaterThanOrEqualTo(java.math.BigDecimal.valueOf(50)));
    }

    @Test
    void injecaoNaOrdenacao_barradaPelaWhitelistDoPlsql() {
        // Contorna o enum do Java de propósito (SQL direto): prova que o PL/SQL se defende sozinho.
        assertThatThrownBy(() -> jdbcTemplate.queryForList(
                "SELECT pkg_l30_consultas.fn_engajamento_filtrado(p_ordenar_por => ?) FROM dual",
                "X; DROP TABLE l30_users"))
                .hasMessageContaining("ORA-20050");
        Integer tabela = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM user_tables WHERE table_name = 'L30_USERS'", Integer.class);
        assertThat(tabela).isEqualTo(1);
    }

    @Test
    void enumsDoJava_rejeitamValorForaDaLista() {
        assertThatThrownBy(() -> OrdenacaoEngajamento.de("X; DROP TABLE"))
                .isInstanceOf(RegraNegocioException.class);
        assertThatThrownBy(() -> DirecaoOrdenacao.de("DESC, 1"))
                .isInstanceOf(RegraNegocioException.class);
    }

    private static FiltroEngajamento filtro(Integer nivelMin, java.math.BigDecimal adesaoMin,
                                            OrdenacaoEngajamento ordem, DirecaoOrdenacao direcao) {
        return new FiltroEngajamento(null, null, nivelMin, adesaoMin, ordem, direcao);
    }

    private static int alertasAbertosDeAdesao(UUID usuario) {
        Integer n = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM l30_alerts WHERE user_id = ? AND alert_type = 'ADESAO_BAIXA' AND resolved = 0",
                Integer.class, usuario.toString());
        return n == null ? 0 : n;
    }

    private static DesafioConcluidoEvent evento(UUID usuario, UUID desafio, LocalDate inicio, int dia) {
        return new DesafioConcluidoEvent(usuario, "ZZ_TESTE_Fase7", 100, desafio, "Desafio fase 7",
                inicio, dia, dia, inicio.plusDays(dia - 1L), 10);
    }

    private static DesafioConcluidoEvent eventoValido() {
        LocalDate inicio = LocalDate.now().minusDays(11);
        return new DesafioConcluidoEvent(
                UUID.randomUUID(), "ZZ_TESTE_Aluno", 100,
                UUID.randomUUID(), "Desafio de teste",
                inicio, 12, 1,
                LocalDate.now(), 10);
    }

    // ---------------------------------------------------------------
    // Roda um script contra o Oracle real, delegando a divisão em statements para
    // OracleScriptParser (testado isoladamente, sem Docker, em OracleScriptParserTest).
    // ---------------------------------------------------------------

    private static void rodarScript(Path arquivo) throws IOException, SQLException {
        String conteudo = Files.readString(arquivo);
        try (Connection conn = dataSource.getConnection()) {
            for (OracleScriptParser.Statement statement : OracleScriptParser.dividirEmStatements(conteudo)) {
                try (Statement st = conn.createStatement()) {
                    st.execute(statement.sql());
                }
            }
        }
    }
}
