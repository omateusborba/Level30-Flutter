package com.level30.api.gateway;

import com.level30.api.domain.engajamento.AlertaEngajamento;
import com.level30.api.domain.engajamento.EngajamentoFiltrado;
import com.level30.api.domain.engajamento.FiltroEngajamento;
import com.level30.api.domain.engajamento.RegistroAuditoria;
import com.level30.api.domain.engajamento.LinhaEngajamento;
import com.level30.api.domain.engajamento.RelatorioEngajamento;
import com.level30.api.domain.engajamento.ResumoEngajamentoUsuario;
import com.level30.api.domain.event.DesafioConcluidoEvent;
import com.level30.api.exception.CamadaOracleIndisponivelException;
import com.level30.api.exception.RecursoNaoEncontradoException;
import com.level30.api.exception.RegraNegocioException;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Component;

/**
 * Fase 6 — adapter ativo quando {@code level30.oracle.enabled=true}. Fala com os packages
 * {@code PKG_L30_ENGAJAMENTO} e {@code PKG_L30_CONSULTAS} ({@code db/oracle/06_..09_}; Fase 7) via {@link SimpleJdbcCall}/{@link JdbcTemplate}
 * puro (sem metadados de procedure — {@code withoutProcedureColumnMetaDataAccess}, mais rápido e
 * não depende de privilégio extra no schema).
 */
@Component
@ConditionalOnProperty(prefix = "level30.oracle", name = "enabled", havingValue = "true")
public class OracleEngajamentoGateway implements EngajamentoGateway {

    private static final String OUT_ALERTAS_GERADOS = "P_ALERTAS_GERADOS";
    private static final String RETORNO_CURSOR = "RETORNO";

    private static final RowMapper<EngajamentoFiltrado> LINHA_FILTRADA = (rs, rowNum) -> new EngajamentoFiltrado(
            rs.getString("USER_ID"),
            rs.getString("NOME"),
            rs.getInt("TOTAL_XP"),
            rs.getInt("NIVEL"),
            rs.getInt("STREAK"),
            rs.getInt("CONCLUSOES"),
            rs.getBigDecimal("ADESAO"),
            rs.getString("FAIXA"));

    private final JdbcTemplate oracleJdbcTemplate;
    private final SimpleJdbcCall registrarConclusaoCall;
    private final SimpleJdbcCall verificarInatividadeCall;
    private final SimpleJdbcCall gerarRelatorioCall;
    private final SimpleJdbcCall engajamentoFiltradoCall;

    public OracleEngajamentoGateway(@Qualifier("oracleJdbcTemplate") JdbcTemplate oracleJdbcTemplate,
                                    @Qualifier("oracleDataSource") DataSource oracleDataSource) {
        this.oracleJdbcTemplate = oracleJdbcTemplate;

        this.registrarConclusaoCall = new SimpleJdbcCall(oracleDataSource)
                .withCatalogName("PKG_L30_ENGAJAMENTO")
                .withProcedureName("PR_REGISTRAR_CONCLUSAO")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("P_USER_ID", Types.VARCHAR),
                        new SqlParameter("P_USER_NAME", Types.VARCHAR),
                        new SqlParameter("P_TOTAL_XP", Types.NUMERIC),
                        new SqlParameter("P_CHALLENGE_ID", Types.VARCHAR),
                        new SqlParameter("P_TITLE", Types.VARCHAR),
                        new SqlParameter("P_START_DATE", Types.DATE),
                        new SqlParameter("P_DAY_NUMBER", Types.NUMERIC),
                        new SqlParameter("P_STREAK", Types.NUMERIC),
                        new SqlParameter("P_COMPLETED_ON", Types.DATE),
                        new SqlParameter("P_XP_DELTA", Types.NUMERIC),
                        new SqlOutParameter(OUT_ALERTAS_GERADOS, Types.NUMERIC));

        this.verificarInatividadeCall = new SimpleJdbcCall(oracleDataSource)
                .withProcedureName("PR_VERIFICAR_INATIVIDADE")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("P_DIAS_LIMITE", Types.NUMERIC),
                        new SqlOutParameter(OUT_ALERTAS_GERADOS, Types.NUMERIC));

        this.gerarRelatorioCall = new SimpleJdbcCall(oracleDataSource)
                .withCatalogName("PKG_L30_ENGAJAMENTO")
                .withProcedureName("PR_GERAR_RELATORIO_ENGAJAMENTO")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("P_INICIO", Types.DATE),
                        new SqlParameter("P_FIM", Types.DATE),
                        new SqlOutParameter("P_EXECUCAO_ID", Types.NUMERIC));

        // Function com retorno SYS_REFCURSOR: o valor de retorno é declarado como OUT "return"
        // com RowMapper, e o resultado volta no mapa de saída sob essa chave.
        this.engajamentoFiltradoCall = new SimpleJdbcCall(oracleDataSource)
                .withCatalogName("PKG_L30_CONSULTAS")
                .withFunctionName("FN_ENGAJAMENTO_FILTRADO")
                .withoutProcedureColumnMetaDataAccess()
                .withReturnValue()
                .declareParameters(
                        new SqlOutParameter(RETORNO_CURSOR, Types.REF_CURSOR, LINHA_FILTRADA),
                        new SqlParameter("P_INICIO", Types.DATE),
                        new SqlParameter("P_FIM", Types.DATE),
                        new SqlParameter("P_NIVEL_MIN", Types.NUMERIC),
                        new SqlParameter("P_ADESAO_MIN", Types.NUMERIC),
                        new SqlParameter("P_ORDENAR_POR", Types.VARCHAR),
                        new SqlParameter("P_DIRECAO", Types.VARCHAR));
    }

    @Override
    public int registrarConclusao(DesafioConcluidoEvent evento) {
        try {
            Map<String, Object> params = new HashMap<>();
            params.put("P_USER_ID", evento.userId().toString());
            params.put("P_USER_NAME", evento.userName());
            params.put("P_TOTAL_XP", evento.totalXp());
            params.put("P_CHALLENGE_ID", evento.challengeId().toString());
            params.put("P_TITLE", evento.title());
            params.put("P_START_DATE", Date.valueOf(evento.startDate()));
            params.put("P_DAY_NUMBER", evento.dayNumber());
            params.put("P_STREAK", evento.streak());
            params.put("P_COMPLETED_ON", Date.valueOf(evento.completedOn()));
            params.put("P_XP_DELTA", evento.xpDelta());

            Map<String, Object> saida = registrarConclusaoCall.execute(params);
            return numero(saida.get(OUT_ALERTAS_GERADOS)).intValue();
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    public int verificarInatividade(int diasLimite) {
        try {
            Map<String, Object> saida = verificarInatividadeCall.execute(Map.of("P_DIAS_LIMITE", diasLimite));
            return numero(saida.get(OUT_ALERTAS_GERADOS)).intValue();
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    public RelatorioEngajamento gerarRelatorio(LocalDate inicio, LocalDate fim) {
        try {
            Map<String, Object> params = new HashMap<>();
            params.put("P_INICIO", Date.valueOf(inicio));
            params.put("P_FIM", Date.valueOf(fim));
            Map<String, Object> saida = gerarRelatorioCall.execute(params);
            long execucaoId = numero(saida.get("P_EXECUCAO_ID")).longValue();
            return buscarRelatorio(execucaoId);
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    public RelatorioEngajamento buscarRelatorio(long execucaoId) {
        try {
            List<LinhaEngajamento> linhas = oracleJdbcTemplate.query(
                    """
                    SELECT r.user_id, u.name, r.active_challenges, r.completions, r.adherence_rate,
                           r.current_streak, r.engagement_band
                      FROM l30_engagement_reports r
                      JOIN l30_users u ON u.id = r.user_id
                     WHERE r.execution_id = ?
                     ORDER BY u.name
                    """,
                    (rs, rowNum) -> new LinhaEngajamento(
                            rs.getString("user_id"),
                            rs.getString("name"),
                            rs.getInt("active_challenges"),
                            rs.getInt("completions"),
                            rs.getBigDecimal("adherence_rate"),
                            rs.getInt("current_streak"),
                            rs.getString("engagement_band")),
                    execucaoId);

            if (linhas.isEmpty()) {
                throw new RecursoNaoEncontradoException(
                        "Relatório de engajamento " + execucaoId + " não encontrado.");
            }

            // período via RowMapper + getObject(..., LocalDate.class): o driver Oracle devolve
            // colunas DATE como java.sql.Timestamp (tem hora), não java.sql.Date — um cast direto
            // pra java.sql.Date lança ClassCastException. getObject(_, LocalDate.class) converte
            // certo não importa qual subtipo de Date o driver escolheu devolver.
            var periodo = oracleJdbcTemplate.queryForObject(
                    "SELECT period_start, period_end FROM l30_engagement_reports WHERE execution_id = ? FETCH FIRST 1 ROW ONLY",
                    (rs, rowNum) -> new LocalDate[] {
                            rs.getObject("period_start", LocalDate.class),
                            rs.getObject("period_end", LocalDate.class)
                    },
                    execucaoId);
            LocalDate periodoInicio = periodo[0];
            LocalDate periodoFim = periodo[1];

            Map<String, Long> contagemPorFaixa = new LinkedHashMap<>();
            for (String faixa : List.of("ALTO", "MODERADO", "EM_RISCO", "CRITICO", "SEM_DESAFIO")) {
                contagemPorFaixa.put(faixa, 0L);
            }
            for (LinhaEngajamento linha : linhas) {
                contagemPorFaixa.merge(linha.faixa(), 1L, Long::sum);
            }

            return new RelatorioEngajamento(execucaoId, periodoInicio, periodoFim, contagemPorFaixa, linhas);
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    private static final String ALERTAS_BASE = """
            SELECT a.id, a.user_id, u.name, a.challenge_id, a.alert_type, a.severity,
                   a.message, a.measured_value, a.resolved, a.created_at
              FROM l30_alerts a
              JOIN l30_users u ON u.id = a.user_id
            """;
    private static final String ALERTAS_TODOS = ALERTAS_BASE + " ORDER BY a.created_at DESC";
    private static final String ALERTAS_ABERTOS =
            ALERTAS_BASE + " WHERE a.resolved = 0 ORDER BY a.created_at DESC";

    @Override
    public List<AlertaEngajamento> listarAlertas(boolean somenteAbertos) {
        try {
            String sql = somenteAbertos ? ALERTAS_ABERTOS : ALERTAS_TODOS;
            return oracleJdbcTemplate.query(sql, (rs, rowNum) -> {
                Timestamp criadoEm = rs.getTimestamp("created_at");
                return new AlertaEngajamento(
                        rs.getLong("id"),
                        rs.getString("user_id"),
                        rs.getString("name"),
                        rs.getString("challenge_id"),
                        rs.getString("alert_type"),
                        rs.getString("severity"),
                        rs.getString("message"),
                        rs.getBigDecimal("measured_value"),
                        rs.getInt("resolved") == 1,
                        criadoEm == null ? null : criadoEm.toInstant());
            });
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    public ResumoEngajamentoUsuario resumoUsuario(UUID userId) {
        try {
            return oracleJdbcTemplate.queryForObject(
                    "SELECT pkg_l30_engajamento.fn_resumo_usuario(id) AS resumo, pkg_l30_engajamento.fn_taxa_adesao(id) AS taxa FROM l30_users WHERE id = ?",
                    (rs, rowNum) -> new ResumoEngajamentoUsuario(
                            userId, rs.getString("resumo"), rs.getBigDecimal("taxa")),
                    userId.toString());
        } catch (EmptyResultDataAccessException e) {
            throw new RecursoNaoEncontradoException(
                    "Usuário " + userId + " não encontrado na réplica Oracle.");
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    @SuppressWarnings("unchecked")
    public List<EngajamentoFiltrado> consultarEngajamento(FiltroEngajamento filtro) {
        try {
            Map<String, Object> params = new HashMap<>();
            params.put("P_INICIO", filtro.inicio() == null ? null : Date.valueOf(filtro.inicio()));
            params.put("P_FIM", filtro.fim() == null ? null : Date.valueOf(filtro.fim()));
            params.put("P_NIVEL_MIN", filtro.nivelMin());
            params.put("P_ADESAO_MIN", filtro.adesaoMin());
            // só o name() do enum chega ao banco — nunca texto do cliente
            params.put("P_ORDENAR_POR", filtro.ordenarPor().name());
            params.put("P_DIRECAO", filtro.direcao().name());

            Map<String, Object> saida = engajamentoFiltradoCall.execute(params);
            return (List<EngajamentoFiltrado>) saida.get(RETORNO_CURSOR);
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    @Override
    public List<RegistroAuditoria> listarAuditoria(int limite) {
        try {
            return oracleJdbcTemplate.query(
                    """
                    SELECT id, tabela, operacao, registro_id, dados_antigos, dados_novos,
                           usuario_banco, criado_em
                      FROM l30_audit_log
                     ORDER BY id DESC
                     FETCH FIRST ? ROWS ONLY
                    """,
                    (rs, rowNum) -> {
                        Timestamp criadoEm = rs.getTimestamp("criado_em");
                        return new RegistroAuditoria(
                                rs.getLong("id"),
                                rs.getString("tabela"),
                                rs.getString("operacao"),
                                rs.getString("registro_id"),
                                rs.getString("dados_antigos"),
                                rs.getString("dados_novos"),
                                rs.getString("usuario_banco"),
                                criadoEm == null ? null : criadoEm.toInstant());
                    },
                    limite);
        } catch (DataAccessException e) {
            throw traduzir(e);
        }
    }

    // ---------------------------------------------------------------
    // Tradução de erros Oracle -> exceções da aplicação
    // ---------------------------------------------------------------

    /**
     * ORA-20000..ORA-20999 são erros de negócio levantados pelo PL/SQL do projeto
     * (RAISE_APPLICATION_ERROR, ver cabeçalho de {@code 03_plsql.sql}) -&gt; 422, com a primeira
     * linha da mensagem, sem o prefixo {@code ORA-2xxxx:}. Qualquer outra falha de acesso a dados
     * (Oracle fora do ar, timeout, rede) -&gt; 503.
     */
    private RuntimeException traduzir(DataAccessException e) {
        // O driver Oracle aninha o erro real (oracle.jdbc.OracleDatabaseException, que não é
        // SQLException) dentro do SQLException; getMostSpecificCause() pararia nele. Percorre a
        // cadeia inteira atrás de um SQLException na faixa de erros de negócio.
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql && sql.getErrorCode() >= 20000 && sql.getErrorCode() <= 20999) {
                return new RegraNegocioException(primeiraLinhaSemPrefixo(sql.getMessage()), HttpStatus.UNPROCESSABLE_ENTITY);
            }
            if (t.getCause() == t) {
                break;
            }
        }
        return new CamadaOracleIndisponivelException("Camada Oracle indisponível.", e);
    }

    private String primeiraLinhaSemPrefixo(String mensagem) {
        if (mensagem == null) {
            return "Erro de negócio no Oracle.";
        }
        String primeiraLinha = mensagem.lines().findFirst().orElse(mensagem).trim();
        return primeiraLinha.replaceFirst("^ORA-\\d+:\\s*", "");
    }

    private Number numero(Object valor) {
        return valor instanceof Number n ? n : 0;
    }
}
