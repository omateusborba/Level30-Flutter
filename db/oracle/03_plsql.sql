-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 03_plsql.sql — Functions e procedures
--
--   pr_log_execucao                (apoio)  auditoria em transação autônoma
--   fn_taxa_adesao                 FUNCTION indicador: % de adesão no período
--   fn_resumo_usuario              FUNCTION dados formatados do aluno
--   pr_registrar_conclusao         PROCEDURE acionada pelo backend Java (JDBC)
--   pr_verificar_inatividade       PROCEDURE rotina de alertas (cursor FOR)
--   pr_gerar_relatorio_engajamento PROCEDURE relatório por usuário (OPEN/FETCH)
--
-- Códigos de erro do projeto:
--   -20001..-20009  parâmetros das functions
--   -20010..-20019  pr_registrar_conclusao
--   -20020..-20029  pr_verificar_inatividade
--   -20030..-20039  pr_gerar_relatorio_engajamento
--   -20099          erro inesperado encapsulado
--
-- Controle de transação:
--   pr_registrar_conclusao NÃO faz COMMIT — quem chama (Spring) decide.
--   As rotinas batch (inatividade e relatório) fazem COMMIT ao final.
-- =====================================================================


-- ---------------------------------------------------------------------
-- pr_log_execucao
-- Grava o log em transação autônoma: o registro persiste mesmo que a
-- rotina que chamou faça ROLLBACK. Falha no log nunca derruba a rotina.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_log_execucao (
    p_rotina   IN VARCHAR2,
    p_status   IN VARCHAR2,
    p_detalhe  IN VARCHAR2 DEFAULT NULL,
    p_linhas   IN NUMBER   DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO l30_execution_log (routine, status, detail, rows_affected)
    VALUES (SUBSTR(p_rotina, 1, 60), p_status, SUBSTR(p_detalhe, 1, 1000), p_linhas);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;   -- intencional: auditoria não pode interromper o fluxo principal
END pr_log_execucao;
/


-- ---------------------------------------------------------------------
-- fn_taxa_adesao  (FUNCTION — indicador)
--
-- Percentual de dias com conclusão sobre os dias em que o aluno tinha
-- desafio aberto no período.
--   dias esperados  = soma, por desafio, dos dias do período entre o
--                     início do desafio e seu encerramento (ou hoje)
--   dias realizados = conclusões registradas no período
--
-- Parâmetros IN:
--   p_user_id  UUID do usuário (obrigatório)
--   p_inicio   início do período (padrão: 29 dias antes de p_fim)
--   p_fim      fim do período    (padrão: hoje)
-- RETURN: NUMBER(5,2) entre 0 e 100, ou NULL se não havia desafio aberto.
-- Exceções: -20001 usuário nulo · -20002 período inválido ·
--           -20003 usuário inexistente
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_taxa_adesao (
    p_user_id  IN l30_users.id%TYPE,
    p_inicio   IN DATE DEFAULT NULL,
    p_fim      IN DATE DEFAULT NULL
) RETURN NUMBER IS
    v_fim        DATE := TRUNC(NVL(p_fim, SYSDATE));
    v_inicio     DATE := NVL(TRUNC(p_inicio), v_fim - 29);
    v_existe     NUMBER;
    v_esperados  NUMBER;
    v_realizados NUMBER;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'fn_taxa_adesao: p_user_id é obrigatório');
    END IF;

    IF v_inicio > v_fim THEN
        RAISE_APPLICATION_ERROR(-20002, 'fn_taxa_adesao: início posterior ao fim do período');
    END IF;

    SELECT 1 INTO v_existe FROM l30_users WHERE id = p_user_id;   -- NO_DATA_FOUND se não existir

    SELECT NVL(SUM(GREATEST(
                   LEAST(v_fim, NVL(c.ended_on, v_fim)) - GREATEST(v_inicio, c.start_date) + 1,
                   0)), 0)
      INTO v_esperados
      FROM l30_challenges c
     WHERE c.user_id    = p_user_id
       AND c.start_date <= v_fim;

    IF v_esperados = 0 THEN
        RETURN NULL;   -- sem desafio aberto no período: indicador não se aplica
    END IF;

    SELECT COUNT(*)
      INTO v_realizados
      FROM l30_completions cc
     WHERE cc.user_id = p_user_id
       AND cc.completed_on BETWEEN v_inicio AND v_fim;

    RETURN ROUND(LEAST(v_realizados / v_esperados * 100, 100), 2);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'fn_taxa_adesao: usuário ' || p_user_id || ' não encontrado');
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN
            RAISE;   -- erro de negócio já tratado acima
        END IF;
        RAISE_APPLICATION_ERROR(-20099, 'fn_taxa_adesao: ' || SQLERRM);
END fn_taxa_adesao;
/


-- ---------------------------------------------------------------------
-- fn_resumo_usuario  (FUNCTION — dados formatados)
--
-- Linha pronta para exibição no dashboard ou em notificação.
-- Ex.: "Ana Souza | 1.250 XP | 2 desafios ativos | streak de 12 dias | adesão 30d: 83,5%"
--
-- Parâmetro IN: p_user_id
-- RETURN: VARCHAR2 formatado no padrão brasileiro (milhar com ponto,
--         decimal com vírgula).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_resumo_usuario (
    p_user_id IN l30_users.id%TYPE
) RETURN VARCHAR2 IS
    c_nls      CONSTANT VARCHAR2(40) := 'NLS_NUMERIC_CHARACTERS='',.''';
    v_nome     l30_users.name%TYPE;
    v_xp       l30_users.total_xp%TYPE;
    v_ativos   NUMBER;
    v_streak   NUMBER;
    v_taxa     NUMBER;
    v_taxa_txt VARCHAR2(40);
BEGIN
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'fn_resumo_usuario: p_user_id é obrigatório');
    END IF;

    SELECT name, total_xp
      INTO v_nome, v_xp
      FROM l30_users
     WHERE id = p_user_id;

    SELECT COUNT(*), NVL(MAX(streak), 0)
      INTO v_ativos, v_streak
      FROM l30_challenges
     WHERE user_id = p_user_id
       AND status  = 'ATIVO';

    v_taxa := fn_taxa_adesao(p_user_id);

    IF v_taxa IS NULL THEN
        v_taxa_txt := 'sem desafio no período';
    ELSE
        v_taxa_txt := TO_CHAR(v_taxa, 'FM990D0', c_nls) || '%';
    END IF;

    RETURN v_nome
        || ' | ' || TO_CHAR(v_xp, 'FM999G999G990', c_nls) || ' XP'
        || ' | ' || v_ativos || CASE WHEN v_ativos = 1 THEN ' desafio ativo' ELSE ' desafios ativos' END
        || ' | streak de ' || v_streak || CASE WHEN v_streak = 1 THEN ' dia' ELSE ' dias' END
        || ' | adesão 30d: ' || v_taxa_txt;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Usuário não encontrado';
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN
            RAISE;
        END IF;
        RAISE_APPLICATION_ERROR(-20099, 'fn_resumo_usuario: ' || SQLERRM);
END fn_resumo_usuario;
/


-- ---------------------------------------------------------------------
-- pr_registrar_conclusao  (PROCEDURE — acionada pelo backend Java)
--
-- Fluxo: app Flutter → POST /challenges/{id}/complete → Spring Boot
--        grava no PostgreSQL → chama esta procedure via JDBC.
--
-- 1. Sincroniza a réplica do usuário e do desafio (MERGE)
-- 2. Registra o evento de conclusão (idempotente: reentrega é ignorada)
-- 3. Resolve alertas de inatividade abertos daquele desafio
-- 4. Gera alerta se a sequência foi reiniciada
-- 5. Gera alerta se a adesão de 30 dias continua abaixo de 50%
--
-- OUT p_alertas_gerados: quantos alertas novos foram criados.
-- Não faz COMMIT: participa da transação de quem chama.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_registrar_conclusao (
    p_user_id          IN  l30_users.id%TYPE,
    p_user_name        IN  l30_users.name%TYPE,
    p_total_xp         IN  l30_users.total_xp%TYPE,
    p_challenge_id     IN  l30_challenges.id%TYPE,
    p_title            IN  l30_challenges.title%TYPE,
    p_start_date       IN  DATE,
    p_day_number       IN  NUMBER,
    p_streak           IN  NUMBER,
    p_completed_on     IN  DATE,
    p_xp_delta         IN  NUMBER,
    p_alertas_gerados  OUT NUMBER
) IS
    c_rotina        CONSTANT VARCHAR2(30) := 'PR_REGISTRAR_CONCLUSAO';
    c_limite_adesao CONSTANT NUMBER := 50;
    v_data          DATE := TRUNC(p_completed_on);
    v_titulo        l30_challenges.title%TYPE := NVL(p_title, 'Desafio');
    v_taxa          NUMBER;
BEGIN
    SAVEPOINT sp_registrar_conclusao;
    p_alertas_gerados := 0;

    IF p_user_id IS NULL OR p_challenge_id IS NULL OR v_data IS NULL OR p_day_number IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, c_rotina || ': usuário, desafio, data e dia são obrigatórios');
    END IF;

    IF p_day_number NOT BETWEEN 1 AND 30 THEN
        RAISE_APPLICATION_ERROR(-20011, c_rotina || ': dia ' || p_day_number || ' fora do intervalo 1-30');
    END IF;

    -- 1a. Réplica do usuário
    MERGE INTO l30_users u
    USING (SELECT p_user_id AS id,
                  NVL(p_user_name, 'Usuário ' || SUBSTR(p_user_id, 1, 8)) AS name,
                  NVL(p_total_xp, 0) AS total_xp
             FROM dual) s
       ON (u.id = s.id)
     WHEN MATCHED THEN
          UPDATE SET u.name = s.name, u.total_xp = s.total_xp, u.synced_at = SYSTIMESTAMP
     WHEN NOT MATCHED THEN
          INSERT (id, name, total_xp, synced_at)
          VALUES (s.id, s.name, s.total_xp, SYSTIMESTAMP);

    -- 1b. Réplica do desafio
    MERGE INTO l30_challenges c
    USING (SELECT p_challenge_id AS id,
                  p_user_id      AS user_id,
                  v_titulo       AS title,
                  NVL(TRUNC(p_start_date), v_data - (p_day_number - 1)) AS start_date,
                  p_day_number   AS day_number,
                  NVL(p_streak, 0) AS streak,
                  v_data         AS completed_on
             FROM dual) s
       ON (c.id = s.id)
     WHEN MATCHED THEN
          UPDATE SET c.current_day      = GREATEST(c.current_day, s.day_number),
                     c.streak           = s.streak,
                     c.status           = CASE WHEN s.day_number = 30 THEN 'CONCLUIDO' ELSE 'ATIVO' END,
                     c.ended_on         = CASE WHEN s.day_number = 30 THEN s.completed_on END,
                     c.last_activity_at = SYSTIMESTAMP
     WHEN NOT MATCHED THEN
          INSERT (id, user_id, title, start_date, current_day, streak, status, ended_on, last_activity_at)
          VALUES (s.id, s.user_id, s.title, s.start_date, s.day_number, s.streak,
                  CASE WHEN s.day_number = 30 THEN 'CONCLUIDO' ELSE 'ATIVO' END,
                  CASE WHEN s.day_number = 30 THEN s.completed_on END,
                  SYSTIMESTAMP);

    -- 2. Evento de conclusão (idempotente)
    BEGIN
        INSERT INTO l30_completions (challenge_id, user_id, day_number, completed_on, xp_delta)
        VALUES (p_challenge_id, p_user_id, p_day_number, v_data, NVL(p_xp_delta, 0));
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            pr_log_execucao(c_rotina, 'SUCESSO',
                            'Evento duplicado ignorado: desafio=' || p_challenge_id || ' dia=' || p_day_number, 0);
            RETURN;   -- mesma conclusão reenviada: réplica atualizada, sem regras de novo
    END;

    -- 3. Concluir o dia resolve a inatividade daquele desafio
    UPDATE l30_alerts
       SET resolved    = 1,
           resolved_at = SYSTIMESTAMP
     WHERE challenge_id = p_challenge_id
       AND alert_type   = 'INATIVIDADE'
       AND resolved     = 0;

    -- 4. Sequência reiniciada depois de uma quebra
    IF NVL(p_streak, 0) = 1 AND p_day_number > 1 THEN
        INSERT INTO l30_alerts (user_id, challenge_id, alert_type, severity, message, measured_value)
        VALUES (p_user_id, p_challenge_id, 'STREAK_REINICIADO', 'BAIXA',
                'Sequência reiniciada no dia ' || p_day_number || ' do desafio "' || v_titulo || '"',
                p_day_number);
        p_alertas_gerados := p_alertas_gerados + 1;
    END IF;

    -- 5. Adesão ainda baixa, mesmo com a conclusão de hoje
    v_taxa := fn_taxa_adesao(p_user_id);

    IF v_taxa IS NOT NULL AND v_taxa < c_limite_adesao THEN
        INSERT INTO l30_alerts (user_id, challenge_id, alert_type, severity, message, measured_value)
        SELECT p_user_id, NULL, 'ADESAO_BAIXA',
               CASE WHEN v_taxa < 25 THEN 'ALTA' ELSE 'MEDIA' END,
               'Adesão de 30 dias em ' || TO_CHAR(v_taxa, 'FM990D0', 'NLS_NUMERIC_CHARACTERS='',.''')
               || '%, abaixo da meta de ' || c_limite_adesao || '%',
               v_taxa
          FROM dual
         WHERE NOT EXISTS (SELECT 1
                             FROM l30_alerts a
                            WHERE a.user_id    = p_user_id
                              AND a.alert_type = 'ADESAO_BAIXA'
                              AND a.resolved   = 0);
        p_alertas_gerados := p_alertas_gerados + SQL%ROWCOUNT;
    END IF;

    pr_log_execucao(c_rotina, 'SUCESSO',
                    'desafio=' || p_challenge_id || ' dia=' || p_day_number
                    || ' alertas=' || p_alertas_gerados, 1);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO sp_registrar_conclusao;
        pr_log_execucao(c_rotina, 'ERRO', SQLERRM);
        RAISE;
END pr_registrar_conclusao;
/


-- ---------------------------------------------------------------------
-- pr_verificar_inatividade  (PROCEDURE — rotina automatizada de alertas)
--
-- Percorre os desafios ATIVOS sem conclusão há p_dias_limite dias ou
-- mais e registra um alerta de INATIVIDADE (um por desafio enquanto
-- estiver aberto). Severidade por tempo parado:
--   3 a 6 dias BAIXA · 7 a 13 dias MEDIA · 14+ dias ALTA
--
-- Pode ser agendada via DBMS_SCHEDULER (ver 05_job_opcional.sql).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_verificar_inatividade (
    p_dias_limite      IN  NUMBER DEFAULT 3,
    p_alertas_gerados  OUT NUMBER
) IS
    c_rotina     CONSTANT VARCHAR2(30) := 'PR_VERIFICAR_INATIVIDADE';
    v_severidade l30_alerts.severity%TYPE;

    CURSOR c_desafios_parados (cp_limite NUMBER) IS
        SELECT c.id,
               c.user_id,
               c.title,
               TRUNC(SYSDATE) - NVL(TRUNC(CAST(c.last_activity_at AS DATE)), c.start_date) AS dias_parado
          FROM l30_challenges c
         WHERE c.status = 'ATIVO'
           AND NVL(TRUNC(CAST(c.last_activity_at AS DATE)), c.start_date) <= TRUNC(SYSDATE) - cp_limite
           AND NOT EXISTS (SELECT 1
                             FROM l30_alerts a
                            WHERE a.challenge_id = c.id
                              AND a.alert_type   = 'INATIVIDADE'
                              AND a.resolved     = 0);
BEGIN
    p_alertas_gerados := 0;

    IF p_dias_limite IS NULL OR p_dias_limite < 1 THEN
        RAISE_APPLICATION_ERROR(-20020, c_rotina || ': p_dias_limite deve ser maior ou igual a 1');
    END IF;

    FOR r IN c_desafios_parados(p_dias_limite) LOOP
        IF r.dias_parado >= 14 THEN
            v_severidade := 'ALTA';
        ELSIF r.dias_parado >= 7 THEN
            v_severidade := 'MEDIA';
        ELSE
            v_severidade := 'BAIXA';
        END IF;

        INSERT INTO l30_alerts (user_id, challenge_id, alert_type, severity, message, measured_value)
        VALUES (r.user_id, r.id, 'INATIVIDADE', v_severidade,
                'Desafio "' || r.title || '" sem conclusão há ' || r.dias_parado || ' dias'
                || CASE WHEN v_severidade = 'ALTA' THEN ' — sugerir replanejamento' END,
                r.dias_parado);

        p_alertas_gerados := p_alertas_gerados + 1;
    END LOOP;

    COMMIT;
    pr_log_execucao(c_rotina, 'SUCESSO', 'limite=' || p_dias_limite || ' dias', p_alertas_gerados);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        pr_log_execucao(c_rotina, 'ERRO', SQLERRM);
        RAISE;
END pr_verificar_inatividade;
/


-- ---------------------------------------------------------------------
-- pr_gerar_relatorio_engajamento  (PROCEDURE — relatório resumido)
--
-- Para cada aluno (cursor explícito OPEN/FETCH/CLOSE), calcula no
-- período: desafios ativos, conclusões, taxa de adesão, streak atual e
-- faixa de engajamento. Grava em l30_engagement_reports com um
-- execution_id, que é devolvido para o backend consultar o resultado.
--
-- Faixas: ALTO >= 80% · MODERADO >= 50% · EM_RISCO >= 25% ·
--         CRITICO < 25% · SEM_DESAFIO (nenhum desafio no período)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE pr_gerar_relatorio_engajamento (
    p_inicio        IN  DATE,
    p_fim           IN  DATE,
    p_execucao_id   OUT NUMBER
) IS
    c_rotina     CONSTANT VARCHAR2(40) := 'PR_GERAR_RELATORIO_ENGAJAMENTO';
    v_inicio     DATE := TRUNC(p_inicio);
    v_fim        DATE := TRUNC(p_fim);
    v_ativos     NUMBER;
    v_streak     NUMBER;
    v_conclusoes NUMBER;
    v_taxa       NUMBER;
    v_faixa      l30_engagement_reports.engagement_band%TYPE;
    v_total      PLS_INTEGER := 0;

    CURSOR c_alunos IS
        SELECT id, name
          FROM l30_users
         WHERE role = 'USER'
         ORDER BY name;

    v_aluno c_alunos%ROWTYPE;
BEGIN
    IF v_inicio IS NULL OR v_fim IS NULL THEN
        RAISE_APPLICATION_ERROR(-20030, c_rotina || ': início e fim são obrigatórios');
    END IF;

    IF v_inicio > v_fim OR v_fim - v_inicio > 366 THEN
        RAISE_APPLICATION_ERROR(-20031, c_rotina || ': período inválido (máximo de 366 dias)');
    END IF;

    p_execucao_id := seq_l30_report_execution.NEXTVAL;

    OPEN c_alunos;
    LOOP
        FETCH c_alunos INTO v_aluno;
        EXIT WHEN c_alunos%NOTFOUND;

        SELECT COUNT(CASE WHEN status = 'ATIVO' THEN 1 END),
               NVL(MAX(CASE WHEN status = 'ATIVO' THEN streak END), 0)
          INTO v_ativos, v_streak
          FROM l30_challenges
         WHERE user_id    = v_aluno.id
           AND start_date <= v_fim;

        SELECT COUNT(*)
          INTO v_conclusoes
          FROM l30_completions
         WHERE user_id = v_aluno.id
           AND completed_on BETWEEN v_inicio AND v_fim;

        v_taxa := fn_taxa_adesao(v_aluno.id, v_inicio, v_fim);

        IF v_taxa IS NULL THEN
            v_faixa := 'SEM_DESAFIO';
        ELSIF v_taxa >= 80 THEN
            v_faixa := 'ALTO';
        ELSIF v_taxa >= 50 THEN
            v_faixa := 'MODERADO';
        ELSIF v_taxa >= 25 THEN
            v_faixa := 'EM_RISCO';
        ELSE
            v_faixa := 'CRITICO';
        END IF;

        INSERT INTO l30_engagement_reports (
            execution_id, user_id, period_start, period_end,
            active_challenges, completions, adherence_rate, current_streak, engagement_band)
        VALUES (
            p_execucao_id, v_aluno.id, v_inicio, v_fim,
            v_ativos, v_conclusoes, v_taxa, v_streak, v_faixa);

        v_total := v_total + 1;
    END LOOP;
    CLOSE c_alunos;

    COMMIT;
    pr_log_execucao(c_rotina, 'SUCESSO',
                    'execucao=' || p_execucao_id || ' periodo='
                    || TO_CHAR(v_inicio, 'DD/MM/YYYY') || '-' || TO_CHAR(v_fim, 'DD/MM/YYYY'),
                    v_total);
EXCEPTION
    WHEN OTHERS THEN
        IF c_alunos%ISOPEN THEN
            CLOSE c_alunos;
        END IF;
        ROLLBACK;
        pr_log_execucao(c_rotina, 'ERRO', SQLERRM);
        RAISE;
END pr_gerar_relatorio_engajamento;
/


-- Conferência: todos os objetos devem estar VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('FN_TAXA_ADESAO', 'FN_RESUMO_USUARIO', 'PR_LOG_EXECUCAO',
                       'PR_REGISTRAR_CONCLUSAO', 'PR_VERIFICAR_INATIVIDADE',
                       'PR_GERAR_RELATORIO_ENGAJAMENTO')
 ORDER BY object_type, object_name;
