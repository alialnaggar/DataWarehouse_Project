# macOS Docker Verification

This folder is only for local verification on macOS/Linux. It does not replace the normal submission SQL scripts.

The original Bronze procedure uses Windows-style CSV paths such as:

```sql
C:\sql\datasets\CUSTOMERS.csv
```

The Docker runner creates a temporary copy of that procedure with paths changed to:

```sql
/var/opt/mssql/datasets/CUSTOMERS.csv
```

That path exists inside the SQL Server container because `docker-compose.yml` mounts the repo `Datasets/` folder there.

Run from the repository root:

```bash
./tools/run_pd1_docker.sh
```

The script starts SQL Server, creates the database, loads Bronze and Silver, then runs the PD1 submission audit script.
