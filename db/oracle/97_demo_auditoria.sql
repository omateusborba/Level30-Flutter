-- =====================================================================
-- Level30 · Smart HAS — Fase 7 (roteiro de demonstração)
-- 97_demo_auditoria.sql — gera UM UPDATE e UM DELETE em L30_COMPLETIONS para a tabela de auditoria
-- (aba Oracle do dashboard) mostrar as três operações (o INSERT vem de qualquer conclusão feita no app).
--
--   UPDATE: ajusta o XP da conclusão mais recente da Elisa Castro (+5)
--   DELETE: apaga a conclusão mais antiga do Henrique Dias
--
-- É uma alteração só na réplica Oracle (o PostgreSQL não muda): depois da gravação, rode
-- scripts/demo-reset.sh para voltar os dois bancos ao estado consistente.
-- TRAVA: só roda em banco local/de demo (mesma regra do 98_limpa_residuo_testes.sql).
-- Pré-requisito: base criada por scripts/demo-seed.sh.
-- =====================================================================
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
    v_servico VARCHAR2(128) := UPPER(SYS_CONTEXT('USERENV', 'SERVICE_NAME'));
    v_id      NUMBER;
    v_n       NUMBER;
BEGIN
    IF v_servico NOT IN ('FREEPDB1', 'FREE', 'XEPDB1') AND v_servico NOT LIKE '%DEMO%' THEN
        RAISE_APPLICATION_ERROR(-20990,
            '97_demo_auditoria: serviço ' || v_servico || ' não é local nem de demo; nada foi alterado');
    END IF;

    -- UPDATE
    SELECT id INTO v_id FROM (
        SELECT cc.id FROM l30_completions cc JOIN l30_users u ON u.id = cc.user_id
         WHERE u.name = 'Elisa Castro' ORDER BY cc.completed_on DESC, cc.id DESC)
     WHERE ROWNUM = 1;
    UPDATE l30_completions SET xp_delta = xp_delta + 5 WHERE id = v_id;
    DBMS_OUTPUT.PUT_LINE('UPDATE na conclusão #' || v_id || ' (Elisa Castro)');

    -- DELETE
    SELECT id INTO v_id FROM (
        SELECT cc.id FROM l30_completions cc JOIN l30_users u ON u.id = cc.user_id
         WHERE u.name = 'Henrique Dias' ORDER BY cc.completed_on ASC, cc.id ASC)
     WHERE ROWNUM = 1;
    DELETE FROM l30_completions WHERE id = v_id;
    DBMS_OUTPUT.PUT_LINE('DELETE na conclusão #' || v_id || ' (Henrique Dias)');
    COMMIT;

    SELECT COUNT(DISTINCT operacao) INTO v_n FROM l30_audit_log;
    DBMS_OUTPUT.PUT_LINE('Operações distintas na auditoria agora: ' || v_n);
END;
/
SELECT operacao, COUNT(*) AS linhas FROM l30_audit_log GROUP BY operacao ORDER BY operacao;
EXIT
