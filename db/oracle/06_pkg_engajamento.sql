-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 06_pkg_engajamento.sql — PKG_L30_ENGAJAMENTO (spec + body)
--
-- Consolida as rotinas da Fase 6 (03_plsql.sql) em um package:
--   FN_TAXA_ADESAO · FN_RESUMO_USUARIO ·
--   PR_REGISTRAR_CONCLUSAO · PR_GERAR_RELATORIO_ENGAJAMENTO
-- Assinaturas e comportamento preservados, com duas diferenças:
--   * validações repetidas viraram funções privadas (FN_USUARIO_EXISTE);
--   * o alerta ADESAO_BAIXA saiu de PR_REGISTRAR_CONCLUSAO: a regra tem
--     uma única fonte, a trigger TRG_L30_STATUS_ALERTA (08_...).
--
-- PR_LOG_EXECUCAO e PR_VERIFICAR_INATIVIDADE continuam standalone
-- (fora do escopo da consolidação; o job 05 chama a segunda).
-- Pré-requisito: 01_ddl.sql e 03_plsql.sql (pr_log_execucao).
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_l30_engajamento AS

    -- Meta mínima de adesão (%) em 30 dias. Abaixo disso a trigger
    -- TRG_L30_STATUS_ALERTA mantém um alerta ADESAO_BAIXA aberto.
    c_limite_adesao CONSTANT NUMBER := 50;

    -- -----------------------------------------------------------------
    -- Exceptions nomeadas (faixa do projeto: -20001..-20099)
    --   -20001 e_usuario_obrigatorio   p_user_id nulo
    --   -20002 e_periodo_invalido      início posterior ao fim (taxa de adesão)
    --   -20003 e_usuario_inexistente   usuário não está na réplica Oracle
    --   -20010 e_conclusao_invalida    usuário/desafio/data/dia ausentes
    --   -20011 e_dia_invalido          dia fora de 1..30
    --   -20030 e_relatorio_periodo_nulo início/fim do relatório ausentes
    --   -20031 e_relatorio_periodo_invalido  início > fim ou mais de 366 dias
    --   -20099 erro inesperado encapsulado (RAISE_APPLICATION_ERROR direto)
    -- (-20020 pertence a pr_verificar_inatividade; -20050 a pkg_l30_consultas.)
    -- -----------------------------------------------------------------
    e_usuario_obrigatorio        EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_usuario_obrigatorio, -20001);
    e_periodo_invalido           EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_periodo_invalido, -20002);
    e_usuario_inexistente        EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_usuario_inexistente, -20003);
    e_conclusao_invalida         EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_conclusao_invalida, -20010);
    e_dia_invalido               EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_dia_invalido, -20011);
    e_relatorio_periodo_nulo     EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_relatorio_periodo_nulo, -20030);
    e_relatorio_periodo_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_relatorio_periodo_invalido, -20031);

    -- % de dias com conclusão sobre os dias com desafio aberto no período.
    -- Padrão: últimos 30 dias. NULL quando não havia desafio aberto.
    FUNCTION fn_taxa_adesao (
        p_user_id IN l30_users.id%TYPE,
        p_inicio  IN DATE DEFAULT NULL,
        p_fim     IN DATE DEFAULT NULL
    ) RETURN NUMBER;

    -- "Ana Souza | 1.250 XP | 2 desafios ativos | streak de 12 dias | adesão 30d: 83,5%"
    FUNCTION fn_resumo_usuario (
        p_user_id IN l30_users.id%TYPE
    ) RETURN VARCHAR2;

    -- Fonte ÚNICA da regra "adesão baixa": abre/mantém/fecha o alerta ADESAO_BAIXA do usuário
    -- conforme fn_taxa_adesao(30 dias) x c_limite_adesao. Chamada pela trigger
    -- TRG_L30_STATUS_ALERTA (AFTER STATEMENT) e pelo seed da demo. Não faz COMMIT.
    PROCEDURE pr_avaliar_alerta_adesao (
        p_user_id IN l30_users.id%TYPE
    );

    -- Acionada pelo backend Java a cada conclusão. Sincroniza a réplica,
    -- registra o evento (idempotente) e trata inatividade/streak.
    -- NÃO faz COMMIT. O alerta de adesão baixa vem da trigger; p_alertas_gerados
    -- conta só os alertas criados pela própria procedure (STREAK_REINICIADO).
    PROCEDURE pr_registrar_conclusao (
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
    );

    -- Relatório por aluno no período; devolve o execution_id gravado em
    -- l30_engagement_reports. Faz COMMIT.
    PROCEDURE pr_gerar_relatorio_engajamento (
        p_inicio       IN  DATE,
        p_fim          IN  DATE,
        p_execucao_id  OUT NUMBER
    );

END pkg_l30_engajamento;
/

CREATE OR REPLACE PACKAGE BODY pkg_l30_engajamento AS

    -- ---------------------------------------------------------------
    -- Privadas (fora da spec)
    -- ---------------------------------------------------------------

    FUNCTION fn_usuario_existe (p_user_id IN l30_users.id%TYPE) RETURN BOOLEAN IS
        v_qtd NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd FROM l30_users WHERE id = p_user_id;
        RETURN v_qtd > 0;
    END fn_usuario_existe;

    -- ---------------------------------------------------------------
    -- fn_taxa_adesao
    --   dias esperados  = soma, por desafio, dos dias do período entre o
    --                     início do desafio e seu encerramento (ou fim)
    --   dias realizados = conclusões registradas no período
    -- ---------------------------------------------------------------
    FUNCTION fn_taxa_adesao (
        p_user_id  IN l30_users.id%TYPE,
        p_inicio   IN DATE DEFAULT NULL,
        p_fim      IN DATE DEFAULT NULL
    ) RETURN NUMBER IS
        v_fim        DATE := TRUNC(NVL(p_fim, SYSDATE));
        v_inicio     DATE := NVL(TRUNC(p_inicio), v_fim - 29);
        v_esperados  NUMBER;
        v_realizados NUMBER;
    BEGIN
        IF p_user_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'fn_taxa_adesao: p_user_id é obrigatório');
        END IF;

        IF v_inicio > v_fim THEN
            RAISE_APPLICATION_ERROR(-20002, 'fn_taxa_adesao: início posterior ao fim do período');
        END IF;

        IF NOT fn_usuario_existe(p_user_id) THEN
            RAISE_APPLICATION_ERROR(-20003, 'fn_taxa_adesao: usuário ' || p_user_id || ' não encontrado');
        END IF;

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
        WHEN OTHERS THEN
            -- RAISE sem nome só vale lexicamente dentro do handler
            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                RAISE;   -- erro de negócio já tratado acima
            END IF;
            RAISE_APPLICATION_ERROR(-20099, 'fn_taxa_adesao: ' || SQLERRM);
    END fn_taxa_adesao;

    -- ---------------------------------------------------------------
    -- fn_resumo_usuario
    -- ---------------------------------------------------------------
    FUNCTION fn_resumo_usuario (
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
            -- RAISE sem nome só vale lexicamente dentro do handler
            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                RAISE;   -- erro de negócio já tratado acima
            END IF;
            RAISE_APPLICATION_ERROR(-20099, 'fn_resumo_usuario: ' || SQLERRM);
    END fn_resumo_usuario;

    -- ---------------------------------------------------------------
    -- pr_avaliar_alerta_adesao
    --   taxa < c_limite_adesao -> MERGE abre (ou atualiza) o alerta aberto
    --   taxa >= limite          -> fecha o alerta aberto (resolved = 1)
    --   taxa NULL               -> nada muda
    -- ---------------------------------------------------------------
    PROCEDURE pr_avaliar_alerta_adesao (
        p_user_id IN l30_users.id%TYPE
    ) IS
        v_taxa NUMBER := fn_taxa_adesao(p_user_id);
    BEGIN
        IF v_taxa IS NULL THEN
            RETURN;
        END IF;

        IF v_taxa < c_limite_adesao THEN
            MERGE INTO l30_alerts a
            USING (SELECT p_user_id AS user_id,
                          v_taxa AS taxa,
                          CASE WHEN v_taxa < 25 THEN 'ALTA' ELSE 'MEDIA' END AS severidade
                     FROM dual) s
               ON (a.user_id = s.user_id AND a.alert_type = 'ADESAO_BAIXA' AND a.resolved = 0)
             WHEN MATCHED THEN
                  UPDATE SET a.measured_value = s.taxa,
                             a.severity       = s.severidade,
                             a.message        = 'Adesão de 30 dias em '
                                                || TO_CHAR(s.taxa, 'FM990D0', 'NLS_NUMERIC_CHARACTERS='',.''')
                                                || '%, abaixo da meta de ' || c_limite_adesao || '%'
             WHEN NOT MATCHED THEN
                  INSERT (user_id, challenge_id, alert_type, severity, message, measured_value)
                  VALUES (s.user_id, NULL, 'ADESAO_BAIXA', s.severidade,
                          'Adesão de 30 dias em '
                          || TO_CHAR(s.taxa, 'FM990D0', 'NLS_NUMERIC_CHARACTERS='',.''')
                          || '%, abaixo da meta de ' || c_limite_adesao || '%',
                          s.taxa);
        ELSE
            UPDATE l30_alerts
               SET resolved    = 1,
                   resolved_at = SYSTIMESTAMP
             WHERE user_id    = p_user_id
               AND alert_type = 'ADESAO_BAIXA'
               AND resolved   = 0;
        END IF;
    END pr_avaliar_alerta_adesao;

    -- ---------------------------------------------------------------
    -- pr_registrar_conclusao
    -- 1. Sincroniza réplica de usuário e desafio (MERGE)
    -- 2. Registra o evento (idempotente) -> dispara as triggers de
    --    auditoria e de status de alerta
    -- 3. Resolve alertas de inatividade abertos do desafio
    -- 4. Alerta se a sequência foi reiniciada
    -- ---------------------------------------------------------------
    PROCEDURE pr_registrar_conclusao (
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
        c_rotina CONSTANT VARCHAR2(30) := 'PR_REGISTRAR_CONCLUSAO';
        v_data   DATE := TRUNC(p_completed_on);
        v_titulo l30_challenges.title%TYPE := NVL(p_title, 'Desafio');
    BEGIN
        SAVEPOINT sp_registrar_conclusao;
        p_alertas_gerados := 0;

        IF p_user_id IS NULL OR p_challenge_id IS NULL OR v_data IS NULL OR p_day_number IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, c_rotina || ': usuário, desafio, data e dia são obrigatórios');
        END IF;

        IF p_day_number NOT BETWEEN 1 AND 30 THEN
            RAISE_APPLICATION_ERROR(-20011, c_rotina || ': dia ' || p_day_number || ' fora do intervalo 1-30');
        END IF;

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

        BEGIN
            INSERT INTO l30_completions (challenge_id, user_id, day_number, completed_on, xp_delta)
            VALUES (p_challenge_id, p_user_id, p_day_number, v_data, NVL(p_xp_delta, 0));
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                pr_log_execucao(c_rotina, 'SUCESSO',
                                'Evento duplicado ignorado: desafio=' || p_challenge_id || ' dia=' || p_day_number, 0);
                RETURN;   -- reentrega: réplica atualizada, sem regras de novo
        END;

        UPDATE l30_alerts
           SET resolved    = 1,
               resolved_at = SYSTIMESTAMP
         WHERE challenge_id = p_challenge_id
           AND alert_type   = 'INATIVIDADE'
           AND resolved     = 0;

        IF NVL(p_streak, 0) = 1 AND p_day_number > 1 THEN
            INSERT INTO l30_alerts (user_id, challenge_id, alert_type, severity, message, measured_value)
            VALUES (p_user_id, p_challenge_id, 'STREAK_REINICIADO', 'BAIXA',
                    'Sequência reiniciada no dia ' || p_day_number || ' do desafio "' || v_titulo || '"',
                    p_day_number);
            p_alertas_gerados := p_alertas_gerados + 1;
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

    -- ---------------------------------------------------------------
    -- pr_gerar_relatorio_engajamento
    -- Faixas: ALTO >= 80% · MODERADO >= 50% · EM_RISCO >= 25% ·
    --         CRITICO < 25% · SEM_DESAFIO (nenhum desafio no período)
    -- ---------------------------------------------------------------
    PROCEDURE pr_gerar_relatorio_engajamento (
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

END pkg_l30_engajamento;
/

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name = 'PKG_L30_ENGAJAMENTO'
 ORDER BY object_type;
