/*
===============================================================================
Validation Script: validate_gold.sql
Purpose:    Checks Gold row counts, fact grain uniqueness, and FK integrity.
===============================================================================
*/

USE DataWarehouse;
GO

-- ============================================================
-- ROW COUNTS
-- ============================================================
SELECT 'gold.dim_date' AS table_name, COUNT(*) AS row_count FROM gold.dim_date
UNION ALL SELECT 'gold.dim_customer', COUNT(*) FROM gold.dim_customer
UNION ALL SELECT 'gold.dim_product', COUNT(*) FROM gold.dim_product
UNION ALL SELECT 'gold.dim_promotion', COUNT(*) FROM gold.dim_promotion
UNION ALL SELECT 'gold.dim_store', COUNT(*) FROM gold.dim_store
UNION ALL SELECT 'gold.dim_register', COUNT(*) FROM gold.dim_register
UNION ALL SELECT 'gold.dim_employee', COUNT(*) FROM gold.dim_employee
UNION ALL SELECT 'gold.dim_warehouse', COUNT(*) FROM gold.dim_warehouse
UNION ALL SELECT 'gold.fact_store_sales', COUNT(*) FROM gold.fact_store_sales
UNION ALL SELECT 'gold.fact_online_sales', COUNT(*) FROM gold.fact_online_sales;
GO

-- ============================================================
-- SOURCE-TO-GOLD FACT RECONCILIATION
-- ============================================================
SELECT
    'Store Sales' AS fact_name,
    (SELECT COUNT(*) FROM silver.transaction_items ti
        INNER JOIN silver.pos_transactions pt ON ti.Transaction_ID = pt.Transaction_ID) AS silver_source_rows,
    (SELECT COUNT(*) FROM gold.fact_store_sales) AS gold_fact_rows
UNION ALL
SELECT
    'Online Sales',
    (SELECT COUNT(*) FROM silver.online_order_items oi
        INNER JOIN silver.online_orders oo ON oi.Order_ID = oo.Order_ID),
    (SELECT COUNT(*) FROM gold.fact_online_sales);
GO

-- ============================================================
-- FACT GRAIN DUPLICATES
-- Expected duplicate_count = 0 for both rows.
-- ============================================================
SELECT 'gold.fact_store_sales' AS table_name, COUNT(*) AS duplicate_count
FROM (
    SELECT Transaction_Number, Transaction_Line_No
    FROM gold.fact_store_sales
    GROUP BY Transaction_Number, Transaction_Line_No
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'gold.fact_online_sales', COUNT(*)
FROM (
    SELECT Order_Number, Order_Item_Number
    FROM gold.fact_online_sales
    GROUP BY Order_Number, Order_Item_Number
    HAVING COUNT(*) > 1
) d;
GO

-- ============================================================
-- FK ORPHAN CHECKS
-- Expected orphan_count = 0 for every row.
-- ============================================================
SELECT 'fact_store_sales -> dim_date' AS relationship_name, COUNT(*) AS orphan_count
FROM gold.fact_store_sales f LEFT JOIN gold.dim_date d ON f.Date_Key = d.Date_Key
WHERE d.Date_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_customer', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_customer d ON f.Customer_Key = d.Customer_Key
WHERE d.Customer_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_product', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_product d ON f.Product_Key = d.Product_Key
WHERE d.Product_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_store', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_store d ON f.Store_Key = d.Store_Key
WHERE d.Store_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_register', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_register d ON f.Register_Key = d.Register_Key
WHERE d.Register_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_employee', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_employee d ON f.Employee_Key = d.Employee_Key
WHERE d.Employee_Key IS NULL
UNION ALL
SELECT 'fact_store_sales -> dim_promotion', COUNT(*)
FROM gold.fact_store_sales f LEFT JOIN gold.dim_promotion d ON f.Promotion_Key = d.Promotion_Key
WHERE d.Promotion_Key IS NULL
UNION ALL
SELECT 'fact_online_sales -> dim_date', COUNT(*)
FROM gold.fact_online_sales f LEFT JOIN gold.dim_date d ON f.Date_Key = d.Date_Key
WHERE d.Date_Key IS NULL
UNION ALL
SELECT 'fact_online_sales -> dim_customer', COUNT(*)
FROM gold.fact_online_sales f LEFT JOIN gold.dim_customer d ON f.Customer_Key = d.Customer_Key
WHERE d.Customer_Key IS NULL
UNION ALL
SELECT 'fact_online_sales -> dim_product', COUNT(*)
FROM gold.fact_online_sales f LEFT JOIN gold.dim_product d ON f.Product_Key = d.Product_Key
WHERE d.Product_Key IS NULL
UNION ALL
SELECT 'fact_online_sales -> dim_warehouse', COUNT(*)
FROM gold.fact_online_sales f LEFT JOIN gold.dim_warehouse d ON f.Warehouse_Key = d.Warehouse_Key
WHERE d.Warehouse_Key IS NULL
UNION ALL
SELECT 'fact_online_sales -> dim_promotion', COUNT(*)
FROM gold.fact_online_sales f LEFT JOIN gold.dim_promotion d ON f.Promotion_Key = d.Promotion_Key
WHERE d.Promotion_Key IS NULL;
GO

SELECT 'gold.load_log' AS log_table, table_name, rows_inserted, status, error_message
FROM gold.load_log
ORDER BY log_id;
GO
