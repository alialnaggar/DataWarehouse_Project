#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SA_PASSWORD="${MSSQL_SA_PASSWORD:-BIntP_Strong_Passw0rd!}"
SQLCMD_IMAGE="${SQLCMD_IMAGE:-mcr.microsoft.com/mssql-tools:latest}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_sql() {
  local script_path="$1"
  docker run --rm \
    --platform linux/amd64 \
    --network container:datawarehouse-sqlserver \
    -v "$ROOT_DIR:/workspace:ro" \
    -v "$TMP_DIR:/tmp/pd2:ro" \
    "$SQLCMD_IMAGE" \
    /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -b -i "$script_path"
}

echo "Starting SQL Server Docker container..."
cd "$ROOT_DIR"
MSSQL_SA_PASSWORD="$SA_PASSWORD" docker compose up -d sqlserver

echo "Waiting for SQL Server to accept connections..."
for attempt in {1..90}; do
  if docker run --rm \
      --platform linux/amd64 \
      --network container:datawarehouse-sqlserver \
      "$SQLCMD_IMAGE" \
      /opt/mssql-tools/bin/sqlcmd \
      -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT 1" >/dev/null 2>&1; then
    break
  fi

  if [[ "$attempt" == "90" ]]; then
    echo "SQL Server did not become ready in time." >&2
    exit 1
  fi

  sleep 2
done

echo "Preparing Docker-specific Bronze loader paths..."
perl -pe "s#C:\\\\sql\\\\datasets\\\\#/var/opt/mssql/datasets/#g; s/, CODEPAGE = '65001'//g" \
  "$ROOT_DIR/Scripts/Bronze/proc_load_bronze.sql" \
  > "$TMP_DIR/proc_load_bronze_docker.sql"

echo "Running Bronze, Silver, and Gold layers..."
run_sql "/workspace/Scripts/init_database.sql"
run_sql "/workspace/Scripts/Bronze/ddl_bronze.sql"
run_sql "/tmp/pd2/proc_load_bronze_docker.sql"
run_sql "/workspace/Scripts/Silver/ddl_silver.sql"
run_sql "/workspace/Scripts/Silver/proc_load_silver.sql"
run_sql "/workspace/Scripts/Gold/ddl_gold.sql"
run_sql "/workspace/Scripts/Gold/proc_load_gold.sql"
run_sql "/workspace/Scripts/Docker/run_loads.sql"
run_sql "/workspace/Scripts/Gold/run_gold_load.sql"
run_sql "/workspace/Scripts/Gold/validate_gold.sql"

echo "Done. Gold validation completed."
