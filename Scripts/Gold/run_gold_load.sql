USE DataWarehouse;
GO

EXEC gold.load_gold;
GO

SELECT 'gold.load_log' AS log_table, table_name, rows_inserted, status, error_message
FROM gold.load_log
ORDER BY log_id;
GO
