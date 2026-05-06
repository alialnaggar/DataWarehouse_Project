/*
===============================================================================
Stored Procedure: proc_load_gold.sql
Purpose:  Loads the Gold Layer Galaxy Schema from Silver tables.

Business processes:
  1. Store Sales Performance  - one row per POS transaction line item
  2. Online Sales Performance - one row per online order line item

Conformed dimensions:
  gold.dim_date, gold.dim_customer, gold.dim_product, gold.dim_promotion
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @start_time DATETIME = GETDATE();

    PRINT '======================================================';
    PRINT 'Starting Gold Layer Load';
    PRINT 'Procedure : gold.load_gold';
    PRINT 'Start Time: ' + CAST(@start_time AS NVARCHAR(50));
    PRINT '======================================================';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Facts first because they reference dimensions.
        DELETE FROM gold.fact_online_sales;
        DELETE FROM gold.fact_store_sales;

        DELETE FROM gold.dim_payment_method;
        DELETE FROM gold.dim_order_status;
        DELETE FROM gold.dim_warehouse;
        DELETE FROM gold.dim_employee;
        DELETE FROM gold.dim_store;
        DELETE FROM gold.dim_promotion;
        DELETE FROM gold.dim_product;
        DELETE FROM gold.dim_customer;
        DELETE FROM gold.dim_date;

        -- ============================================================
        -- DATE DIMENSION
        -- Includes one unknown date member plus all analytical dates
        -- needed by the two facts and supporting dimensions.
        -- ============================================================
        WITH source_dates AS (
            SELECT CAST('19000101' AS DATE) AS full_date
            UNION
            SELECT Transaction_Date FROM silver.pos_transactions WHERE Transaction_Date IS NOT NULL
            UNION
            SELECT Order_Date FROM silver.online_orders WHERE Order_Date IS NOT NULL
            UNION
            SELECT Start_Date FROM silver.promotions WHERE Start_Date IS NOT NULL
            UNION
            SELECT End_Date FROM silver.promotions WHERE End_Date IS NOT NULL
            UNION
            SELECT Opening_Date FROM silver.stores WHERE Opening_Date IS NOT NULL
            UNION
            SELECT Hire_Date FROM silver.employees WHERE Hire_Date IS NOT NULL
        )
        INSERT INTO gold.dim_date (
            full_date, day_number, month_number, month_name, quarter_number,
            year_number, day_of_week_number, day_name, is_weekend
        )
        SELECT
            full_date,
            DAY(full_date),
            MONTH(full_date),
            DATENAME(MONTH, full_date),
            DATEPART(QUARTER, full_date),
            YEAR(full_date),
            DATEPART(WEEKDAY, full_date),
            DATENAME(WEEKDAY, full_date),
            CASE WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
        FROM source_dates;

        PRINT 'Loaded gold.dim_date rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- CONFORMED CUSTOMER DIMENSION
        -- Customer_ID = 0 represents anonymous / missing customer.
        -- ============================================================
        INSERT INTO gold.dim_customer (
            customer_id, first_name, last_name, full_name, gender, city,
            loyalty_level, email
        )
        SELECT
            0,
            'Unknown',
            'Customer',
            'Unknown Customer',
            'Unknown',
            'Unknown',
            'Unknown',
            NULL
        UNION ALL
        SELECT
            Customer_ID,
            First_Name,
            Last_Name,
            Full_Name,
            Gender,
            City,
            Loyalty_Level,
            Email
        FROM silver.customers;

        PRINT 'Loaded gold.dim_customer rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- CONFORMED PRODUCT DIMENSION
        -- Product_ID = 0 represents missing product references.
        -- ============================================================
        INSERT INTO gold.dim_product (
            product_id, sku, product_name, brand_id, brand_name,
            department_id, department_name, package_size
        )
        SELECT
            0,
            'UNKNOWN',
            'Unknown Product',
            NULL,
            'Unknown',
            NULL,
            'Unknown',
            'N/A'
        UNION ALL
        SELECT
            Product_ID,
            SKU,
            Product_Name,
            Brand_ID,
            Brand_Name,
            Department_ID,
            Department_Name,
            Package_Size
        FROM silver.products;

        PRINT 'Loaded gold.dim_product rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- CONFORMED PROMOTION DIMENSION
        -- Promotion_ID = 0 represents no promotion.
        -- ============================================================
        INSERT INTO gold.dim_promotion (
            promotion_id, promo_type, discount_percent, start_date,
            end_date, promo_duration_days
        )
        SELECT
            0,
            'No Promotion',
            0.00,
            NULL,
            NULL,
            NULL
        UNION ALL
        SELECT
            Promotion_ID,
            Promo_Type,
            Discount_Percent,
            Start_Date,
            End_Date,
            Promo_Duration_Days
        FROM silver.promotions;

        PRINT 'Loaded gold.dim_promotion rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- STORE, EMPLOYEE, WAREHOUSE DIMENSIONS
        -- ============================================================
        INSERT INTO gold.dim_store (
            store_id, store_name, city, state, region, opening_date
        )
        SELECT
            0,
            'Unknown Store',
            'Unknown',
            'Unknown',
            'Unknown',
            NULL
        UNION ALL
        SELECT
            Store_ID,
            Store_Name,
            City,
            State,
            Region,
            Opening_Date
        FROM silver.stores;

        PRINT 'Loaded gold.dim_store rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        INSERT INTO gold.dim_employee (
            employee_id, employee_name, gender, position, store_id,
            hire_date, tenure_years
        )
        SELECT
            0,
            'Unknown Employee',
            'Unknown',
            'Unknown',
            0,
            NULL,
            NULL
        UNION ALL
        SELECT
            Employee_ID,
            Name,
            Gender,
            Position,
            Store_ID,
            Hire_Date,
            Tenure_Years
        FROM silver.employees;

        PRINT 'Loaded gold.dim_employee rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        INSERT INTO gold.dim_warehouse (
            warehouse_id, warehouse_name, city, state
        )
        SELECT
            0,
            'Unknown Warehouse',
            'Unknown',
            'Unknown'
        UNION ALL
        SELECT
            Warehouse_ID,
            Warehouse_Name,
            City,
            State
        FROM silver.warehouses;

        PRINT 'Loaded gold.dim_warehouse rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- ONLINE SALES SUPPORTING DIMENSIONS
        -- ============================================================
        INSERT INTO gold.dim_order_status (
            status_name, status_description
        )
        SELECT
            'Unknown',
            'Unknown or missing online order status'
        UNION
        SELECT DISTINCT
            Order_Status,
            CASE
                WHEN Order_Status = 'Delivered' THEN 'Order completed and delivered to the customer'
                WHEN Order_Status = 'Pending' THEN 'Order has been placed and is awaiting completion'
                WHEN Order_Status = 'Cancelled' THEN 'Order was cancelled before completion'
                WHEN Order_Status = 'Shipped' THEN 'Order has shipped and is in transit'
                ELSE 'Operational online order status'
            END
        FROM silver.online_orders
        WHERE Order_Status IS NOT NULL;

        PRINT 'Loaded gold.dim_order_status rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        INSERT INTO gold.dim_payment_method (
            payment_method_name, payment_provider
        )
        SELECT
            'Unknown',
            'Unknown'
        UNION
        SELECT DISTINCT
            Payment_Method,
            Payment_Method
        FROM silver.payments
        WHERE Payment_Method IS NOT NULL;

        PRINT 'Loaded gold.dim_payment_method rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- FACT 1: STORE SALES PERFORMANCE
        -- Grain: one POS transaction line item.
        -- ============================================================
        INSERT INTO gold.fact_store_sales (
            date_key, store_key, product_key, customer_key, employee_key,
            promotion_key, source_line_number, transaction_number, transaction_time,
            quantity, unit_price, gross_sales_amount, discount_percent,
            discount_amount, net_sales_amount
        )
        SELECT
            dd.date_key,
            COALESCE(ds.store_key, ds_unknown.store_key),
            COALESCE(dp.product_key, dp_unknown.product_key),
            COALESCE(dc.customer_key, dc_unknown.customer_key),
            COALESCE(de.employee_key, de_unknown.employee_key),
            COALESCE(dpr.promotion_key, dpr_none.promotion_key),
            ti.Line_ID,
            ti.Transaction_ID,
            pt.Transaction_Time,
            ti.Quantity,
            ti.Unit_Price,
            ti.Sales_Amount,
            ISNULL(ti.Discount_Percent, 0),
            ISNULL(ti.Discount_Amount, 0),
            ISNULL(ti.Net_Sales_Amount, ti.Sales_Amount)
        FROM silver.transaction_items ti
        LEFT JOIN silver.pos_transactions pt
            ON ti.Transaction_ID = pt.Transaction_ID
        JOIN gold.dim_date dd
            ON dd.full_date = ISNULL(pt.Transaction_Date, CAST('19000101' AS DATE))
        LEFT JOIN gold.dim_store ds
            ON ds.store_id = ISNULL(pt.Store_ID, 0)
        CROSS JOIN (SELECT store_key FROM gold.dim_store WHERE store_id = 0) ds_unknown
        LEFT JOIN gold.dim_product dp
            ON dp.product_id = ISNULL(ti.Product_ID, 0)
        CROSS JOIN (SELECT product_key FROM gold.dim_product WHERE product_id = 0) dp_unknown
        LEFT JOIN gold.dim_customer dc
            ON dc.customer_id = ISNULL(pt.Customer_ID, 0)
        CROSS JOIN (SELECT customer_key FROM gold.dim_customer WHERE customer_id = 0) dc_unknown
        LEFT JOIN gold.dim_employee de
            ON de.employee_id = ISNULL(pt.Employee_ID, 0)
        CROSS JOIN (SELECT employee_key FROM gold.dim_employee WHERE employee_id = 0) de_unknown
        LEFT JOIN gold.dim_promotion dpr
            ON dpr.promotion_id = ISNULL(ti.Promotion_ID, 0)
        CROSS JOIN (SELECT promotion_key FROM gold.dim_promotion WHERE promotion_id = 0) dpr_none;

        PRINT 'Loaded gold.fact_store_sales rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        -- ============================================================
        -- FACT 2: ONLINE SALES PERFORMANCE
        -- Grain: one online order line item.
        -- ============================================================
        INSERT INTO gold.fact_online_sales (
            date_key, customer_key, product_key, warehouse_key,
            promotion_key, order_status_key, payment_method_key,
            source_order_item_number, source_order_number,
            quantity, unit_price, gross_sales_amount, discount_percent,
            discount_amount, net_sales_amount, order_total
        )
        SELECT
            dd.date_key,
            COALESCE(dc.customer_key, dc_unknown.customer_key),
            COALESCE(dp.product_key, dp_unknown.product_key),
            COALESCE(dw.warehouse_key, dw_unknown.warehouse_key),
            COALESCE(dpr.promotion_key, dpr_none.promotion_key),
            COALESCE(dos.order_status_key, dos_unknown.order_status_key),
            COALESCE(dpm.payment_method_key, dpm_unknown.payment_method_key),
            oi.Order_Item_ID,
            oi.Order_ID,
            oi.Quantity,
            oi.Unit_Price,
            oi.Sales_Amount,
            ISNULL(oi.Discount_Percent, 0),
            ISNULL(oi.Discount_Amount, 0),
            ISNULL(oi.Net_Sales_Amount, oi.Sales_Amount),
            oo.Order_Total
        FROM silver.online_order_items oi
        LEFT JOIN silver.online_orders oo
            ON oi.Order_ID = oo.Order_ID
        JOIN gold.dim_date dd
            ON dd.full_date = ISNULL(oo.Order_Date, CAST('19000101' AS DATE))
        LEFT JOIN gold.dim_customer dc
            ON dc.customer_id = ISNULL(oo.Customer_ID, 0)
        CROSS JOIN (SELECT customer_key FROM gold.dim_customer WHERE customer_id = 0) dc_unknown
        LEFT JOIN gold.dim_product dp
            ON dp.product_id = ISNULL(oi.Product_ID, 0)
        CROSS JOIN (SELECT product_key FROM gold.dim_product WHERE product_id = 0) dp_unknown
        LEFT JOIN gold.dim_warehouse dw
            ON dw.warehouse_id = ISNULL(oo.Warehouse_ID, 0)
        CROSS JOIN (SELECT warehouse_key FROM gold.dim_warehouse WHERE warehouse_id = 0) dw_unknown
        LEFT JOIN gold.dim_promotion dpr
            ON dpr.promotion_id = ISNULL(oi.Promotion_ID, 0)
        CROSS JOIN (SELECT promotion_key FROM gold.dim_promotion WHERE promotion_id = 0) dpr_none
        LEFT JOIN gold.dim_order_status dos
            ON dos.status_name = ISNULL(oo.Order_Status, 'Unknown')
        CROSS JOIN (SELECT order_status_key FROM gold.dim_order_status WHERE status_name = 'Unknown') dos_unknown
        LEFT JOIN (
            SELECT Order_ID, MIN(Payment_Method) AS Payment_Method
            FROM silver.payments
            GROUP BY Order_ID
        ) pay
            ON pay.Order_ID = oi.Order_ID
        LEFT JOIN gold.dim_payment_method dpm
            ON dpm.payment_method_name = ISNULL(pay.Payment_Method, 'Unknown')
        CROSS JOIN (SELECT payment_method_key FROM gold.dim_payment_method WHERE payment_method_name = 'Unknown') dpm_unknown;

        PRINT 'Loaded gold.fact_online_sales rows: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

        COMMIT TRANSACTION;

        PRINT '======================================================';
        PRINT 'Gold Layer Load Completed Successfully';
        PRINT 'End Time: ' + CAST(GETDATE() AS NVARCHAR(50));
        PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @start_time, GETDATE()) AS NVARCHAR(20)) + 's';
        PRINT '======================================================';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        PRINT '!! Gold Layer Load Failed';
        PRINT '!! ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

PRINT 'Procedure gold.load_gold created successfully.';
PRINT 'Run: EXEC gold.load_gold;';
