-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 07_trg_audit_conclusao.sql — L30_AUDIT_LOG + TRG_L30_AUDIT_CONCLUSAO
--
-- Toda mudança em l30_completions (I/U/D) grava uma linha de auditoria
-- com o registro antes/depois em JSON e o usuário de banco da sessão.
-- A trigger só LÊ :OLD/:NEW e escreve em outra tabela (sem FK, para a
-- auditoria sobreviver a deletes em cascata).
-- =====================================================================

DECLARE
    v_existe NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_existe FROM user_tables WHERE table_name = 'L30_AUDIT_LOG';
    IF v_existe = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE l30_audit_log (
                id             NUMBER GENERATED ALWAYS AS IDENTITY
                               CONSTRAINT pk_l30_audit_log PRIMARY KEY,
                tabela         VARCHAR2(40)  NOT NULL,
                operacao       VARCHAR2(1)   NOT NULL
                               CONSTRAINT ck_l30_audit_operacao CHECK (operacao IN (''I'', ''U'', ''D'')),
                registro_id    VARCHAR2(64),
                dados_antigos  CLOB CONSTRAINT ck_l30_audit_antigos_json CHECK (dados_antigos IS JSON),
                dados_novos    CLOB CONSTRAINT ck_l30_audit_novos_json CHECK (dados_novos IS JSON),
                usuario_banco  VARCHAR2(128) DEFAULT SYS_CONTEXT(''USERENV'', ''SESSION_USER'') NOT NULL,
                criado_em      TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
            )';
        EXECUTE IMMEDIATE 'CREATE INDEX ix_l30_audit_tabela_data ON l30_audit_log (tabela, criado_em)';
        EXECUTE IMMEDIATE 'COMMENT ON TABLE l30_audit_log IS ''Auditoria de DML nas tabelas do Level30 (I/U/D, valores em JSON)''';
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_l30_audit_conclusao
AFTER INSERT OR UPDATE OR DELETE ON l30_completions
FOR EACH ROW
DECLARE
    v_operacao  VARCHAR2(1);
    v_antigos   CLOB;
    v_novos     CLOB;
    v_registro  VARCHAR2(64);
BEGIN
    IF INSERTING THEN
        v_operacao := 'I';
    ELSIF UPDATING THEN
        v_operacao := 'U';
    ELSE
        v_operacao := 'D';
    END IF;

    IF NOT INSERTING THEN
        SELECT JSON_OBJECT('id'           VALUE :OLD.id,
                           'challenge_id' VALUE :OLD.challenge_id,
                           'user_id'      VALUE :OLD.user_id,
                           'day_number'   VALUE :OLD.day_number,
                           'completed_on' VALUE TO_CHAR(:OLD.completed_on, 'YYYY-MM-DD'),
                           'xp_delta'     VALUE :OLD.xp_delta
                           RETURNING CLOB)
          INTO v_antigos
          FROM dual;
    END IF;

    IF NOT DELETING THEN
        SELECT JSON_OBJECT('id'           VALUE :NEW.id,
                           'challenge_id' VALUE :NEW.challenge_id,
                           'user_id'      VALUE :NEW.user_id,
                           'day_number'   VALUE :NEW.day_number,
                           'completed_on' VALUE TO_CHAR(:NEW.completed_on, 'YYYY-MM-DD'),
                           'xp_delta'     VALUE :NEW.xp_delta
                           RETURNING CLOB)
          INTO v_novos
          FROM dual;
    END IF;

    v_registro := TO_CHAR(CASE WHEN DELETING THEN :OLD.id ELSE :NEW.id END);

    INSERT INTO l30_audit_log (tabela, operacao, registro_id, dados_antigos, dados_novos, usuario_banco)
    VALUES ('L30_COMPLETIONS', v_operacao, v_registro, v_antigos, v_novos,
            SYS_CONTEXT('USERENV', 'SESSION_USER'));
END trg_l30_audit_conclusao;
/

SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'TRG_L30_AUDIT_CONCLUSAO';
