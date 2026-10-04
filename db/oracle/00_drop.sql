-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 00_drop.sql — Remove os objetos do projeto (pode rodar várias vezes)
--
-- Remove SOMENTE objetos com prefixo L30_ e as rotinas PL/SQL do projeto.
-- Seguro para schemas compartilhados (ex.: usuário RM da FIAP).
-- =====================================================================

DECLARE
    PROCEDURE executar_se_existir (p_comando IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_comando;
    EXCEPTION
        WHEN OTHERS THEN
            -- -942 tabela | -4043 objeto | -2289 sequence | -27475 job inexistente
            IF SQLCODE NOT IN (-942, -4043, -2289, -27475) THEN
                RAISE;
            END IF;
    END executar_se_existir;
BEGIN
    executar_se_existir('BEGIN DBMS_SCHEDULER.DROP_JOB(''JOB_L30_INATIVIDADE''); END;');

    executar_se_existir('DROP PROCEDURE pr_gerar_relatorio_engajamento');
    executar_se_existir('DROP PROCEDURE pr_verificar_inatividade');
    executar_se_existir('DROP PROCEDURE pr_registrar_conclusao');
    executar_se_existir('DROP PROCEDURE pr_log_execucao');
    executar_se_existir('DROP FUNCTION fn_resumo_usuario');
    executar_se_existir('DROP FUNCTION fn_taxa_adesao');

    executar_se_existir('DROP TABLE l30_engagement_reports CASCADE CONSTRAINTS PURGE');
    executar_se_existir('DROP TABLE l30_alerts CASCADE CONSTRAINTS PURGE');
    executar_se_existir('DROP TABLE l30_completions CASCADE CONSTRAINTS PURGE');
    executar_se_existir('DROP TABLE l30_challenges CASCADE CONSTRAINTS PURGE');
    executar_se_existir('DROP TABLE l30_users CASCADE CONSTRAINTS PURGE');
    executar_se_existir('DROP TABLE l30_execution_log CASCADE CONSTRAINTS PURGE');

    executar_se_existir('DROP SEQUENCE seq_l30_report_execution');
END;
/
