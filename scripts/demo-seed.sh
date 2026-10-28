#!/usr/bin/env bash
# Seed ÚNICO da demo: reseta e popula PostgreSQL/H2 e (se configurado) Oracle com as mesmas pessoas e IDs,
# ~90 dias de histórico, XP, conquistas, risco e snapshots. Idempotente: pode rodar quantas vezes quiser.
#
# Uso:
#   scripts/demo-seed.sh                       # só o banco local da API (H2 em backend/data)
#   ORACLE_URL=jdbc:oracle:thin:@//localhost:1521/FREEPDB1 ORACLE_USER=... ORACLE_PASSWORD=... \
#     scripts/demo-seed.sh                     # também zera e popula a réplica Oracle
#   DB_URL=jdbc:postgresql://localhost:5432/level30 DB_USER=... DB_PASSWORD=... scripts/demo-seed.sh
#
# TRAVA: se DB_URL ou ORACLE_URL não forem locais (H2, localhost, 127.0.0.1) nem de "demo", o script aborta ANTES
# de abrir qualquer conexão, e a aplicação repete a checagem. Nunca coloque credenciais neste arquivo.
set -euo pipefail
cd "$(dirname "$0")/.."

eh_local() { case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
  jdbc:h2:*|*localhost*|*127.0.0.1*|*host.docker.internal*|*demo*) return 0 ;; *) return 1 ;; esac; }

DB_URL_EFETIVA="${DB_URL:-jdbc:h2:file:./data/level30;AUTO_SERVER=TRUE}"
if ! eh_local "$DB_URL_EFETIVA"; then
  echo "ABORTADO: DB_URL não é local nem de demo. Nada foi apagado." >&2; exit 2
fi
ARGS=(--server.port=0 --app.seed.enabled=false --level30.demo.seed.run=true --level30.demo.seed.exit-after=true)
if [ -n "${ORACLE_URL:-}" ]; then
  if ! eh_local "$ORACLE_URL"; then
    echo "ABORTADO: ORACLE_URL não é local nem de demo. Nada foi apagado." >&2; exit 2
  fi
  export LEVEL30_ORACLE_ENABLED=true
fi

JAR=$(ls backend/target/level30-api-*.jar 2>/dev/null | grep -v original | head -n1 || true)
if [ -z "$JAR" ]; then
  echo "Jar não encontrado; compilando (mvn -DskipTests package)..."
  (cd backend && mvn -B -q -DskipTests package)
  JAR=$(ls backend/target/level30-api-*.jar | grep -v original | head -n1)
fi

echo "Seed da demo -> banco: ${DB_URL_EFETIVA%%\?*} | Oracle: ${ORACLE_URL:-desligado}"
java -jar "$JAR" "${ARGS[@]}"
