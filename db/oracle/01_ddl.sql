-- =====================================================================
-- Level30 · Smart HAS — Fase 6
-- 01_ddl.sql — Modelo físico Oracle
--
-- Compatível com Oracle 19c+ (IDENTITY exige 12c+).
-- Tabelas com prefixo L30_ para não colidir com outros projetos no
-- mesmo schema.
--
-- Papel do Oracle na arquitetura:
--   PostgreSQL continua sendo o banco transacional do Spring Boot.
--   O Oracle é a camada de inteligência: recebe réplica de usuários e
--   desafios + eventos de conclusão (via pr_registrar_conclusao) e
--   concentra indicadores, alertas e relatórios em PL/SQL.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Usuários (réplica do PostgreSQL)
-- ---------------------------------------------------------------------
CREATE TABLE l30_users (
    id          VARCHAR2(36)  CONSTRAINT pk_l30_users PRIMARY KEY,
    name        VARCHAR2(120) NOT NULL,
    email       VARCHAR2(160),
    role        VARCHAR2(10)  DEFAULT 'USER' NOT NULL
                CONSTRAINT ck_l30_users_role CHECK (role IN ('USER', 'ADMIN')),
    total_xp    NUMBER(10)    DEFAULT 0 NOT NULL
                CONSTRAINT ck_l30_users_xp CHECK (total_xp >= 0),
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    synced_at   TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX ux_l30_users_email ON l30_users (LOWER(email));

COMMENT ON TABLE  l30_users           IS 'Réplica dos usuários do Level30 (origem: PostgreSQL)';
COMMENT ON COLUMN l30_users.id        IS 'UUID do usuário, idêntico ao PostgreSQL';
COMMENT ON COLUMN l30_users.total_xp  IS 'XP acumulado (snapshot enviado pelo backend)';
COMMENT ON COLUMN l30_users.synced_at IS 'Última sincronização recebida do backend';

-- ---------------------------------------------------------------------
-- Desafios de 30 dias (réplica do PostgreSQL)
-- ---------------------------------------------------------------------
CREATE TABLE l30_challenges (
    id                VARCHAR2(36)  CONSTRAINT pk_l30_challenges PRIMARY KEY,
    user_id           VARCHAR2(36)  NOT NULL
                      CONSTRAINT fk_l30_challenges_user
                      REFERENCES l30_users (id) ON DELETE CASCADE,
    title             VARCHAR2(150) NOT NULL,
    start_date        DATE          NOT NULL,
    current_day       NUMBER(2)     DEFAULT 0 NOT NULL
                      CONSTRAINT ck_l30_challenges_day CHECK (current_day BETWEEN 0 AND 30),
    streak            NUMBER(3)     DEFAULT 0 NOT NULL
                      CONSTRAINT ck_l30_challenges_streak CHECK (streak >= 0),
    status            VARCHAR2(12)  DEFAULT 'ATIVO' NOT NULL
                      CONSTRAINT ck_l30_challenges_status
                      CHECK (status IN ('ATIVO', 'CONCLUIDO', 'ABANDONADO')),
    ended_on          DATE,
    last_activity_at  TIMESTAMP WITH TIME ZONE,
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT ck_l30_challenges_ended CHECK (ended_on IS NULL OR ended_on >= start_date)
);

CREATE INDEX ix_l30_challenges_user   ON l30_challenges (user_id);
CREATE INDEX ix_l30_challenges_status ON l30_challenges (status);

COMMENT ON TABLE  l30_challenges             IS 'Desafios de 30 dias dos usuários';
COMMENT ON COLUMN l30_challenges.current_day IS 'Quantidade de dias concluídos (0 a 30)';
COMMENT ON COLUMN l30_challenges.ended_on    IS 'Data de encerramento (conclusão do dia 30 ou abandono)';

-- ---------------------------------------------------------------------
-- Histórico de conclusões (evento imutável — um registro por dia)
-- ---------------------------------------------------------------------
CREATE TABLE l30_completions (
    id            NUMBER GENERATED ALWAYS AS IDENTITY
                  CONSTRAINT pk_l30_completions PRIMARY KEY,
    challenge_id  VARCHAR2(36) NOT NULL
                  CONSTRAINT fk_l30_completions_challenge
                  REFERENCES l30_challenges (id) ON DELETE CASCADE,
    user_id       VARCHAR2(36) NOT NULL
                  CONSTRAINT fk_l30_completions_user
                  REFERENCES l30_users (id) ON DELETE CASCADE,
    day_number    NUMBER(2)    NOT NULL
                  CONSTRAINT ck_l30_completions_day CHECK (day_number BETWEEN 1 AND 30),
    completed_on  DATE         NOT NULL,
    xp_delta      NUMBER(4)    DEFAULT 0 NOT NULL,
    note          VARCHAR2(500),
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_l30_completion_por_dia UNIQUE (challenge_id, completed_on),
    CONSTRAINT uq_l30_completion_numero  UNIQUE (challenge_id, day_number)
);

CREATE INDEX ix_l30_completions_user_data ON l30_completions (user_id, completed_on);

COMMENT ON TABLE  l30_completions              IS 'Cada conclusão diária de desafio, registrada como evento';
COMMENT ON COLUMN l30_completions.completed_on IS 'Data local (America/Sao_Paulo) calculada pelo backend';

-- ---------------------------------------------------------------------
-- Alertas gerados pelas rotinas PL/SQL
-- ---------------------------------------------------------------------
CREATE TABLE l30_alerts (
    id              NUMBER GENERATED ALWAYS AS IDENTITY
                    CONSTRAINT pk_l30_alerts PRIMARY KEY,
    user_id         VARCHAR2(36) NOT NULL
                    CONSTRAINT fk_l30_alerts_user
                    REFERENCES l30_users (id) ON DELETE CASCADE,
    challenge_id    VARCHAR2(36)
                    CONSTRAINT fk_l30_alerts_challenge
                    REFERENCES l30_challenges (id) ON DELETE CASCADE,
    alert_type      VARCHAR2(20) NOT NULL
                    CONSTRAINT ck_l30_alerts_type
                    CHECK (alert_type IN ('INATIVIDADE', 'ADESAO_BAIXA', 'STREAK_REINICIADO')),
    severity        VARCHAR2(5)  NOT NULL
                    CONSTRAINT ck_l30_alerts_severity CHECK (severity IN ('BAIXA', 'MEDIA', 'ALTA')),
    message         VARCHAR2(400) NOT NULL,
    measured_value  NUMBER(6,2),
    resolved        NUMBER(1) DEFAULT 0 NOT NULL
                    CONSTRAINT ck_l30_alerts_resolved CHECK (resolved IN (0, 1)),
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_l30_alerts_user_open      ON l30_alerts (user_id, resolved);
CREATE INDEX ix_l30_alerts_challenge_type ON l30_alerts (challenge_id, alert_type, resolved);

COMMENT ON TABLE  l30_alerts                IS 'Alertas de engajamento gerados no banco';
COMMENT ON COLUMN l30_alerts.measured_value IS 'Valor que disparou o alerta (dias parado, % de adesão, dia do desafio)';

-- ---------------------------------------------------------------------
-- Relatórios de engajamento (uma linha por usuário por execução)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_l30_report_execution START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE l30_engagement_reports (
    id                 NUMBER GENERATED ALWAYS AS IDENTITY
                       CONSTRAINT pk_l30_engagement_reports PRIMARY KEY,
    execution_id       NUMBER       NOT NULL,
    user_id            VARCHAR2(36) NOT NULL
                       CONSTRAINT fk_l30_reports_user
                       REFERENCES l30_users (id) ON DELETE CASCADE,
    period_start       DATE         NOT NULL,
    period_end         DATE         NOT NULL,
    active_challenges  NUMBER(3)    NOT NULL,
    completions        NUMBER(5)    NOT NULL,
    adherence_rate     NUMBER(5,2),
    current_streak     NUMBER(3)    NOT NULL,
    engagement_band    VARCHAR2(12) NOT NULL
                       CONSTRAINT ck_l30_reports_band
                       CHECK (engagement_band IN ('ALTO', 'MODERADO', 'EM_RISCO', 'CRITICO', 'SEM_DESAFIO')),
    generated_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_l30_reports_exec_user UNIQUE (execution_id, user_id)
);

COMMENT ON TABLE  l30_engagement_reports                IS 'Resultado de cada execução de pr_gerar_relatorio_engajamento';
COMMENT ON COLUMN l30_engagement_reports.adherence_rate IS 'NULL quando o usuário não tinha desafio no período';

-- ---------------------------------------------------------------------
-- Log de execução das rotinas (gravado em transação autônoma)
-- ---------------------------------------------------------------------
CREATE TABLE l30_execution_log (
    id             NUMBER GENERATED ALWAYS AS IDENTITY
                   CONSTRAINT pk_l30_execution_log PRIMARY KEY,
    routine        VARCHAR2(60)  NOT NULL,
    status         VARCHAR2(10)  NOT NULL
                   CONSTRAINT ck_l30_log_status CHECK (status IN ('SUCESSO', 'ERRO')),
    detail         VARCHAR2(1000),
    rows_affected  NUMBER,
    executed_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE l30_execution_log IS 'Auditoria das procedures: sucesso, erro e volume processado';
