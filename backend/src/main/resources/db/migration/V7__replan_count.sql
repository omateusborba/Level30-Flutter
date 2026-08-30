-- C2 · Replanejamento assistido por IA (F2). Cada desafio pode ser replanejado
-- no maximo 2 vezes; o contador vive aqui.

ALTER TABLE challenges ADD COLUMN replan_count INTEGER NOT NULL DEFAULT 0;
