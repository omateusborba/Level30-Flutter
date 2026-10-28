-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 10_consolidacao.sql — remove as rotinas standalone da Fase 6 que
-- agora vivem em PKG_L30_ENGAJAMENTO e confere o schema.
--
-- Rode DEPOIS de 06..09. Se o package não estiver VALID, nada é
-- removido (as rotinas antigas continuam servindo).
-- PR_LOG_EXECUCAO e PR_VERIFICAR_INATIVIDADE permanecem standalone.
-- =====================================================================

DECLARE
    v_invalidos NUMBER;

    PROCEDURE executar_se_existir (p_comando IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_comando;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT IN (-942, -4043) THEN
                RAISE;
            END IF;
    END executar_se_existir;
BEGIN
    SELECT COUNT(*) INTO v_invalidos
      FROM user_objects
     WHERE object_name IN ('PKG_L30_ENGAJAMENTO', 'PKG_L30_CONSULTAS',
                           'TRG_L30_AUDIT_CONCLUSAO', 'TRG_L30_STATUS_ALERTA')
       AND status <> 'VALID';

    SELECT v_invalidos + (4 - COUNT(DISTINCT object_name)) INTO v_invalidos
      FROM user_objects
     WHERE object_name IN ('PKG_L30_ENGAJAMENTO', 'PKG_L30_CONSULTAS',
                           'TRG_L30_AUDIT_CONCLUSAO', 'TRG_L30_STATUS_ALERTA');

    IF v_invalidos > 0 THEN
        RAISE_APPLICATION_ERROR(-20098,
            '10_consolidacao: packages/triggers ausentes ou inválidos; standalone preservadas');
    END IF;

    executar_se_existir('DROP FUNCTION fn_taxa_adesao');
    executar_se_existir('DROP FUNCTION fn_resumo_usuario');
    executar_se_existir('DROP PROCEDURE pr_registrar_conclusao');
    executar_se_existir('DROP PROCEDURE pr_gerar_relatorio_engajamento');
END;
/

-- Conferência: nenhum erro de compilação e nenhum objeto inválido
SELECT name, type, line, text FROM user_errors ORDER BY name, sequence;

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'PROCEDURE', 'FUNCTION')
   AND (object_name LIKE '%L30%' OR object_name LIKE 'PR\_%' ESCAPE '\' OR object_name LIKE 'FN\_%' ESCAPE '\')
 ORDER BY object_type, object_name;
