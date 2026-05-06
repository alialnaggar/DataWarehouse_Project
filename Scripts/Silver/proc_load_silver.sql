/*
===============================================================================
Stored Procedure: proc_load_silver.sql
Purpose:  Reads from Bronze, applies all transformations, and writes to Silver.
          Logs every table load into silver.load_log.

Transformations applied per table:
  - NULL handling
  - Whitespace trimming
  - Data type casting
  - Value standardization (Gender, Status, Loyalty)
  - Derived columns (Full_Name, Tenure_Years, Sales_Amount, etc.)
  - Deduplication (ROW_NUMBER on business keys)
  - Enrichment (Brand_Name, Department_Name joined into Products)

Run order: After ddl_silver.sql
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @start_time     DATETIME,
        @end_time       DATETIME,
        @rows           INT,
        @table_name     NVARCHAR(200),
        @proc_name      NVARCHAR(200) = 'silver.load_silver';

    PRINT '======================================================';
    PRINT 'Starting Silver Layer Load';
    PRINT 'Procedure : silver.load_silver';
    PRINT 'Start Time: ' + CAST(GETDATE() AS NVARCHAR(50));
    PRINT '======================================================';

    BEGIN TRY

        -- ============================================================
        -- BRANDS  (no joins needed — transform only)
        -- ============================================================
        SET @table_name = 'silver.brands';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.brands;

        INSERT INTO silver.brands (Brand_ID, Brand_Name)
        SELECT
            Brand_ID,
            TRIM(Brand_Name)
        FROM (
            SELECT
                Brand_ID,
                Brand_Name,
                ROW_NUMBER() OVER (PARTITION BY Brand_ID ORDER BY Brand_ID) AS rn
            FROM bronze.ret_brands
            WHERE Brand_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DEPARTMENTS
        -- ============================================================
        SET @table_name = 'silver.departments';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.departments;

        INSERT INTO silver.departments (Department_ID, Department_Name)
        SELECT
            Department_ID,
            TRIM(Department_Name)
        FROM (
            SELECT
                Department_ID,
                Department_Name,
                ROW_NUMBER() OVER (PARTITION BY Department_ID ORDER BY Department_ID) AS rn
            FROM bronze.ret_departments
            WHERE Department_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- CUSTOMERS
        -- Transformations:
        --   - TRIM all string columns
        --   - Standardize Gender: keep 'Male'/'Female', else 'Unknown'
        --   - Standardize Loyalty_Level capitalization
        --   - Derived Full_Name
        --   - Deduplicate on Customer_ID (keep latest)
        -- ============================================================
        SET @table_name = 'silver.customers';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.customers;

        INSERT INTO silver.customers
        (Customer_ID, First_Name, Last_Name, Full_Name, Gender, City, Loyalty_Level, Email)
        SELECT
            Customer_ID,
            TRIM(First_Name),
            TRIM(Last_Name),
            TRIM(First_Name) + ' ' + TRIM(Last_Name)               AS Full_Name,
            CASE
                WHEN UPPER(TRIM(Gender)) IN ('MALE','M')   THEN 'Male'
                WHEN UPPER(TRIM(Gender)) IN ('FEMALE','F') THEN 'Female'
                ELSE 'Unknown'
            END                                                     AS Gender,
            TRIM(City),
            CASE
                WHEN UPPER(TRIM(Loyalty_Level)) = 'BRONZE'   THEN 'Bronze'
                WHEN UPPER(TRIM(Loyalty_Level)) = 'SILVER'   THEN 'Silver'
                WHEN UPPER(TRIM(Loyalty_Level)) = 'GOLD'     THEN 'Gold'
                WHEN UPPER(TRIM(Loyalty_Level)) = 'PLATINUM' THEN 'Platinum'
                ELSE 'Bronze'   -- default tier for unknowns
            END                                                     AS Loyalty_Level,
            TRIM(Email)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Customer_ID) AS rn
            FROM bronze.ret_customers
            WHERE Customer_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- EMPLOYEES
        -- Transformations:
        --   - TRIM Name, Position
        --   - Standardize Gender
        --   - TRY_CAST Hire_Date
        --   - Derived Tenure_Years
        -- ============================================================
        SET @table_name = 'silver.employees';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.employees;

        INSERT INTO silver.employees
        (Employee_ID, Name, Gender, Position, Store_ID, Hire_Date, Tenure_Years)
        SELECT
            Employee_ID,
            TRIM(Name),
            CASE
                WHEN UPPER(TRIM(Gender)) IN ('MALE','M')   THEN 'Male'
                WHEN UPPER(TRIM(Gender)) IN ('FEMALE','F') THEN 'Female'
                ELSE 'Unknown'
            END,
            TRIM(Position),
            Store_ID,
            TRY_CAST(Hire_Date AS DATE),
            DATEDIFF(YEAR, TRY_CAST(Hire_Date AS DATE), GETDATE())
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Employee_ID ORDER BY Employee_ID) AS rn
            FROM bronze.ret_employees
            WHERE Employee_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- STORES
        -- ============================================================
        SET @table_name = 'silver.stores';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.stores;

        INSERT INTO silver.stores
        (Store_ID, Store_Name, City, State, Region, Opening_Date)
        SELECT
            Store_ID,
            TRIM(Store_Name),
            TRIM(City),
            TRIM(State),
            TRIM(Region),
            TRY_CAST(Opening_Date AS DATE)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Store_ID ORDER BY Store_ID) AS rn
            FROM bronze.ret_stores
            WHERE Store_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- REGISTERS
        -- ============================================================
        SET @table_name = 'silver.registers';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.registers;

        INSERT INTO silver.registers (Register_ID, Store_ID, Register_Number)
        SELECT
            Register_ID,
            Store_ID,
            Register_Number
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Register_ID ORDER BY Register_ID) AS rn
            FROM bronze.ret_registers
            WHERE Register_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- PRODUCTS  (enriched with Brand_Name + Department_Name)
        -- ============================================================
        SET @table_name = 'silver.products';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.products;

        INSERT INTO silver.products
        (Product_ID, SKU, Product_Name, Brand_ID, Brand_Name, Department_ID, Department_Name, Package_Size)
        SELECT
            p.Product_ID,
            TRIM(p.SKU),
            TRIM(p.Product_Name),
            p.Brand_ID,
            ISNULL(b.Brand_Name, 'Unknown'),
            p.Department_ID,
            ISNULL(d.Department_Name, 'Unknown'),
            ISNULL(TRIM(p.Package_Size), 'N/A')
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Product_ID ORDER BY Product_ID) AS rn
            FROM bronze.ret_products
            WHERE Product_ID IS NOT NULL
        ) p
        LEFT JOIN silver.brands       b ON p.Brand_ID      = b.Brand_ID
        LEFT JOIN silver.departments  d ON p.Department_ID = d.Department_ID
        WHERE p.rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- PROMOTIONS
        -- ============================================================
        SET @table_name = 'silver.promotions';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.promotions;

        INSERT INTO silver.promotions
        (Promotion_ID, Promo_Type, Discount_Percent, Start_Date, End_Date, Promo_Duration_Days)
        SELECT
            Promotion_ID,
            TRIM(Promo_Type),
            ISNULL(Discount_Percent, 0),
            TRY_CAST(Start_Date AS DATE),
            TRY_CAST(End_Date   AS DATE),
            DATEDIFF(DAY, TRY_CAST(Start_Date AS DATE), TRY_CAST(End_Date AS DATE))
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Promotion_ID ORDER BY Promotion_ID) AS rn
            FROM bronze.ret_promotions
            WHERE Promotion_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- WAREHOUSES
        -- ============================================================
        SET @table_name = 'silver.warehouses';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.warehouses;

        INSERT INTO silver.warehouses (Warehouse_ID, Warehouse_Name, City, State)
        SELECT
            Warehouse_ID,
            TRIM(Warehouse_Name),
            TRIM(City),
            TRIM(State)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Warehouse_ID ORDER BY Warehouse_ID) AS rn
            FROM bronze.ret_warehouses
            WHERE Warehouse_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- SUPPLIERS
        -- ============================================================
        SET @table_name = 'silver.suppliers';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.suppliers;

        INSERT INTO silver.suppliers (Supplier_ID, Supplier_Name, Country, Phone)
        SELECT
            Supplier_ID,
            TRIM(Supplier_Name),
            TRIM(Country),
            TRIM(Phone)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Supplier_ID ORDER BY Supplier_ID) AS rn
            FROM bronze.ret_suppliers
            WHERE Supplier_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- PRODUCT_SUPPLIERS
        -- ============================================================
        SET @table_name = 'silver.product_suppliers';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.product_suppliers;

        INSERT INTO silver.product_suppliers (Product_ID, Supplier_ID, Supply_Price)
        SELECT
            Product_ID,
            Supplier_ID,
            ISNULL(Supply_Price, 0)
        FROM bronze.ret_product_suppliers
        WHERE Product_ID IS NOT NULL
          AND Supplier_ID IS NOT NULL
          AND Supply_Price > 0;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DELIVERY_PROVIDERS
        -- ============================================================
        SET @table_name = 'silver.delivery_providers';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.delivery_providers;

        INSERT INTO silver.delivery_providers (Provider_ID, Provider_Name, Phone)
        SELECT
            Provider_ID,
            TRIM(Provider_Name),
            TRIM(Phone)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Provider_ID ORDER BY Provider_ID) AS rn
            FROM bronze.ret_delivery_providers
            WHERE Provider_ID IS NOT NULL
        ) deduped
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- POS_TRANSACTIONS
        -- ============================================================
        SET @table_name = 'silver.pos_transactions';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.pos_transactions;

        INSERT INTO silver.pos_transactions
        (Transaction_ID, Store_ID, Register_ID, Employee_ID, Customer_ID, Transaction_Time, Transaction_Date)
        SELECT
            TRIM(Transaction_ID),
            Store_ID,
            Register_ID,
            Employee_ID,
            Customer_ID,
            TRY_CAST(Transaction_Time AS DATETIME),
            TRY_CAST(TRY_CAST(Transaction_Time AS DATETIME) AS DATE)
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Transaction_ID ORDER BY Transaction_ID) AS rn
            FROM bronze.ret_pos_transactions
            WHERE Transaction_ID IS NOT NULL
        ) deduped
        WHERE rn = 1
          AND TRY_CAST(Transaction_Time AS DATETIME) IS NOT NULL;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- TRANSACTION_ITEMS
        -- Derived: Sales_Amount, Discount_Percent (from promotions),
        --          Discount_Amount, Net_Sales_Amount
        -- ============================================================
        SET @table_name = 'silver.transaction_items';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.transaction_items;

        INSERT INTO silver.transaction_items
        (Line_ID, Transaction_ID, Product_ID, Promotion_ID, Quantity, Unit_Price,
         Sales_Amount, Discount_Percent, Discount_Amount, Net_Sales_Amount)
        SELECT
            ti.Line_ID,
            TRIM(ti.Transaction_ID),
            ti.Product_ID,
            ISNULL(ti.Promotion_ID, 0)                                          AS Promotion_ID,
            ti.Quantity,
            ti.Unit_Price,
            ti.Quantity * ti.Unit_Price                                         AS Sales_Amount,
            ISNULL(p.Discount_Percent, 0)                                       AS Discount_Percent,
            (ti.Quantity * ti.Unit_Price) * ISNULL(p.Discount_Percent,0) / 100  AS Discount_Amount,
            (ti.Quantity * ti.Unit_Price)
              - (ti.Quantity * ti.Unit_Price) * ISNULL(p.Discount_Percent,0) / 100
                                                                                AS Net_Sales_Amount
        FROM bronze.ret_transaction_items ti
        LEFT JOIN silver.promotions p ON ti.Promotion_ID = p.Promotion_ID
        WHERE ti.Line_ID      IS NOT NULL
          AND ti.Quantity     > 0
          AND ti.Unit_Price   > 0;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- ONLINE_ORDERS
        -- ============================================================
        SET @table_name = 'silver.online_orders';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.online_orders;

        INSERT INTO silver.online_orders
        (Order_ID, Customer_ID, Warehouse_ID, Order_Time, Order_Date, Order_Status, Order_Total)
        SELECT
            Order_ID,
            Customer_ID,
            Warehouse_ID,
            TRY_CAST(Order_Time AS DATETIME),
            TRY_CAST(TRY_CAST(Order_Time AS DATETIME) AS DATE),
            CASE
                WHEN UPPER(TRIM(Order_Status)) = 'DELIVERED'  THEN 'Delivered'
                WHEN UPPER(TRIM(Order_Status)) = 'PENDING'    THEN 'Pending'
                WHEN UPPER(TRIM(Order_Status)) = 'CANCELLED'  THEN 'Cancelled'
                WHEN UPPER(TRIM(Order_Status)) = 'CANCELED'   THEN 'Cancelled'
                WHEN UPPER(TRIM(Order_Status)) = 'SHIPPED'    THEN 'Shipped'
                ELSE TRIM(Order_Status)
            END,
            ISNULL(Order_Total, 0)      -- NULL values defaulted to 0
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_ID) AS rn
            FROM bronze.ret_online_orders
            WHERE Order_ID IS NOT NULL
        ) deduped
        WHERE rn = 1
          AND TRY_CAST(Order_Time AS DATETIME) IS NOT NULL;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- ONLINE_ORDER_ITEMS
        -- ============================================================
        SET @table_name = 'silver.online_order_items';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.online_order_items;

        INSERT INTO silver.online_order_items
        (Order_Item_ID, Order_ID, Product_ID, Promotion_ID, Quantity, Unit_Price,
         Sales_Amount, Discount_Percent, Discount_Amount, Net_Sales_Amount)
        SELECT
            oi.Order_Item_ID,
            oi.Order_ID,
            oi.Product_ID,
            ISNULL(oi.Promotion_ID, 0),
            oi.Quantity,
            oi.Unit_Price,
            oi.Quantity * oi.Unit_Price,
            ISNULL(p.Discount_Percent, 0),
            (oi.Quantity * oi.Unit_Price) * ISNULL(p.Discount_Percent,0) / 100,
            (oi.Quantity * oi.Unit_Price)
              - (oi.Quantity * oi.Unit_Price) * ISNULL(p.Discount_Percent,0) / 100
        FROM bronze.ret_online_order_items oi
        LEFT JOIN silver.promotions p ON oi.Promotion_ID = p.Promotion_ID
        WHERE oi.Order_Item_ID IS NOT NULL
          AND oi.Quantity      > 0
          AND oi.Unit_Price    > 0;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- INVENTORY
        -- ============================================================
        SET @table_name = 'silver.inventory';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.inventory;

        INSERT INTO silver.inventory
        (Inventory_ID, Store_ID, Product_ID, Stock_Level, Last_Updated, Reorder_Flag)
        SELECT
            Inventory_ID,
            Store_ID,
            Product_ID,
            ISNULL(Stock_Level, 0),
            TRY_CAST(Last_Updated AS DATETIME),
            CASE WHEN ISNULL(Stock_Level, 0) < 50 THEN 1 ELSE 0 END
        FROM bronze.ret_inventory
        WHERE Inventory_ID IS NOT NULL
          AND Store_ID     IS NOT NULL
          AND Product_ID   IS NOT NULL;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DELIVERIES
        -- Derived: Days_to_Ship, Days_to_Deliver, Total_Delivery_Days,
        --          On_Time_Flag (SLA = 7 days)
        -- Requires join to silver.online_orders for Order_Time
        -- ============================================================
        SET @table_name = 'silver.deliveries';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.deliveries;

        INSERT INTO silver.deliveries
        (Delivery_ID, Order_ID, Provider_ID, Ship_Date, Delivery_Date, Delivery_Status,
         Days_to_Ship, Days_to_Deliver, Total_Delivery_Days, On_Time_Flag)
        SELECT
            d.Delivery_ID,
            d.Order_ID,
            d.Provider_ID,
            TRY_CAST(d.Ship_Date     AS DATETIME),
            TRY_CAST(d.Delivery_Date AS DATETIME),
            CASE
                WHEN UPPER(TRIM(d.Delivery_Status)) = 'DELIVERED'  THEN 'Delivered'
                WHEN UPPER(TRIM(d.Delivery_Status)) = 'PENDING'    THEN 'Pending'
                WHEN UPPER(TRIM(d.Delivery_Status)) = 'FAILED'     THEN 'Failed'
                ELSE TRIM(d.Delivery_Status)
            END,
            DATEDIFF(DAY, o.Order_Time, TRY_CAST(d.Ship_Date AS DATETIME)),
            DATEDIFF(DAY, TRY_CAST(d.Ship_Date AS DATETIME), TRY_CAST(d.Delivery_Date AS DATETIME)),
            DATEDIFF(DAY, o.Order_Time, TRY_CAST(d.Delivery_Date AS DATETIME)),
            CASE
                WHEN DATEDIFF(DAY, o.Order_Time, TRY_CAST(d.Delivery_Date AS DATETIME)) <= 7
                THEN 1 ELSE 0
            END
        FROM bronze.ret_deliveries d
        LEFT JOIN silver.online_orders o ON d.Order_ID = o.Order_ID
        WHERE d.Delivery_ID IS NOT NULL;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- PAYMENTS
        -- ============================================================
        SET @table_name = 'silver.payments';
        SET @start_time = GETDATE();
        PRINT '>> Loading: ' + @table_name;
        TRUNCATE TABLE silver.payments;

        INSERT INTO silver.payments
        (Payment_ID, Order_ID, Payment_Method, Payment_Amount, Payment_Time)
        SELECT
            Payment_ID,
            Order_ID,
            TRIM(Payment_Method),
            Payment_Amount,
            TRY_CAST(Payment_Time AS DATETIME)
        FROM bronze.ret_payments
        WHERE Payment_ID     IS NOT NULL
          AND Payment_Amount > 0;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        PRINT '>> Rows: ' + CAST(@rows AS NVARCHAR) + ' | Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 's';
        INSERT INTO silver.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        PRINT '======================================================';
        PRINT 'Silver Layer Load Completed Successfully';
        PRINT 'End Time: ' + CAST(GETDATE() AS NVARCHAR(50));
        PRINT '======================================================';

    END TRY

    BEGIN CATCH
        PRINT '!! ERROR ON TABLE: ' + ISNULL(@table_name,'UNKNOWN');
        PRINT '!! ' + ERROR_MESSAGE();

        INSERT INTO silver.load_log
        VALUES (
            @proc_name,
            @table_name,
            @start_time,
            GETDATE(),
            NULL, NULL,
            'FAILED',
            ERROR_MESSAGE()
        );
    END CATCH
END;
GO

PRINT 'Procedure silver.load_silver created successfully.';
PRINT 'Run: EXEC silver.load_silver';
