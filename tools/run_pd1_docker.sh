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
    -v "$TMP_DIR:/tmp/pd1:ro" \
    "$SQLCMD_IMAGE" \
    /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -b -i "$script_path"
}

run_sql_dw() {
  local script_path="$1"
  docker run --rm \
    --platform linux/amd64 \
    --network container:datawarehouse-sqlserver \
    -v "$ROOT_DIR:/workspace:ro" \
    -v "$TMP_DIR:/tmp/pd1:ro" \
    "$SQLCMD_IMAGE" \
    /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -b -d DataWarehouse -i "$script_path"
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

echo "Running database setup and PD1 load..."
run_sql "/workspace/Scripts/init_database.sql"
run_sql "/workspace/Scripts/Bronze/ddl_bronze.sql"
run_sql "/tmp/pd1/proc_load_bronze_docker.sql"
run_sql "/workspace/Scripts/Silver/ddl_silver.sql"
run_sql "/workspace/Scripts/Silver/proc_load_silver.sql"
run_sql "/workspace/Scripts/Docker/run_loads.sql"

echo "Running PD1 submission audit..."
run_sql_dw "/workspace/Scripts/PD1-SubmissionScript.sql" | tee "$ROOT_DIR/pd1_audit_output.txt"

echo "Done. Audit output saved to:"
echo "$ROOT_DIR/pd1_audit_output.txt"
