#!/usr/bin/env bash
# Reset ÚNICO da demo: roda o seed (PostgreSQL/H2 + Oracle, mesmas pessoas e IDs, paridade conferida) e, se
# informado, limpa resíduo de testes antigos no Oracle (98). Ver docs/fase7/02_ROTEIRO_DEMO.md.
#
#   ORACLE_URL=... ORACLE_USER=... ORACLE_PASSWORD=... scripts/demo-reset.sh
#   (opcional) ORACLE_DOCKER_CONTAINER=level30-oracle  -> também roda db/oracle/98 dentro do container
#
# Herda as travas de scripts/demo-seed.sh: recusa qualquer banco que não seja local ou de demo.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/demo-seed.sh

if [ -n "${ORACLE_DOCKER_CONTAINER:-}" ] && [ -n "${ORACLE_USER:-}" ]; then
  echo "Limpando resíduo de testes no Oracle (98)..."
  docker exec -i -w /scripts "$ORACLE_DOCKER_CONTAINER" sqlplus -L -S \
    "$ORACLE_USER/$ORACLE_PASSWORD@//localhost/FREEPDB1" @98_limpa_residuo_testes.sql
fi
echo "Reset concluído. Aluno do roteiro: larissa@level30.app (senha da demo no seed)."
