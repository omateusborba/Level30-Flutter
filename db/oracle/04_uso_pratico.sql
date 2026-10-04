-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 04_uso_pratico.sql — Functions em consultas e execução das procedures
-- Rode bloco a bloco no SQL Developer para capturar os prints do documento.
-- =====================================================================

SET SERVEROUTPUT ON

-- ---------------------------------------------------------------------
-- 1. Ranking de adesão dos últimos 30 dias (function no SELECT e ORDER BY)
-- ---------------------------------------------------------------------
SELECT u.name                  AS aluno,
       fn_taxa_adesao(u.id)    AS adesao_30d
  FROM l30_users u
 WHERE u.role = 'USER'
 ORDER BY adesao_30d DESC NULLS LAST;

-- ---------------------------------------------------------------------
-- 2. Resumo formatado de todos os alunos (dados prontos para a UI)
-- ---------------------------------------------------------------------
SELECT fn_resumo_usuario(u.id) AS resumo
  FROM l30_users u
 WHERE u.role = 'USER'
 ORDER BY u.name;

-- ---------------------------------------------------------------------
-- 3. Alunos que precisam de acompanhamento (function no WHERE)
-- ---------------------------------------------------------------------
SELECT u.name, u.email, fn_taxa_adesao(u.id) AS adesao_30d
  FROM l30_users u
 WHERE u.role = 'USER'
   AND fn_taxa_adesao(u.id) < 50
 ORDER BY adesao_30d;

-- ---------------------------------------------------------------------
-- 4. Tendência: última semana x últimos 30 dias (parâmetros de período)
-- ---------------------------------------------------------------------
SELECT aluno,
       adesao_7d,
       adesao_30d,
       CASE
           WHEN adesao_7d IS NULL OR adesao_30d IS NULL THEN 'SEM DADOS'
           WHEN adesao_7d >= adesao_30d + 10 THEN 'MELHORANDO'
           WHEN adesao_7d <= adesao_30d - 10 THEN 'PIORANDO'
           ELSE 'ESTÁVEL'
       END AS tendencia
  FROM (SELECT u.name AS aluno,
               fn_taxa_adesao(u.id, TRUNC(SYSDATE) - 6, TRUNC(SYSDATE)) AS adesao_7d,
               fn_taxa_adesao(u.id) AS adesao_30d
          FROM l30_users u
         WHERE u.role = 'USER')
 ORDER BY aluno;

-- ---------------------------------------------------------------------
-- 5. Adesão média do programa por desafio (function dentro de agregação)
-- ---------------------------------------------------------------------
SELECT c.title                                   AS desafio,
       COUNT(DISTINCT c.user_id)                 AS alunos,
       ROUND(AVG(fn_taxa_adesao(c.user_id)), 1)  AS adesao_media_30d
  FROM l30_challenges c
 WHERE c.status = 'ATIVO'
 GROUP BY c.title
 ORDER BY adesao_media_30d DESC NULLS LAST;

-- ---------------------------------------------------------------------
-- 6. Tratamento de exceções (cada comando deve falhar com a mensagem do projeto)
-- ---------------------------------------------------------------------
SELECT fn_taxa_adesao('00000000-0000-0000-0000-000000000000') FROM dual;   -- ORA-20003
SELECT fn_taxa_adesao(NULL) FROM dual;                                     -- ORA-20001
SELECT fn_taxa_adesao(id, SYSDATE, SYSDATE - 10) FROM l30_users WHERE ROWNUM = 1;  -- ORA-20002

-- ---------------------------------------------------------------------
-- 7. pr_verificar_inatividade — rotina automatizada de alertas
-- ---------------------------------------------------------------------
DECLARE
    v_alertas NUMBER;
BEGIN
    pr_verificar_inatividade(p_dias_limite => 3, p_alertas_gerados => v_alertas);
    DBMS_OUTPUT.PUT_LINE('Alertas de inatividade gerados: ' || v_alertas);
END;
/

SELECT u.name, a.severity, a.message, a.created_at
  FROM l30_alerts a
  JOIN l30_users  u ON u.id = a.user_id
 WHERE a.alert_type = 'INATIVIDADE'
   AND a.resolved   = 0
 ORDER BY CASE a.severity WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END, u.name;

-- ---------------------------------------------------------------------
-- 8. pr_gerar_relatorio_engajamento — relatório dos últimos 30 dias
-- ---------------------------------------------------------------------
DECLARE
    v_execucao NUMBER;
BEGIN
    pr_gerar_relatorio_engajamento(TRUNC(SYSDATE) - 29, TRUNC(SYSDATE), v_execucao);
    DBMS_OUTPUT.PUT_LINE('Relatório gerado. execution_id = ' || v_execucao);
END;
/

SELECT u.name, r.active_challenges, r.completions, r.adherence_rate,
       r.current_streak, r.engagement_band
  FROM l30_engagement_reports r
  JOIN l30_users u ON u.id = r.user_id
 WHERE r.execution_id = (SELECT MAX(execution_id) FROM l30_engagement_reports)
 ORDER BY r.adherence_rate DESC NULLS LAST;

-- Distribuição por faixa (visão do coordenador)
SELECT engagement_band, COUNT(*) AS alunos
  FROM l30_engagement_reports
 WHERE execution_id = (SELECT MAX(execution_id) FROM l30_engagement_reports)
 GROUP BY engagement_band
 ORDER BY alunos DESC;

-- ---------------------------------------------------------------------
-- 9. pr_registrar_conclusao — simula a chamada que o Java fará via JDBC
--    Conclui o próximo dia de um desafio ativo que ainda não foi feito hoje.
-- ---------------------------------------------------------------------
DECLARE
    v_alertas NUMBER;
    v_ch      l30_challenges%ROWTYPE;
    v_user    l30_users%ROWTYPE;
BEGIN
    SELECT c.* INTO v_ch
      FROM l30_challenges c
     WHERE c.status = 'ATIVO'
       AND c.current_day < 30
       AND NOT EXISTS (SELECT 1 FROM l30_completions cc
                        WHERE cc.challenge_id = c.id AND cc.completed_on = TRUNC(SYSDATE))
     ORDER BY c.last_activity_at NULLS FIRST
     FETCH FIRST 1 ROW ONLY;

    SELECT * INTO v_user FROM l30_users WHERE id = v_ch.user_id;

    pr_registrar_conclusao(
        p_user_id         => v_user.id,
        p_user_name       => v_user.name,
        p_total_xp        => v_user.total_xp + 12,
        p_challenge_id    => v_ch.id,
        p_title           => v_ch.title,
        p_start_date      => v_ch.start_date,
        p_day_number      => v_ch.current_day + 1,
        p_streak          => 1,
        p_completed_on    => TRUNC(SYSDATE),
        p_xp_delta        => 12,
        p_alertas_gerados => v_alertas);

    COMMIT;   -- no backend quem decide é a transação do Spring
    DBMS_OUTPUT.PUT_LINE(v_user.name || ' concluiu o dia ' || (v_ch.current_day + 1)
                         || ' de "' || v_ch.title || '". Alertas gerados: ' || v_alertas);
    DBMS_OUTPUT.PUT_LINE(fn_resumo_usuario(v_user.id));
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nenhum desafio ATIVO pendente para hoje. '
                             || 'Rode 02_carga_simulada.sql ou aguarde o próximo dia.');
END;
/

-- ---------------------------------------------------------------------
-- 10. Auditoria das rotinas
-- ---------------------------------------------------------------------
SELECT routine, status, rows_affected, detail, executed_at
  FROM l30_execution_log
 ORDER BY executed_at DESC
 FETCH FIRST 20 ROWS ONLY;
