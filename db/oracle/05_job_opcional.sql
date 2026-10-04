-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 05_job_opcional.sql — Agenda pr_verificar_inatividade diariamente às 06h
--
-- Requer o privilégio CREATE JOB. Se o usuário não tiver (comum em
-- ambientes acadêmicos), o comando falha com ORA-27486 e a rotina
-- continua podendo ser acionada pelo backend (@Scheduled no Spring).
-- =====================================================================

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_L30_INATIVIDADE',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_alertas NUMBER; BEGIN pr_verificar_inatividade(3, v_alertas); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=0;BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Level30: alertas diários de inatividade');
END;
/

SELECT job_name, enabled, state, next_run_date
  FROM user_scheduler_jobs
 WHERE job_name = 'JOB_L30_INATIVIDADE';
