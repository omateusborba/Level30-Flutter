-- =====================================================================
-- Level30 · Smart HAS — Fase 7 (correções)
-- 98_limpa_residuo_testes.sql — remove o resíduo de testes da base de demo:
--   * alunos de teste: nomes ZZ_TESTE_* e os legados "Aluno Teste" / "Aluno Fase7"
--     (com desafios, conclusões e alertas, por cascata);
--   * linhas de auditoria e de log de execução geradas por eles.
--
-- TRAVA: só roda em banco local/de demo. O serviço do banco precisa estar na lista abaixo
-- (FREEPDB1/FREE/XEPDB1 = Oracle em Docker local; *DEMO* = base de demonstração). No Oracle da
-- FIAP (serviço ORCL) o script aborta sem apagar nada.
-- Idempotente. Para a base de demo completa, prefira scripts/demo-seed.sh.
-- =====================================================================
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
    v_servico VARCHAR2(128) := UPPER(SYS_CONTEXT('USERENV', 'SERVICE_NAME'));
    v_removidos NUMBER := 0;
BEGIN
    IF v_servico NOT IN ('FREEPDB1', 'FREE', 'XEPDB1') AND v_servico NOT LIKE '%DEMO%' THEN
        RAISE_APPLICATION_ERROR(-20990,
            '98_limpa_residuo_testes: serviço ' || v_servico || ' não é local nem de demo; nada foi apagado');
    END IF;

    FOR u IN (SELECT id FROM l30_users
               WHERE name LIKE 'ZZ\_TESTE\_%' ESCAPE '\' OR name IN ('Aluno Teste', 'Aluno Fase7')) LOOP
        DELETE FROM l30_execution_log
         WHERE detail LIKE '%' || NVL((SELECT MIN(id) FROM l30_challenges WHERE user_id = u.id), '#nenhum#') || '%';
        DELETE FROM l30_users WHERE id = u.id;           -- cascata: desafios, conclusões, alertas
        DELETE FROM l30_audit_log
         WHERE JSON_VALUE(dados_novos, '$.user_id') = u.id OR JSON_VALUE(dados_antigos, '$.user_id') = u.id;
        v_removidos := v_removidos + 1;
    END LOOP;

    DELETE FROM l30_execution_log WHERE status = 'ERRO' AND detail LIKE '%dia 99 fora do intervalo%';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Alunos de teste removidos: ' || v_removidos);
END;
/
EXIT
