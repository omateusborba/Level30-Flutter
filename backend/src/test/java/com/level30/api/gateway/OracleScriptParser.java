package com.level30.api.gateway;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Fase 6 — divide um script `.sql` no estilo SQL*Plus (como os de {@code db/oracle/}) na lista de
 * statements que cada um vira ao rodar via JDBC puro. Extraído de
 * {@link OracleEngajamentoGatewayIT} para poder ser testado sem Docker — ver
 * {@code OracleScriptParserTest}, que roda contra os arquivos reais.
 *
 * <p>Regras (nessa ordem):
 * <ol>
 *   <li>Descarta comandos SQL*Plus de configuração em linha própria ({@code SET SERVEROUTPUT},
 *       {@code SPOOL}, {@code PROMPT}, etc.) — inválidos via JDBC. A lista de palavras de
 *       {@code SET} é explícita (não um {@code SET\b} genérico) de propósito: os scripts têm
 *       {@code UPDATE ... SET coluna = valor} de verdade (ex.: {@code pr_registrar_conclusao},
 *       a carga simulada), e um regex genérico apagaria essas linhas.</li>
 *   <li>Cada linha contendo só {@code /} encerra um bloco PL/SQL: o trecho desde o fim do bloco
 *       anterior (ou do início do arquivo) até ali é <strong>um</strong> statement — inteiro,
 *       com o {@code END nome;} final preservado e nenhum {@code ;} interno removido. Um arquivo
 *       com N linhas {@code /} vira N blocos PL/SQL distintos, não um só.</li>
 *   <li>O que sobra depois do último {@code /} (ou o arquivo inteiro, se não houver nenhum) é SQL
 *       simples, fatiado por {@code ;}; fragmentos vazios ou só com comentários são descartados.</li>
 * </ol>
 */
final class OracleScriptParser {

    private static final Pattern DIRETIVA_SQLPLUS = Pattern.compile(
            "(?im)^[ \\t]*(SET[ \\t]+(SERVEROUTPUT|ECHO|FEEDBACK|LINESIZE|PAGESIZE|VERIFY|TIMING|"
                    + "HEADING|TRIMSPOOL|SCAN|DEFINE|SQLBLANKLINES|AUTOCOMMIT|ARRAYSIZE|LONG|WRAP)\\b.*"
                    + "|SPOOL\\b.*|PROMPT\\b.*)$");

    private static final Pattern DELIMITADOR_BLOCO = Pattern.compile("(?m)^[ \\t]*/[ \\t]*$");

    private OracleScriptParser() {
    }

    /** Um statement pronto para {@code Statement#execute}, com a origem (bloco PL/SQL ou SQL simples). */
    record Statement(String sql, boolean plsql) {
    }

    static List<Statement> dividirEmStatements(String conteudoScript) {
        String semDiretivas = DIRETIVA_SQLPLUS.matcher(conteudoScript).replaceAll("");
        String[] partes = DELIMITADOR_BLOCO.split(semDiretivas);

        List<Statement> statements = new ArrayList<>();

        // Cada parte ANTES da última veio seguida de uma linha "/" — é, por definição, um bloco
        // PL/SQL completo (é exatamente o que esse delimitador significa no SQL*Plus).
        for (int i = 0; i < partes.length - 1; i++) {
            String bloco = partes[i].strip();
            if (!bloco.isEmpty() && !ehSoComentario(bloco)) {
                statements.add(new Statement(bloco, true));
            }
        }

        // O restante (depois do último "/", ou o arquivo inteiro se não houver nenhum "/") é SQL
        // simples terminado por ";".
        String resto = partes.length == 0 ? "" : partes[partes.length - 1];
        for (String stmt : resto.split(";")) {
            String s = stmt.strip();
            if (!s.isEmpty() && !ehSoComentario(s)) {
                statements.add(new Statement(s, false));
            }
        }

        return statements;
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
}
