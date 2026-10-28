-- =====================================================================
-- Level30 · Smart HAS — Fase 7
-- 09_pkg_consultas.sql — PKG_L30_CONSULTAS (Dynamic SQL seguro)
--
-- FN_ENGAJAMENTO_FILTRADO monta um SELECT com ORDER BY variável.
--   * VALORES (datas, nível mínimo, adesão mínima): sempre BIND.
--   * IDENTIFICADORES (coluna e direção do ORDER BY): não aceitam bind,
--     então passam por WHITELIST (CASE) + DBMS_ASSERT.SIMPLE_SQL_NAME.
--     Qualquer valor fora da lista => ORA-20050.
-- Pré-requisito: 06_pkg_engajamento.sql.
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_l30_consultas AS

    -- TRUE grava o SQL final (sem valores) em DBMS_OUTPUT.
    c_debug CONSTANT BOOLEAN := FALSE;

    -- -20050: parâmetro de ordenação fora da whitelist.
    e_ordenacao_invalida EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_ordenacao_invalida, -20050);

    -- Colunas devolvidas: USER_ID, NOME, TOTAL_XP, NIVEL, STREAK, CONCLUSOES,
    -- ADESAO (NULL sem desafio no período), FAIXA (mesmas faixas do relatório).
    -- p_inicio/p_fim: janela da adesão e das conclusões (padrão: 30 dias).
    -- p_nivel_min: nível mínimo (nível = XP/500 + 1, espelho de Leveling.java).
    -- p_adesao_min: adesão mínima em %.
    -- p_ordenar_por: ADESAO | STREAK | NOME | NIVEL   p_direcao: ASC | DESC
    FUNCTION fn_engajamento_filtrado (
        p_inicio      IN DATE     DEFAULT NULL,
        p_fim         IN DATE     DEFAULT NULL,
        p_nivel_min   IN NUMBER   DEFAULT NULL,
        p_adesao_min  IN NUMBER   DEFAULT NULL,
        p_ordenar_por IN VARCHAR2 DEFAULT 'ADESAO',
        p_direcao     IN VARCHAR2 DEFAULT 'DESC'
    ) RETURN SYS_REFCURSOR;

END pkg_l30_consultas;
/

CREATE OR REPLACE PACKAGE BODY pkg_l30_consultas AS

    FUNCTION fn_engajamento_filtrado (
        p_inicio      IN DATE     DEFAULT NULL,
        p_fim         IN DATE     DEFAULT NULL,
        p_nivel_min   IN NUMBER   DEFAULT NULL,
        p_adesao_min  IN NUMBER   DEFAULT NULL,
        p_ordenar_por IN VARCHAR2 DEFAULT 'ADESAO',
        p_direcao     IN VARCHAR2 DEFAULT 'DESC'
    ) RETURN SYS_REFCURSOR IS
        v_cur     SYS_REFCURSOR;
        v_coluna  VARCHAR2(30);
        v_direcao VARCHAR2(4);
        v_sql     VARCHAR2(4000);
    BEGIN
        -- 1) Whitelist dos identificadores: o CASE devolve o nome REAL da
        --    coluna; a entrada do usuário nunca vai parar no texto do SQL.
        v_coluna := CASE UPPER(TRIM(NVL(p_ordenar_por, 'ADESAO')))
                        WHEN 'ADESAO' THEN 'ADESAO'
                        WHEN 'STREAK' THEN 'STREAK'
                        WHEN 'NOME'   THEN 'NOME'
                        WHEN 'NIVEL'  THEN 'NIVEL'
                    END;
        v_direcao := CASE UPPER(TRIM(NVL(p_direcao, 'DESC')))
                         WHEN 'ASC'  THEN 'ASC'
                         WHEN 'DESC' THEN 'DESC'
                     END;

        IF v_coluna IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050,
                'pkg_l30_consultas: p_ordenar_por inválido (use ADESAO, STREAK, NOME ou NIVEL)');
        END IF;
        IF v_direcao IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050,
                'pkg_l30_consultas: p_direcao inválida (use ASC ou DESC)');
        END IF;

        -- Defesa extra: o identificador resultante precisa ser um nome SQL simples.
        v_coluna := DBMS_ASSERT.SIMPLE_SQL_NAME(v_coluna);

        -- 2) Filtros opcionais com binds FIXOS. Em vez de montar o WHERE só
        --    com os filtros presentes (o que mudaria o número de binds a cada
        --    chamada), o padrão "(:b IS NULL OR coluna >= :b)" mantém sempre 4
        --    binds; filtro nulo vira condição verdadeira. Cada valor entra uma
        --    única vez, numa CTE de parâmetros (SELECT ... FROM dual), então o
        --    USING abaixo é posicional sem repetir variável. Escolha sobre
        --    DBMS_SQL: mais simples, um único cursor reutilizável pelo Oracle.
        v_sql :=
               'WITH p AS (SELECT :b_inicio AS inicio, :b_fim AS fim, '
            || '               :b_nivel_min AS nivel_min, :b_adesao_min AS adesao_min FROM dual), '
            || 'base AS ( '
            || '  SELECT u.id AS user_id, u.name AS nome, u.total_xp, '
            || '         TRUNC(u.total_xp / 500) + 1 AS nivel, '
            || '         NVL((SELECT MAX(c.streak) FROM l30_challenges c '
            || '               WHERE c.user_id = u.id AND c.status = ''ATIVO''), 0) AS streak, '
            || '         (SELECT COUNT(*) FROM l30_completions cc '
            || '           WHERE cc.user_id = u.id '
            || '             AND cc.completed_on BETWEEN NVL(TRUNC(p.inicio), TRUNC(NVL(p.fim, SYSDATE)) - 29) '
            || '                                     AND TRUNC(NVL(p.fim, SYSDATE))) AS conclusoes, '
            || '         pkg_l30_engajamento.fn_taxa_adesao(u.id, p.inicio, p.fim) AS adesao, '
            || '         p.nivel_min, p.adesao_min '
            || '    FROM l30_users u CROSS JOIN p '
            || '   WHERE u.role = ''USER'') '
            || 'SELECT user_id, nome, total_xp, nivel, streak, conclusoes, adesao, '
            || '       CASE WHEN adesao IS NULL THEN ''SEM_DESAFIO'' '
            || '            WHEN adesao >= 80 THEN ''ALTO'' '
            || '            WHEN adesao >= 50 THEN ''MODERADO'' '
            || '            WHEN adesao >= 25 THEN ''EM_RISCO'' '
            || '            ELSE ''CRITICO'' END AS faixa '
            || '  FROM base '
            || ' WHERE (1 = 1) '
            || '   AND (nivel_min  IS NULL OR nivel  >= nivel_min) '
            || '   AND (adesao_min IS NULL OR adesao >= adesao_min) '
            || ' ORDER BY ' || v_coluna || ' ' || v_direcao || ' NULLS LAST, nome ASC, user_id ASC';

        IF c_debug THEN
            DBMS_OUTPUT.PUT_LINE('[pkg_l30_consultas] ' || v_sql);   -- só o texto; binds não são logados
        END IF;

        OPEN v_cur FOR v_sql USING p_inicio, p_fim, p_nivel_min, p_adesao_min;
        RETURN v_cur;
    END fn_engajamento_filtrado;

END pkg_l30_consultas;
/

SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'PKG_L30_CONSULTAS' ORDER BY object_type;
