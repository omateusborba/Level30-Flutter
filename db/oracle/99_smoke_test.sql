-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 99_smoke_test.sql — compila tudo, confere USER_ERRORS e exercita
-- auditoria, alerta e Dynamic SQL. Sai com código != 0 se algo falhar.
--
-- Uso (SQL*Plus/SQLcl, a partir de db/oracle/):
--   sqlplus usuario/senha@//host/FREEPDB1 @99_smoke_test.sql
-- Pré-requisito: 01_ddl e 03_plsql já aplicados. Os dados de teste usam
-- ids "smoke-*" / nome ZZ_TESTE_Smoke e são removidos no fim (inclusive auditoria e log).
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT == 1. Compilando objetos da Fase 7
@@06_pkg_engajamento.sql
@@07_trg_audit_conclusao.sql
@@08_trg_status_alerta.sql
@@09_pkg_consultas.sql
@@10_consolidacao.sql

PROMPT == 2. USER_ERRORS deve estar vazio
DECLARE
    v_erros NUMBER;
    v_inv   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_erros FROM user_errors;
    SELECT COUNT(*) INTO v_inv
      FROM user_objects
     WHERE status <> 'VALID'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'PROCEDURE', 'FUNCTION');
    IF v_erros > 0 OR v_inv > 0 THEN
        RAISE_APPLICATION_ERROR(-20900, 'USER_ERRORS=' || v_erros || ' inválidos=' || v_inv);
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK  sem erros de compilação, nenhum objeto inválido');
END;
/

PROMPT == 3. Auditoria + alerta aberto/fechado (conclusão de teste)
DECLARE
    v_user      l30_users.id%TYPE      := 'smoke-' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 20);
    v_desafio   l30_challenges.id%TYPE := 'smoke-' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 20);
    v_inicio    DATE := TRUNC(SYSDATE) - 10;
    v_alertas   NUMBER;
    v_n         NUMBER;
    v_taxa      NUMBER;

    PROCEDURE concluir (p_dia IN NUMBER) IS
        v_a NUMBER;
    BEGIN
        pkg_l30_engajamento.pr_registrar_conclusao(
            p_user_id => v_user, p_user_name => 'ZZ_TESTE_Smoke', p_total_xp => 100,
            p_challenge_id => v_desafio, p_title => 'Desafio smoke',
            p_start_date => v_inicio, p_day_number => p_dia, p_streak => p_dia,
            p_completed_on => v_inicio + (p_dia - 1), p_xp_delta => 10,
            p_alertas_gerados => v_a);
    END concluir;

    PROCEDURE exigir (p_ok IN BOOLEAN, p_msg IN VARCHAR2) IS
    BEGIN
        IF NOT p_ok THEN
            RAISE_APPLICATION_ERROR(-20901, 'FALHOU: ' || p_msg);
        END IF;
        DBMS_OUTPUT.PUT_LINE('OK  ' || p_msg);
    END exigir;
BEGIN
    -- 1 conclusão em 11 dias de desafio => adesão ~9% (< 50): alerta abre
    concluir(1);

    SELECT COUNT(*) INTO v_n FROM l30_audit_log
     WHERE tabela = 'L30_COMPLETIONS' AND operacao = 'I'
       AND JSON_VALUE(dados_novos, '$.user_id') = v_user;
    exigir(v_n = 1, 'auditoria registrou o INSERT com JSON e usuário de banco');

    SELECT COUNT(*) INTO v_n FROM l30_audit_log
     WHERE JSON_VALUE(dados_novos, '$.user_id') = v_user AND usuario_banco = SYS_CONTEXT('USERENV','SESSION_USER');
    exigir(v_n = 1, 'USUARIO_BANCO = sessão atual');

    SELECT COUNT(*) INTO v_n FROM l30_alerts
     WHERE user_id = v_user AND alert_type = 'ADESAO_BAIXA' AND resolved = 0;
    exigir(v_n = 1, 'alerta ADESAO_BAIXA aberto (adesão abaixo de ' || pkg_l30_engajamento.c_limite_adesao || '%)');

    -- nova conclusão com alerta já aberto: continua um só (MERGE, sem duplicar)
    concluir(2);
    SELECT COUNT(*) INTO v_n FROM l30_alerts
     WHERE user_id = v_user AND alert_type = 'ADESAO_BAIXA' AND resolved = 0;
    exigir(v_n = 1, 'alerta continua único enquanto aberto');

    -- completa os dias restantes => adesão 100%: alerta fecha
    FOR d IN 3 .. 11 LOOP
        concluir(d);
    END LOOP;
    v_taxa := pkg_l30_engajamento.fn_taxa_adesao(v_user);
    exigir(v_taxa = 100, 'adesão final = 100 (obtido ' || v_taxa || ')');

    SELECT COUNT(*) INTO v_n FROM l30_alerts
     WHERE user_id = v_user AND alert_type = 'ADESAO_BAIXA' AND resolved = 0;
    exigir(v_n = 0, 'alerta aberto foi fechado');
    SELECT COUNT(*) INTO v_n FROM l30_alerts
     WHERE user_id = v_user AND alert_type = 'ADESAO_BAIXA' AND resolved = 1 AND resolved_at IS NOT NULL;
    exigir(v_n = 1, 'alerta RESOLVIDO com resolved_at preenchido');

    -- reentrega do mesmo evento não duplica nem audita de novo
    SELECT COUNT(*) INTO v_n FROM l30_audit_log WHERE JSON_VALUE(dados_novos, '$.user_id') = v_user;
    concluir(11);
    DECLARE v_n2 NUMBER; BEGIN
        SELECT COUNT(*) INTO v_n2 FROM l30_audit_log WHERE JSON_VALUE(dados_novos, '$.user_id') = v_user;
        exigir(v_n2 = v_n, 'reentrega idempotente não gera nova auditoria');
    END;

    -- DELETE (cascata do usuário) é auditado
    DELETE FROM l30_users WHERE id = v_user;
    SELECT COUNT(*) INTO v_n FROM l30_audit_log
     WHERE operacao = 'D' AND JSON_VALUE(dados_antigos, '$.user_id') = v_user;
    exigir(v_n = 11, 'DELETE em cascata auditado (11 linhas)');

    DELETE FROM l30_audit_log
     WHERE JSON_VALUE(dados_novos, '$.user_id') = v_user OR JSON_VALUE(dados_antigos, '$.user_id') = v_user;
    -- pr_log_execucao grava em transação autônoma: o log do teste precisa ser removido à parte
    DELETE FROM l30_execution_log WHERE detail LIKE '%' || v_desafio || '%';
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

PROMPT == 4. Dynamic SQL: combinações de filtros e tentativa de injeção
DECLARE
    v_cur   SYS_REFCURSOR;
    v_uid   VARCHAR2(36); v_nome VARCHAR2(120); v_xp NUMBER; v_nivel NUMBER;
    v_streak NUMBER; v_concl NUMBER; v_adesao NUMBER; v_faixa VARCHAR2(12);
    v_linhas NUMBER;
    v_tabelas_antes NUMBER; v_tabelas_depois NUMBER;

    PROCEDURE rodar (p_desc IN VARCHAR2, p_inicio DATE, p_fim DATE, p_nivel NUMBER,
                     p_adesao NUMBER, p_ordem VARCHAR2, p_dir VARCHAR2) IS
    BEGIN
        v_cur := pkg_l30_consultas.fn_engajamento_filtrado(p_inicio, p_fim, p_nivel, p_adesao, p_ordem, p_dir);
        v_linhas := 0;
        LOOP
            FETCH v_cur INTO v_uid, v_nome, v_xp, v_nivel, v_streak, v_concl, v_adesao, v_faixa;
            EXIT WHEN v_cur%NOTFOUND;
            v_linhas := v_linhas + 1;
            IF p_adesao IS NOT NULL AND v_adesao < p_adesao THEN
                RAISE_APPLICATION_ERROR(-20902, 'filtro de adesão violado em: ' || p_desc);
            END IF;
            IF p_nivel IS NOT NULL AND v_nivel < p_nivel THEN
                RAISE_APPLICATION_ERROR(-20902, 'filtro de nível violado em: ' || p_desc);
            END IF;
        END LOOP;
        CLOSE v_cur;
        DBMS_OUTPUT.PUT_LINE('OK  ' || RPAD(p_desc, 44) || v_linhas || ' linha(s)');
    END rodar;
BEGIN
    SELECT COUNT(*) INTO v_tabelas_antes FROM user_tables WHERE table_name LIKE 'L30\_%' ESCAPE '\';

    rodar('sem filtros (padrão)',              NULL, NULL, NULL, NULL, 'ADESAO', 'DESC');
    rodar('nível >= 2',                        NULL, NULL, 2,    NULL, 'NIVEL',  'DESC');
    rodar('adesão >= 50, ordem por nome ASC',  NULL, NULL, NULL, 50,   'NOME',   'ASC');
    rodar('período 7d + nível + adesão',       TRUNC(SYSDATE) - 6, TRUNC(SYSDATE), 1, 10, 'STREAK', 'DESC');
    rodar('ordenação em minúsculas',           NULL, NULL, NULL, NULL, 'streak', 'asc');

    -- injeção em p_ordenar_por: deve cair na whitelist (ORA-20050)
    BEGIN
        v_cur := pkg_l30_consultas.fn_engajamento_filtrado(p_ordenar_por => 'X; DROP TABLE l30_users');
        RAISE_APPLICATION_ERROR(-20903, 'injeção em p_ordenar_por NÃO foi barrada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20050 THEN RAISE; END IF;
            DBMS_OUTPUT.PUT_LINE('OK  p_ordenar_por malicioso => ORA-20050');
    END;

    -- injeção em p_direcao
    BEGIN
        v_cur := pkg_l30_consultas.fn_engajamento_filtrado(p_direcao => 'DESC, (SELECT 1 FROM dual)');
        RAISE_APPLICATION_ERROR(-20903, 'injeção em p_direcao NÃO foi barrada');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20050 THEN RAISE; END IF;
            DBMS_OUTPUT.PUT_LINE('OK  p_direcao maliciosa => ORA-20050');
    END;

    SELECT COUNT(*) INTO v_tabelas_depois FROM user_tables WHERE table_name LIKE 'L30\_%' ESCAPE '\';
    IF v_tabelas_antes <> v_tabelas_depois THEN
        RAISE_APPLICATION_ERROR(-20904, 'número de tabelas L30_ mudou durante o teste de injeção');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK  tabelas L30_ intactas (' || v_tabelas_depois || ')');
END;
/

PROMPT == SMOKE TEST CONCLUÍDO COM SUCESSO
EXIT
