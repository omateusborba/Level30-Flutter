-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 02_carga_simulada.sql — Importação de dados simulados
--
-- Gera 1 coordenador + 12 alunos, 1 a 3 desafios por aluno e o
-- histórico diário de conclusões dos últimos ~75 dias.
--
-- Cada aluno tem um PERFIL de comportamento, para que indicadores,
-- alertas e relatórios tenham casos interessantes:
--   DISCIPLINADO  conclui ~92% dos dias
--   REGULAR       conclui ~70% dos dias
--   OSCILANTE     alterna 5 dias bons (80%) e 5 dias ruins (25%)
--   ABANDONO      começa bem (75%) e praticamente para após o dia 8
--
-- DBMS_RANDOM.SEED fixa a sequência aleatória: a mesma carga sempre
-- gera a mesma distribuição (datas são relativas ao dia da execução).
-- =====================================================================

SET SERVEROUTPUT ON

DECLARE
    TYPE t_textos IS TABLE OF VARCHAR2(150);

    v_nomes   t_textos := t_textos(
        'Ana Souza', 'Bruno Lima', 'Carla Mendes', 'Diego Rocha',
        'Elisa Castro', 'Felipe Nunes', 'Gabriela Alves', 'Henrique Dias',
        'Isabela Prado', 'João Pedro Melo', 'Larissa Freitas', 'Marcos Vieira');

    v_perfis  t_textos := t_textos(
        'DISCIPLINADO', 'DISCIPLINADO', 'DISCIPLINADO', 'REGULAR',
        'REGULAR', 'REGULAR', 'REGULAR', 'OSCILANTE',
        'OSCILANTE', 'OSCILANTE', 'ABANDONO', 'ABANDONO');

    v_titulos t_textos := t_textos(
        'Ler 20 páginas por dia', 'Estudar Java por 1 hora', 'Caminhar 30 minutos',
        'Revisar flashcards', 'Praticar inglês 15 minutos', 'Meditar 10 minutos',
        'Resolver 2 exercícios de SQL', 'Beber 2 litros de água');

    v_user_id       VARCHAR2(36);
    v_challenge_id  VARCHAR2(36);
    v_nome          VARCHAR2(150);
    v_titulo        VARCHAR2(150);
    v_qtd_desafios  PLS_INTEGER;
    v_inicio        DATE;
    v_dia           DATE;
    v_concluidos    PLS_INTEGER;
    v_streak        PLS_INTEGER;
    v_ultimo        DATE;
    v_ultimo_ts     TIMESTAMP WITH TIME ZONE;
    v_xp            PLS_INTEGER;
    v_xp_usuario    PLS_INTEGER;
    v_status        VARCHAR2(12);
    v_encerramento  DATE;
    v_tot_usuarios  PLS_INTEGER := 0;
    v_tot_desafios  PLS_INTEGER := 0;
    v_tot_conclusoes PLS_INTEGER := 0;

    -- UUID no formato do PostgreSQL (8-4-4-4-12)
    FUNCTION novo_uuid RETURN VARCHAR2 IS
        v_hex VARCHAR2(32) := LOWER(RAWTOHEX(SYS_GUID()));
    BEGIN
        RETURN SUBSTR(v_hex, 1, 8)  || '-' || SUBSTR(v_hex, 9, 4)  || '-' ||
               SUBSTR(v_hex, 13, 4) || '-' || SUBSTR(v_hex, 17, 4) || '-' ||
               SUBSTR(v_hex, 21, 12);
    END novo_uuid;

    -- Probabilidade de o aluno concluir o desafio no dia N
    FUNCTION probabilidade (p_perfil IN VARCHAR2, p_dia_idx IN PLS_INTEGER) RETURN NUMBER IS
    BEGIN
        CASE p_perfil
            WHEN 'DISCIPLINADO' THEN RETURN 0.92;
            WHEN 'REGULAR'      THEN RETURN 0.70;
            WHEN 'OSCILANTE'    THEN RETURN CASE WHEN MOD(p_dia_idx, 10) < 5 THEN 0.80 ELSE 0.25 END;
            ELSE                     RETURN CASE WHEN p_dia_idx < 8 THEN 0.75 ELSE 0.03 END;
        END CASE;
    END probabilidade;
BEGIN
    DBMS_RANDOM.SEED(30);

    -- Coordenador do programa
    v_user_id := novo_uuid;
    INSERT INTO l30_users (id, name, email, role, total_xp)
    VALUES (v_user_id, 'Coordenação Level30', 'coordenacao@level30.online', 'ADMIN', 0);
    v_tot_usuarios := v_tot_usuarios + 1;

    -- Alunos
    FOR i IN 1 .. v_nomes.COUNT LOOP
        v_user_id    := novo_uuid;
        v_xp_usuario := 0;
        v_nome       := v_nomes(i);   -- coleção PL/SQL não pode ser indexada dentro de SQL

        INSERT INTO l30_users (id, name, email, role, total_xp)
        VALUES (v_user_id, v_nome, 'aluno' || LPAD(i, 2, '0') || '@level30.online', 'USER', 0);
        v_tot_usuarios := v_tot_usuarios + 1;

        v_qtd_desafios := TRUNC(DBMS_RANDOM.VALUE(1, 4));   -- 1 a 3

        FOR j IN 1 .. v_qtd_desafios LOOP
            v_challenge_id := novo_uuid;
            v_inicio       := TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(10, 76));
            v_titulo       := v_titulos(TRUNC(DBMS_RANDOM.VALUE(1, v_titulos.COUNT + 1)));

            INSERT INTO l30_challenges (id, user_id, title, start_date)
            VALUES (v_challenge_id, v_user_id, v_titulo, v_inicio);
            v_tot_desafios := v_tot_desafios + 1;

            -- Simula cada dia do calendário até hoje ou até o dia 30 do desafio
            v_dia        := v_inicio;
            v_concluidos := 0;
            v_streak     := 0;
            v_ultimo     := NULL;

            WHILE v_dia <= TRUNC(SYSDATE) AND v_concluidos < 30 LOOP
                IF DBMS_RANDOM.VALUE < probabilidade(v_perfis(i), v_dia - v_inicio) THEN
                    v_concluidos := v_concluidos + 1;

                    IF v_ultimo = v_dia - 1 THEN
                        v_streak := v_streak + 1;
                    ELSE
                        v_streak := 1;
                    END IF;

                    v_xp := 10 + LEAST(v_streak, 5) * 2;   -- bônus por sequência, até +10

                    INSERT INTO l30_completions (challenge_id, user_id, day_number, completed_on, xp_delta)
                    VALUES (v_challenge_id, v_user_id, v_concluidos, v_dia, v_xp);

                    v_ultimo         := v_dia;
                    v_xp_usuario     := v_xp_usuario + v_xp;
                    v_tot_conclusoes := v_tot_conclusoes + 1;
                END IF;

                v_dia := v_dia + 1;
            END LOOP;

            -- Estado final do desafio
            IF v_concluidos = 30 THEN
                v_status       := 'CONCLUIDO';
                v_encerramento := v_ultimo;
            ELSIF v_perfis(i) = 'ABANDONO' AND NVL(v_ultimo, v_inicio) < TRUNC(SYSDATE) - 10 THEN
                v_status       := 'ABANDONADO';
                v_encerramento := NVL(v_ultimo, v_inicio) + 7;
            ELSE
                v_status       := 'ATIVO';
                v_encerramento := NULL;
            END IF;

            -- Streak só continua valendo se a última conclusão foi hoje ou ontem
            IF v_status <> 'CONCLUIDO' AND (v_ultimo IS NULL OR v_ultimo < TRUNC(SYSDATE) - 1) THEN
                v_streak := 0;
            END IF;

            IF v_ultimo IS NULL THEN
                v_ultimo_ts := NULL;
            ELSE
                v_ultimo_ts := FROM_TZ(CAST(v_ultimo AS TIMESTAMP)
                                       + NUMTODSINTERVAL(TRUNC(DBMS_RANDOM.VALUE(7, 22)), 'HOUR'),
                                       'America/Sao_Paulo');
            END IF;

            UPDATE l30_challenges
               SET current_day      = v_concluidos,
                   streak           = v_streak,
                   status           = v_status,
                   ended_on         = v_encerramento,
                   last_activity_at = v_ultimo_ts
             WHERE id = v_challenge_id;
        END LOOP;

        UPDATE l30_users SET total_xp = v_xp_usuario WHERE id = v_user_id;
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Carga concluída: ' || v_tot_usuarios || ' usuários, '
                         || v_tot_desafios || ' desafios, '
                         || v_tot_conclusoes || ' conclusões.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Erro na carga: ' || SQLERRM);
        RAISE;
END;
/

-- Conferência rápida
SELECT u.name,
       COUNT(DISTINCT c.id)  AS desafios,
       COUNT(cc.id)          AS conclusoes,
       u.total_xp
  FROM l30_users u
  LEFT JOIN l30_challenges  c  ON c.user_id = u.id
  LEFT JOIN l30_completions cc ON cc.challenge_id = c.id
 GROUP BY u.name, u.total_xp
 ORDER BY conclusoes DESC;
