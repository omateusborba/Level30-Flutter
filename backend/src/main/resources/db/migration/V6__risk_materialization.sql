-- B1 · Risco materializado. O RiskEngine continua sendo a UNICA fonte da formula;
-- estas colunas sao cache, recalculado em completeDay e por job diario (o risco
-- cresce com o tempo mesmo sem acao do usuario). Sem isso, /admin/desafios e
-- /admin/indicadores varrem findAll() e calculam em memoria (achado D7).

ALTER TABLE challenges ADD COLUMN risk_score NUMERIC(4,3) NOT NULL DEFAULT 0;
ALTER TABLE challenges ADD COLUMN risk_level VARCHAR(20) NOT NULL DEFAULT 'LOW';
ALTER TABLE challenges ADD COLUMN risk_updated_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX idx_challenges_risk ON challenges (risk_level, risk_score DESC);

-- Snapshot diario da distribuicao de risco do programa — alimenta o grafico de
-- evolucao no dashboard de Risco (B3). Uma linha por dia.
CREATE TABLE risk_snapshots (
    snapshot_on DATE PRIMARY KEY,
    low         INTEGER NOT NULL DEFAULT 0,
    medium      INTEGER NOT NULL DEFAULT 0,
    high        INTEGER NOT NULL DEFAULT 0,
    critical    INTEGER NOT NULL DEFAULT 0
);
