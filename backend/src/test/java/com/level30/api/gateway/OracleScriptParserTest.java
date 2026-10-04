package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.Test;

/**
 * Fase 6 — {@link OracleScriptParser} testado sem Docker, direto contra o conteúdo real de
 * {@code db/oracle/}. Não é {@code @Tag("oracle")}: roda no build padrão (não depende de Oracle,
 * só lê arquivo e aplica regex), então toda mudança nos scripts ou no parser quebra este teste
 * antes de chegar no {@code OracleEngajamentoGatewayIT} (que precisa de Docker).
 */
class OracleScriptParserTest {

    private static final Path PASTA_SCRIPTS = Path.of("..", "db", "oracle");

    @Test
    void ddl_naoTemBlocoPlsql_e27StatementsSimples() throws IOException {
        List<OracleScriptParser.Statement> statements = parsear("01_ddl.sql");

        assertThat(statements).hasSize(27);
        assertThat(statements).allMatch(s -> !s.plsql());
        assertThat(statements).filteredOn(s -> s.sql().toUpperCase(Locale.ROOT).contains("CREATE TABLE"))
                .hasSize(6);
        assertThat(statements).filteredOn(s -> s.sql().toUpperCase(Locale.ROOT).contains("CREATE SEQUENCE"))
                .hasSize(1);
    }

    @Test
    void cargaSimulada_umBlocoPlsqlMaisUmSelect_semDiretivaSet() throws IOException {
        List<OracleScriptParser.Statement> statements = parsear("02_carga_simulada.sql");

        assertThat(statements).hasSize(2);

        OracleScriptParser.Statement bloco = statements.get(0);
        assertThat(bloco.plsql()).isTrue();
        // O chunk inclui o comentário de cabeçalho do arquivo antes do DECLARE (não há "/"
        // separando os dois) — comentário líder é SQL válido, por isso "contains", não "starts".
        assertThat(bloco.sql()).containsIgnoringCase("DECLARE");
        assertThat(bloco.sql()).endsWith("END;");

        OracleScriptParser.Statement select = statements.get(1);
        assertThat(select.plsql()).isFalse();
        assertThat(select.sql().toUpperCase(Locale.ROOT)).contains("SELECT");

        // A diretiva "SET SERVEROUTPUT ON" (linha própria, antes do DECLARE) não pode sobrar em
        // nenhum statement — nem grudada no bloco PL/SQL, nem como statement isolado.
        assertThat(statements).noneMatch(s -> s.sql().toUpperCase(Locale.ROOT).startsWith("SET "));
        assertThat(statements).noneMatch(s -> s.sql().toUpperCase(Locale.ROOT).contains("SERVEROUTPUT"));
    }

    @Test
    void plsql_seisBlocosCreateOrReplaceMaisUmSelectFinal() throws IOException {
        List<OracleScriptParser.Statement> statements = parsear("03_plsql.sql");

        assertThat(statements).hasSize(7);

        List<OracleScriptParser.Statement> blocos = statements.subList(0, 6);
        List<String> nomesEsperados = List.of(
                "pr_log_execucao", "fn_taxa_adesao", "fn_resumo_usuario",
                "pr_registrar_conclusao", "pr_verificar_inatividade", "pr_gerar_relatorio_engajamento");

        assertThat(blocos).allMatch(OracleScriptParser.Statement::plsql);
        // O primeiro bloco inclui o comentário de cabeçalho do arquivo antes do CREATE OR
        // REPLACE (não há "/" separando os dois) — comentário líder é SQL válido, daí "contains".
        assertThat(blocos).allMatch(b -> b.sql().toUpperCase(Locale.ROOT).contains("CREATE OR REPLACE"));
        for (int i = 0; i < blocos.size(); i++) {
            assertThat(blocos.get(i).sql()).endsWith("END " + nomesEsperados.get(i) + ";");
        }

        OracleScriptParser.Statement select = statements.get(6);
        assertThat(select.plsql()).isFalse();
        assertThat(select.sql().toUpperCase(Locale.ROOT)).contains("SELECT");
        assertThat(select.sql().toUpperCase(Locale.ROOT)).contains("USER_OBJECTS");
    }

    private static List<OracleScriptParser.Statement> parsear(String arquivo) throws IOException {
        String conteudo = Files.readString(PASTA_SCRIPTS.resolve(arquivo));
        return OracleScriptParser.dividirEmStatements(conteudo);
    }
}
