package com.level30.api.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.level30.api.exception.CamadaOracleIndisponivelException;
import com.level30.api.exception.RegraNegocioException;
import java.sql.SQLException;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

/**
 * Fase 6 — tradução de erro do {@link OracleEngajamentoGateway}: códigos ORA-20000..20999 (erros
 * de negócio levantados pelo PL/SQL do projeto, ver {@code db/oracle/03_plsql.sql}) viram 422;
 * qualquer outro erro de acesso a dados (ex.: ORA-17002, conexão perdida) vira 503. Não precisa de
 * Oracle de verdade — {@link JdbcTemplate} é mockado para devolver a exceção exatamente como o
 * driver Oracle devolveria.
 */
class OracleEngajamentoGatewayTest {

    private final JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
    private final DataSource dataSource = mock(DataSource.class);
    private final OracleEngajamentoGateway gateway =
            new OracleEngajamentoGateway(jdbcTemplate, dataSource);

    @Test
    @SuppressWarnings("unchecked")
    void erroDeNegocio_20003_viraRegraNegocioException422SemPrefixoOra() {
        SQLException erroOracle = new SQLException(
                "ORA-20003: fn_taxa_adesao: usuário abc não encontrado\nORA-06512: at \"LEVEL30.FN_TAXA_ADESAO\", line 42",
                "72000", 20003);
        when(jdbcTemplate.query(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.any(RowMapper.class)))
                .thenThrow(new UncategorizedSQLException("query", "select ...", erroOracle));

        assertThatThrownBy(() -> gateway.listarAlertas(true))
                .isInstanceOf(RegraNegocioException.class)
                .hasMessage("fn_taxa_adesao: usuário abc não encontrado")
                .satisfies(e -> assertThat(((RegraNegocioException) e).getStatus())
                        .isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY));
    }

    @Test
    @SuppressWarnings("unchecked")
    void erroDeAcessoFora20000a20999_viraCamadaOracleIndisponivelException503() {
        // ORA-17002 — falha de I/O / conexão perdida com o Oracle (fora da faixa de negócio).
        SQLException erroConexao = new SQLException("Io exception: Connection reset", "08006", 17002);
        when(jdbcTemplate.query(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.any(RowMapper.class)))
                .thenThrow(new UncategorizedSQLException("query", "select ...", erroConexao));

        assertThatThrownBy(() -> gateway.listarAlertas(true))
                .isInstanceOf(CamadaOracleIndisponivelException.class);
    }
}
