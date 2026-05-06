/*
===============================================================================
Validation Script: validate_gold.sql
Purpose:    Practical checks for the PD2 Gold Layer before running the official
            PD2-SubmissionScript-Final.sql audit in SSMS.
===============================================================================
*/

USE DataWarehouse;
GO

PRINT '=============================================================================';
PRINT ' GOLD LAYER ROW COUNTS';
PRINT '=============================================================================';

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(p.rows) AS rows_count
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
    AND p.index_id IN (0, 1)
WHERE s.name = 'gold'
GROUP BY s.name, t.name
ORDER BY t.name;

PRINT '=============================================================================';
PRINT ' FACT KEY NULL CHECKS';
PRINT '=============================================================================';

SELECT
    'gold.fact_store_sales' AS table_name,
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) AS date_key_nulls,
    SUM(CASE WHEN store_key IS NULL THEN 1 ELSE 0 END) AS store_key_nulls,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS product_key_nulls,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS customer_key_nulls,
    SUM(CASE WHEN employee_key IS NULL THEN 1 ELSE 0 END) AS employee_key_nulls,
    SUM(CASE WHEN promotion_key IS NULL THEN 1 ELSE 0 END) AS promotion_key_nulls
FROM gold.fact_store_sales;

SELECT
    'gold.fact_online_sales' AS table_name,
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) AS date_key_nulls,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS customer_key_nulls,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS product_key_nulls,
    SUM(CASE WHEN warehouse_key IS NULL THEN 1 ELSE 0 END) AS warehouse_key_nulls,
    SUM(CASE WHEN promotion_key IS NULL THEN 1 ELSE 0 END) AS promotion_key_nulls,
    SUM(CASE WHEN order_status_key IS NULL THEN 1 ELSE 0 END) AS order_status_key_nulls,
    SUM(CASE WHEN payment_method_key IS NULL THEN 1 ELSE 0 END) AS payment_method_key_nulls
FROM gold.fact_online_sales;

PRINT '=============================================================================';
PRINT ' DUPLICATE DIMENSION NATURAL KEY CHECKS';
PRINT '=============================================================================';

SELECT 'gold.dim_date' AS table_name, full_date AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_date
GROUP BY full_date
HAVING COUNT(*) > 1;

SELECT 'gold.dim_customer' AS table_name, customer_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_product' AS table_name, product_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_product
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_promotion' AS table_name, promotion_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_promotion
GROUP BY promotion_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_store' AS table_name, store_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_store
GROUP BY store_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_employee' AS table_name, employee_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_employee
GROUP BY employee_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_warehouse' AS table_name, warehouse_id AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_warehouse
GROUP BY warehouse_id
HAVING COUNT(*) > 1;

SELECT 'gold.dim_order_status' AS table_name, status_name AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_order_status
GROUP BY status_name
HAVING COUNT(*) > 1;

SELECT 'gold.dim_payment_method' AS table_name, payment_method_name AS natural_key, COUNT(*) AS duplicate_count
FROM gold.dim_payment_method
GROUP BY payment_method_name
HAVING COUNT(*) > 1;

PRINT '=============================================================================';
PRINT ' FACT TO DIMENSION JOIN CHECKS';
PRINT '=============================================================================';

SELECT
    'fact_store_sales to all dimensions' AS check_name,
    COUNT(*) AS orphan_rows
FROM gold.fact_store_sales f
LEFT JOIN gold.dim_date d ON f.date_key = d.date_key
LEFT JOIN gold.dim_store s ON f.store_key = s.store_key
LEFT JOIN gold.dim_product p ON f.product_key = p.product_key
LEFT JOIN gold.dim_customer c ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_employee e ON f.employee_key = e.employee_key
LEFT JOIN gold.dim_promotion pr ON f.promotion_key = pr.promotion_key
WHERE d.date_key IS NULL
   OR s.store_key IS NULL
   OR p.product_key IS NULL
   OR c.customer_key IS NULL
   OR e.employee_key IS NULL
   OR pr.promotion_key IS NULL;

SELECT
    'fact_online_sales to all dimensions' AS check_name,
    COUNT(*) AS orphan_rows
FROM gold.fact_online_sales f
LEFT JOIN gold.dim_date d ON f.date_key = d.date_key
LEFT JOIN gold.dim_customer c ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_product p ON f.product_key = p.product_key
LEFT JOIN gold.dim_warehouse w ON f.warehouse_key = w.warehouse_key
LEFT JOIN gold.dim_promotion pr ON f.promotion_key = pr.promotion_key
LEFT JOIN gold.dim_order_status os ON f.order_status_key = os.order_status_key
LEFT JOIN gold.dim_payment_method pm ON f.payment_method_key = pm.payment_method_key
WHERE d.date_key IS NULL
   OR c.customer_key IS NULL
   OR p.product_key IS NULL
   OR w.warehouse_key IS NULL
   OR pr.promotion_key IS NULL
   OR os.order_status_key IS NULL
   OR pm.payment_method_key IS NULL;

PRINT '=============================================================================';
PRINT ' SILVER TO GOLD FACT GRAIN CHECKS';
PRINT '=============================================================================';

SELECT
    'Store sales line-item grain' AS check_name,
    (SELECT COUNT(*) FROM silver.transaction_items) AS silver_line_items,
    (SELECT COUNT(*) FROM gold.fact_store_sales) AS gold_fact_rows;

SELECT
    'Online sales line-item grain' AS check_name,
    (SELECT COUNT(*) FROM silver.online_order_items) AS silver_line_items,
    (SELECT COUNT(*) FROM gold.fact_online_sales) AS gold_fact_rows;

PRINT '=============================================================================';
PRINT ' CONFORMED DIMENSION CHECK';
PRINT '=============================================================================';

SELECT
    ref_tbl.name AS conformed_dimension,
    COUNT(DISTINCT fact_tbl.name) AS referenced_by_fact_count,
    STRING_AGG(fact_tbl.name, ', ') AS fact_tables
FROM sys.foreign_keys fk
JOIN sys.tables fact_tbl
    ON fk.parent_object_id = fact_tbl.object_id
JOIN sys.schemas fact_schema
    ON fact_tbl.schema_id = fact_schema.schema_id
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
JOIN sys.tables ref_tbl
    ON fkc.referenced_object_id = ref_tbl.object_id
WHERE fact_schema.name = 'gold'
  AND fact_tbl.name LIKE 'fact_%'
  AND ref_tbl.name LIKE 'dim_%'
GROUP BY ref_tbl.name
HAVING COUNT(DISTINCT fact_tbl.name) > 1
ORDER BY ref_tbl.name;
GO
