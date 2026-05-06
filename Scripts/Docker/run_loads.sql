USE DataWarehouse;
GO

EXEC bronze.load_bronze;
GO

EXEC silver.load_silver;
GO

SELECT 'bronze.load_log' AS log_table, table_name, rows_inserted, status, error_message
FROM bronze.load_log
ORDER BY log_id;

SELECT 'silver.load_log' AS log_table, table_name, rows_inserted, status, error_message
FROM silver.load_log
ORDER BY log_id;
GO
