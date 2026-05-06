-- use your database name here
--Use DataWarehouse;

-- =============================================================================
-- PD2 SUBMISSION AUDIT SCRIPT  |  Gold Layer Verification
-- Data Warehouse Course
-- =============================================================================
-- HOW IT WORKS:
--   1. Verifies the gold schema exists
--   2. Identifies and classifies Dimension and Fact tables
--   3. Validates surrogate keys on all tables
--   4. Checks fact-to-dimension foreign key relationships
--   5. Validates the Galaxy Schema (conformed dimensions across fact tables)
--   6. Shows row counts and sample data per table
--   7. Generates a UNIQUE STUDENT TOKEN based on:
--        - Database name
--        - Current SQL Server login
--        - Machine/host name
--        - Submission timestamp
--      This token is different for every student and every run.
--      Students CANNOT replicate each other's token by copying scripts.
-- =============================================================================

SET NOCOUNT ON;
PRINT '=============================================================================';
PRINT '        PD2 SUBMISSION AUDIT  |  Gold Layer  |  Data Warehouse Project';
PRINT '=============================================================================';
PRINT '';

-- =============================================================================
-- SECTION 0 :  STUDENT IDENTITY & ANTI-PLAGIARISM TOKEN
-- =============================================================================

DECLARE @db_name     NVARCHAR(128) = DB_NAME();
DECLARE @login_name  NVARCHAR(128) = SUSER_SNAME();
DECLARE @host_name   NVARCHAR(128) = HOST_NAME();
DECLARE @submit_time NVARCHAR(30)  = CONVERT(NVARCHAR(30), GETDATE(), 120);

DECLARE @seed_string NVARCHAR(512) =
    @db_name + '|' + @login_name + '|' + @host_name + '|' + @submit_time;

DECLARE @raw_hash VARBINARY(32) = HASHBYTES('SHA2_256', @seed_string);
DECLARE @token    NVARCHAR(64)  =
    UPPER(SUBSTRING(CONVERT(NVARCHAR(64), @raw_hash, 2), 1, 32));

PRINT '-------------------------------------------------------------';
PRINT ' STUDENT SUBMISSION RECORD';
PRINT '-------------------------------------------------------------';
PRINT ' Database    : ' + @db_name;
PRINT ' Login       : ' + @login_name;
PRINT ' Host        : ' + @host_name;
PRINT ' Submitted   : ' + @submit_time;
PRINT ' ';
PRINT ' ANTI-PLAGIARISM TOKEN:';
PRINT ' >>> ' + @token + ' <<<';
PRINT ' ';
PRINT ' NOTE: This token is unique to YOUR database, login, machine,';
PRINT '       and submission time. Any copy of this script run on a';
PRINT '       different environment will produce a different token.';
PRINT '-------------------------------------------------------------';
PRINT '';

-- =============================================================================
-- SECTION 1 :  SCHEMA VERIFICATION
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 1 : SCHEMA CHECK';
PRINT '=============================================================================';

SELECT
    s.schema_id,
    s.name                              AS schema_name,
    p.name                              AS schema_owner,
    CASE
        WHEN s.name = 'gold' THEN 'REQUIRED  ✓'
        ELSE 'extra'
    END                                 AS status
FROM sys.schemas           s
JOIN sys.database_principals p ON s.principal_id = p.principal_id
WHERE s.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys',
                     'db_owner','db_accessadmin','db_securityadmin',
                     'db_ddladmin','db_backupoperator','db_datareader',
                     'db_datawriter','db_denydatareader','db_denydatawriter')
ORDER BY s.name;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    PRINT '  *** WARNING: Schema [gold] was NOT found! ***';

PRINT '';

-- =============================================================================
-- SECTION 2 :  TABLE INVENTORY & CLASSIFICATION
--              Classifies tables by prefix: dim_ / fact_ / other
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 2 : TABLE INVENTORY & CLASSIFICATION';
PRINT '=============================================================================';

SELECT
    t.name                              AS table_name,
    CASE
        WHEN t.name LIKE 'dim_%'  THEN 'Dimension'
        WHEN t.name LIKE 'fact_%' THEN 'Fact'
        ELSE                           'Unclassified – check naming convention'
    END                                 AS table_type,
    t.create_date                       AS created_at,
    t.modify_date                       AS last_modified,
    p.rows                              AS total_rows
FROM sys.tables     t
JOIN sys.schemas    s ON t.schema_id  = s.schema_id
JOIN sys.partitions p ON t.object_id  = p.object_id
                     AND p.index_id  IN (0, 1)
WHERE s.name = 'gold'
ORDER BY table_type, t.name;

-- Warn if no dim_ or fact_ tables found
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'gold' AND t.name LIKE 'dim_%')
    PRINT '  *** WARNING: No Dimension tables (dim_) found in [gold]! ***';

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'gold' AND t.name LIKE 'fact_%')
    PRINT '  *** WARNING: No Fact tables (fact_) found in [gold]! ***';

PRINT '';

-- =============================================================================
-- SECTION 3 :  COLUMN DEFINITIONS
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 3 : COLUMN DEFINITIONS';
PRINT '=============================================================================';

SELECT
    t.name                              AS table_name,
    CASE
        WHEN t.name LIKE 'dim_%'  THEN 'Dimension'
        WHEN t.name LIKE 'fact_%' THEN 'Fact'
        ELSE 'Unclassified'
    END                                 AS table_type,
    c.column_id,
    c.name                              AS column_name,
    tp.name                             AS data_type,
    CASE tp.name
        WHEN 'nvarchar' THEN CAST(c.max_length/2 AS VARCHAR) + ' chars'
        WHEN 'varchar'  THEN CAST(c.max_length   AS VARCHAR) + ' chars'
        WHEN 'decimal'  THEN CAST(c.precision AS VARCHAR)
                              + ',' + CAST(c.scale AS VARCHAR)
        ELSE ''
    END                                 AS size_info,
    CASE c.is_nullable
        WHEN 1 THEN 'NULL'
        ELSE        'NOT NULL'
    END                                 AS nullable,
    CASE WHEN ic.object_id IS NOT NULL THEN 'PK' ELSE '' END AS is_pk
FROM sys.columns c
JOIN sys.tables  t  ON c.object_id    = t.object_id
JOIN sys.schemas s  ON t.schema_id    = s.schema_id
JOIN sys.types   tp ON c.user_type_id = tp.user_type_id
LEFT JOIN (
    SELECT ic2.object_id, ic2.column_id
    FROM sys.index_columns ic2
    JOIN sys.indexes ix ON ic2.object_id = ix.object_id
                       AND ic2.index_id  = ix.index_id
    WHERE ix.is_primary_key = 1
) ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE s.name = 'gold'
ORDER BY table_type, t.name, c.column_id;

PRINT '';

-- =============================================================================
-- SECTION 4 :  SURROGATE KEY VALIDATION
--              Every dim_ and fact_ table must have a surrogate key (int/bigint PK)
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 4 : SURROGATE KEY VALIDATION';
PRINT '=============================================================================';

SELECT
    t.name                              AS table_name,
    CASE
        WHEN t.name LIKE 'dim_%'  THEN 'Dimension'
        WHEN t.name LIKE 'fact_%' THEN 'Fact'
        ELSE 'Unclassified'
    END                                 AS table_type,
    c.name                              AS surrogate_key_column,
    tp.name                             AS data_type,
    CASE
        WHEN tp.name IN ('int','bigint') THEN 'OK  – valid surrogate key type'
        ELSE 'WARNING – surrogate key should be INT or BIGINT'
    END                                 AS validation
FROM sys.tables       t
JOIN sys.schemas      s   ON t.schema_id    = s.schema_id
JOIN sys.indexes      ix  ON t.object_id    = ix.object_id
                         AND ix.is_primary_key = 1
JOIN sys.index_columns ic ON ix.object_id   = ic.object_id
                         AND ix.index_id    = ic.index_id
JOIN sys.columns      c   ON ic.object_id   = c.object_id
                         AND ic.column_id   = c.column_id
JOIN sys.types        tp  ON c.user_type_id = tp.user_type_id
WHERE s.name = 'gold'
  AND t.name LIKE 'dim_%' OR t.name LIKE 'fact_%'
ORDER BY table_type, t.name;

-- Flag gold tables missing a primary key entirely
PRINT '';
PRINT '  Tables in [gold] with NO primary key defined:';
SELECT
    t.name  AS table_name,
    'WARNING – No primary key found' AS issue
FROM sys.tables  t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'gold'
  AND NOT EXISTS (
      SELECT 1 FROM sys.indexes ix
      WHERE ix.object_id = t.object_id AND ix.is_primary_key = 1);

PRINT '';

-- =============================================================================
-- SECTION 5 :  FACT-TO-DIMENSION FOREIGN KEY RELATIONSHIPS
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 5 : FACT-TO-DIMENSION RELATIONSHIP CHECK';
PRINT '=============================================================================';

-- 5a – Defined foreign keys
PRINT '5a  Foreign keys explicitly defined:';
SELECT
    fk.name                             AS fk_name,
    tp_tbl.name                         AS fact_table,
    fk_col.name                         AS fk_column,
    ref_tbl.name                        AS referenced_dimension,
    ref_col.name                        AS referenced_column
FROM sys.foreign_keys          fk
JOIN sys.tables                tp_tbl  ON fk.parent_object_id      = tp_tbl.object_id
JOIN sys.schemas               s       ON tp_tbl.schema_id         = s.schema_id
JOIN sys.foreign_key_columns   fkc     ON fk.object_id             = fkc.constraint_object_id
JOIN sys.columns               fk_col  ON fkc.parent_object_id     = fk_col.object_id
                                      AND fkc.parent_column_id     = fk_col.column_id
JOIN sys.tables                ref_tbl ON fkc.referenced_object_id = ref_tbl.object_id
JOIN sys.columns               ref_col ON fkc.referenced_object_id = ref_col.object_id
                                      AND fkc.referenced_column_id = ref_col.column_id
WHERE s.name = 'gold'
ORDER BY tp_tbl.name, fk.name;

-- 5b – Identify fact table columns ending in _key that likely reference dimensions
PRINT '';
PRINT '5b  Surrogate key columns detected in Fact tables (referential consistency check):';
SELECT
    t.name                              AS fact_table,
    c.name                              AS key_column,
    CASE
        WHEN fkc.parent_column_id IS NOT NULL THEN 'FK defined  ✓'
        ELSE                                       'WARNING – no FK constraint found'
    END                                 AS fk_status
FROM sys.tables  t
JOIN sys.schemas s  ON t.schema_id    = s.schema_id
JOIN sys.columns c  ON t.object_id    = c.object_id
LEFT JOIN sys.foreign_key_columns fkc ON t.object_id = fkc.parent_object_id
                                     AND c.column_id = fkc.parent_column_id
WHERE s.name  = 'gold'
  AND t.name LIKE 'fact_%'
  AND (c.name LIKE '%_key' OR c.name LIKE '%_id')
ORDER BY t.name, c.name;

PRINT '';

-- =============================================================================
-- SECTION 6 :  GALAXY SCHEMA – CONFORMED DIMENSIONS CHECK
--              Identifies dimensions shared across multiple fact tables
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 6 : GALAXY SCHEMA  –  CONFORMED DIMENSIONS';
PRINT '=============================================================================';

-- Count how many fact tables reference each dimension via FK
PRINT '6a  Dimensions referenced by fact tables (via foreign keys):';
SELECT
    ref_tbl.name                        AS dimension_table,
    COUNT(DISTINCT tp_tbl.name)         AS referenced_by_n_fact_tables,
    (
        SELECT STRING_AGG(DISTINCT_FACTS.fact_name, ', ')
        FROM (
            SELECT DISTINCT tp_tbl2.name AS fact_name
            FROM sys.foreign_keys        fk2
            JOIN sys.tables              tp_tbl2  ON fk2.parent_object_id      = tp_tbl2.object_id
            JOIN sys.schemas             s2       ON tp_tbl2.schema_id         = s2.schema_id
            JOIN sys.foreign_key_columns fkc2     ON fk2.object_id             = fkc2.constraint_object_id
            JOIN sys.tables              ref_tbl2 ON fkc2.referenced_object_id = ref_tbl2.object_id
            WHERE s2.name       = 'gold'
              AND tp_tbl2.name LIKE 'fact_%'
              AND ref_tbl2.name  = ref_tbl.name
        ) AS DISTINCT_FACTS
    )                                   AS fact_tables,
    CASE
        WHEN COUNT(DISTINCT tp_tbl.name) > 1 THEN 'Conformed Dimension  ✓'
        ELSE 'Used by single fact table'
    END                                 AS conformed_status
FROM sys.foreign_keys        fk
JOIN sys.tables              tp_tbl  ON fk.parent_object_id      = tp_tbl.object_id
JOIN sys.schemas             s       ON tp_tbl.schema_id         = s.schema_id
JOIN sys.foreign_key_columns fkc     ON fk.object_id             = fkc.constraint_object_id
JOIN sys.tables              ref_tbl ON fkc.referenced_object_id = ref_tbl.object_id
WHERE s.name      = 'gold'
  AND tp_tbl.name LIKE 'fact_%'
  AND ref_tbl.name LIKE 'dim_%'
GROUP BY ref_tbl.name
ORDER BY referenced_by_n_fact_tables DESC;

-- 6b – Count star schemas (each fact table = one star)
PRINT '';
PRINT '6b  Star Schema count (one per fact table):';
WITH fact_dim_links AS (
    SELECT DISTINCT
        t.name       AS fact_table,
        ref_tbl.name AS dim_table
    FROM sys.tables               t
    JOIN sys.schemas              s      ON t.schema_id               = s.schema_id
    LEFT JOIN sys.foreign_keys    fk     ON t.object_id               = fk.parent_object_id
    LEFT JOIN sys.foreign_key_columns fkc ON fk.object_id             = fkc.constraint_object_id
    LEFT JOIN sys.tables          ref_tbl ON fkc.referenced_object_id = ref_tbl.object_id
                                         AND ref_tbl.name LIKE 'dim_%'
    WHERE s.name = 'gold'
      AND t.name LIKE 'fact_%'
)
SELECT
    fact_table,
    COUNT(dim_table)                    AS dimension_count,
    STRING_AGG(dim_table, ', ')         AS dimensions_linked,
    CASE
        WHEN COUNT(dim_table) >= 2 THEN 'Valid Star Schema  ✓'
        ELSE 'WARNING – fewer than 2 dimensions linked'
    END                                 AS star_status
FROM fact_dim_links
GROUP BY fact_table
ORDER BY fact_table;

PRINT '';

-- =============================================================================
-- SECTION 7 :  ROW COUNTS
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 7 : ROW COUNTS';
PRINT '=============================================================================';

SELECT
    t.name                              AS table_name,
    CASE
        WHEN t.name LIKE 'dim_%'  THEN 'Dimension'
        WHEN t.name LIKE 'fact_%' THEN 'Fact'
        ELSE 'Unclassified'
    END                                 AS table_type,
    p.rows                              AS total_rows,
    CASE
        WHEN p.rows = 0 THEN 'WARNING – table is empty'
        ELSE 'OK'
    END                                 AS status
FROM sys.tables     t
JOIN sys.schemas    s ON t.schema_id  = s.schema_id
JOIN sys.partitions p ON t.object_id  = p.object_id
                     AND p.index_id  IN (0, 1)
WHERE s.name = 'gold'
ORDER BY table_type, t.name;

PRINT '';

-- =============================================================================
-- SECTION 8 :  SAMPLE DATA  (top 10 rows per table)
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 8 : SAMPLE DATA  (top 10 rows per table)';
PRINT '=============================================================================';

DECLARE @sch_name   NVARCHAR(128);
DECLARE @tbl_name   NVARCHAR(128);
DECLARE @sample_sql NVARCHAR(MAX);

DECLARE smp_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name, t.name
    FROM   sys.tables  t
    JOIN   sys.schemas s ON t.schema_id = s.schema_id
    WHERE  s.name = 'gold'
    ORDER  BY
        CASE WHEN t.name LIKE 'dim_%' THEN 0 ELSE 1 END,
        t.name;

OPEN smp_cur;
FETCH NEXT FROM smp_cur INTO @sch_name, @tbl_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '';
    PRINT '--- [' + @sch_name + '].[' + @tbl_name + '] ---';

    SET @sample_sql =
        N'SELECT TOP 10 N''' + @tbl_name + N''' AS [Table_Name], * '
        + N'FROM [' + @sch_name + N'].[' + @tbl_name + N']';
    EXEC sp_executesql @sample_sql;

    FETCH NEXT FROM smp_cur INTO @sch_name, @tbl_name;
END;

CLOSE      smp_cur;
DEALLOCATE smp_cur;

PRINT '';

-- =============================================================================
-- SECTION 9 :  NULL AUDIT IN FACT TABLE KEY COLUMNS
--              Surrogate key columns in fact tables must never be NULL
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 9 : NULL AUDIT – FACT TABLE KEY COLUMNS';
PRINT '=============================================================================';

DECLARE @null_sql  NVARCHAR(MAX);
DECLARE @col_name  NVARCHAR(128);
DECLARE @col_parts NVARCHAR(MAX);

DECLARE null_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.name, t.name
    FROM   sys.tables  t
    JOIN   sys.schemas s ON t.schema_id = s.schema_id
    WHERE  s.name = 'gold' AND t.name LIKE 'fact_%'
    ORDER  BY t.name;

OPEN null_cur;
FETCH NEXT FROM null_cur INTO @sch_name, @tbl_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '';
    PRINT '--- [' + @sch_name + '].[' + @tbl_name + '] ---';

    SET @col_parts = N'';

    DECLARE col_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT c.name
        FROM   sys.columns c
        JOIN   sys.tables  t2 ON c.object_id  = t2.object_id
        JOIN   sys.schemas s2 ON t2.schema_id = s2.schema_id
        WHERE  s2.name = @sch_name AND t2.name = @tbl_name
          AND (c.name LIKE '%_key' OR c.name LIKE '%_id')
        ORDER  BY c.column_id;

    OPEN col_cur;
    FETCH NEXT FROM col_cur INTO @col_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF LEN(@col_parts) > 0 SET @col_parts += N', ';
        SET @col_parts +=
            N'SUM(CASE WHEN [' + @col_name + N'] IS NULL THEN 1 ELSE 0 END)'
            + N' AS [' + @col_name + N'_nulls]';
        FETCH NEXT FROM col_cur INTO @col_name;
    END;

    CLOSE      col_cur;
    DEALLOCATE col_cur;

    IF LEN(@col_parts) > 0
    BEGIN
        SET @null_sql =
            N'SELECT ' + @col_parts
            + N' FROM [' + @sch_name + N'].[' + @tbl_name + N']';
        EXEC sp_executesql @null_sql;
    END
    ELSE
        PRINT '  No _key or _id columns found in this fact table.';

    FETCH NEXT FROM null_cur INTO @sch_name, @tbl_name;
END;

CLOSE      null_cur;
DEALLOCATE null_cur;

PRINT '';

-- =============================================================================
-- SECTION 10 :  SILVER → GOLD TRACEABILITY
--               Compares row counts between silver and gold for matching table names
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 10 : SILVER  →  GOLD TRACEABILITY';
PRINT '=============================================================================';

SELECT
    sv.table_name                       AS silver_table,
    g.table_name                        AS gold_table,
    sv.row_count                        AS silver_rows,
    g.row_count                         AS gold_rows,
    CASE
        WHEN g.row_count  = sv.row_count THEN 'OK  – counts match'
        WHEN g.row_count  < sv.row_count THEN 'NOTE – rows reduced (aggregation/filter expected)'
        WHEN g.row_count  > sv.row_count THEN 'CHECK – gold has more rows than silver'
        ELSE 'N/A'
    END                                 AS assessment
FROM (
    SELECT t.name AS table_name, p.rows AS row_count
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    WHERE s.name = 'silver'
) sv
JOIN (
    SELECT t.name AS table_name, p.rows AS row_count
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    WHERE s.name = 'gold'
) g ON g.table_name LIKE '%' + sv.table_name + '%'
    OR sv.table_name LIKE '%' + g.table_name + '%'
ORDER BY sv.table_name;

PRINT '';

-- =============================================================================
-- SECTION 11 :  FINAL SUBMISSION SUMMARY
-- =============================================================================

PRINT '=============================================================================';
PRINT ' SECTION 11 : FINAL SUBMISSION SUMMARY';
PRINT '=============================================================================';
PRINT '';

DECLARE @gold_dim_count  INT;
DECLARE @gold_fact_count INT;
DECLARE @gold_total_rows BIGINT;

SELECT @gold_dim_count = COUNT(*)
FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'gold' AND t.name LIKE 'dim_%';

SELECT @gold_fact_count = COUNT(*)
FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'gold' AND t.name LIKE 'fact_%';

SELECT @gold_total_rows = SUM(p.rows)
FROM sys.tables t
JOIN sys.schemas    s ON t.schema_id = s.schema_id
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
WHERE s.name = 'gold';

DECLARE @star_count INT;
SELECT @star_count = COUNT(DISTINCT t.name)
FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'gold' AND t.name LIKE 'fact_%';

DECLARE @conformed_count INT;
SELECT @conformed_count = COUNT(*)
FROM (
    SELECT ref_tbl.name
    FROM sys.foreign_keys        fk
    JOIN sys.tables              tp_tbl  ON fk.parent_object_id      = tp_tbl.object_id
    JOIN sys.schemas             sc      ON tp_tbl.schema_id         = sc.schema_id
    JOIN sys.foreign_key_columns fkc     ON fk.object_id             = fkc.constraint_object_id
    JOIN sys.tables              ref_tbl ON fkc.referenced_object_id = ref_tbl.object_id
    WHERE sc.name = 'gold' AND tp_tbl.name LIKE 'fact_%' AND ref_tbl.name LIKE 'dim_%'
    GROUP BY ref_tbl.name
    HAVING COUNT(DISTINCT tp_tbl.name) > 1
) conf;

PRINT '  Database              : ' + @db_name;
PRINT '  Student Login         : ' + @login_name;
PRINT '  Host                  : ' + @host_name;
PRINT '  Run Timestamp         : ' + @submit_time;
PRINT '';
PRINT '  Dimension tables      : ' + CAST(@gold_dim_count  AS VARCHAR);
PRINT '  Fact tables           : ' + CAST(@gold_fact_count AS VARCHAR);
PRINT '  Star schemas detected : ' + CAST(@star_count      AS VARCHAR);
PRINT '  Conformed dimensions  : ' + CAST(@conformed_count AS VARCHAR);
PRINT '  Gold total rows       : ' + CAST(ISNULL(@gold_total_rows, 0) AS VARCHAR);
PRINT '';
PRINT '  ANTI-PLAGIARISM TOKEN : ' + @token;
PRINT '';
PRINT '=============================================================================';
PRINT '  Students must submit this full output (Results + Messages tabs)';
PRINT '  along with their Gold Layer .sql script and project report.';
PRINT '  The token proves the script was run live on YOUR own database.';
PRINT '=============================================================================';