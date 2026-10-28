-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 08_trg_status_alerta.sql — TRG_L30_STATUS_ALERTA (COMPOUND TRIGGER)
--
-- Fonte única da regra "adesão baixa":
--   adesão 30d < pkg_l30_engajamento.c_limite_adesao -> alerta ADESAO_BAIXA aberto
--   adesão 30d >= limite                              -> alerta aberto é RESOLVIDO
--   adesão NULL (sem desafio no período)              -> nada muda
--
-- Por que COMPOUND: o cálculo lê l30_completions, a tabela em mutação.
-- Num trigger de linha isso daria ORA-04091. Aqui a linha só acumula o
-- user_id (AFTER EACH ROW) e o cálculo roda no AFTER STATEMENT, quando a
-- tabela já pode ser lida.
--
-- Eventos: INSERT e UPDATE de user_id/completed_on. DELETE fica de fora
-- de propósito: l30_completions só é apagada por cascata (usuário ou
-- desafio removido), e reavaliar um usuário em remoção reintroduz
-- mutating table / FK. A auditoria (07) registra os deletes.
-- Não há ALTER TABLE: l30_alerts já tem resolved/resolved_at (ver DDL).
-- =====================================================================

CREATE OR REPLACE TRIGGER trg_l30_status_alerta
FOR INSERT OR UPDATE OF user_id, completed_on ON l30_completions
COMPOUND TRIGGER

    TYPE t_usuarios IS TABLE OF l30_completions.user_id%TYPE INDEX BY VARCHAR2(36);
    g_usuarios t_usuarios;   -- chave = user_id => sem duplicatas

    AFTER EACH ROW IS
    BEGIN
        g_usuarios(:NEW.user_id) := :NEW.user_id;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_user  l30_completions.user_id%TYPE;
        v_taxa  NUMBER;
    BEGIN
        v_user := g_usuarios.FIRST;
        WHILE v_user IS NOT NULL LOOP
            v_taxa := pkg_l30_engajamento.fn_taxa_adesao(v_user);

            IF v_taxa IS NOT NULL AND v_taxa < pkg_l30_engajamento.c_limite_adesao THEN
                MERGE INTO l30_alerts a
                USING (SELECT v_user AS user_id,
                              v_taxa AS taxa,
                              CASE WHEN v_taxa < 25 THEN 'ALTA' ELSE 'MEDIA' END AS severidade
                         FROM dual) s
                   ON (a.user_id = s.user_id AND a.alert_type = 'ADESAO_BAIXA' AND a.resolved = 0)
                 WHEN MATCHED THEN
                      UPDATE SET a.measured_value = s.taxa,
                                 a.severity       = s.severidade,
                                 a.message        = 'Adesão de 30 dias em '
                                                    || TO_CHAR(s.taxa, 'FM990D0', 'NLS_NUMERIC_CHARACTERS='',.''')
                                                    || '%, abaixo da meta de '
                                                    || pkg_l30_engajamento.c_limite_adesao || '%'
                 WHEN NOT MATCHED THEN
                      INSERT (user_id, challenge_id, alert_type, severity, message, measured_value)
                      VALUES (s.user_id, NULL, 'ADESAO_BAIXA', s.severidade,
                              'Adesão de 30 dias em '
                              || TO_CHAR(s.taxa, 'FM990D0', 'NLS_NUMERIC_CHARACTERS='',.''')
                              || '%, abaixo da meta de '
                              || pkg_l30_engajamento.c_limite_adesao || '%',
                              s.taxa);
            ELSIF v_taxa IS NOT NULL THEN
                UPDATE l30_alerts
                   SET resolved    = 1,
                       resolved_at = SYSTIMESTAMP
                 WHERE user_id    = v_user
                   AND alert_type = 'ADESAO_BAIXA'
                   AND resolved   = 0;
            END IF;

            v_user := g_usuarios.NEXT(v_user);
        END LOOP;
        g_usuarios.DELETE;
    END AFTER STATEMENT;

END trg_l30_status_alerta;
/

SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'TRG_L30_STATUS_ALERTA';
