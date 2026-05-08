/*
===============================================================================
Stored Procedure: proc_load_gold.sql
Purpose:  Refreshes the Gold layer dimensional model from Silver tables.

Gold model:
  - Store Sales star schema at POS transaction line grain.
  - Online Sales star schema at online order item grain.
  - Conformed dim_date, dim_customer, dim_product, and dim_promotion.
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @start_time     DATETIME,
        @end_time       DATETIME,
        @rows           INT,
        @table_name     NVARCHAR(200),
        @proc_name      NVARCHAR(200) = 'gold.load_gold';

    PRINT '======================================================';
    PRINT 'Starting Gold Layer Load';
    PRINT 'Procedure : gold.load_gold';
    PRINT 'Start Time: ' + CAST(GETDATE() AS NVARCHAR(50));
    PRINT '======================================================';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Delete facts before dimensions because facts enforce FK consistency.
        DELETE FROM gold.fact_online_sales;
        DELETE FROM gold.fact_store_sales;

        DELETE FROM gold.dim_warehouse;
        DELETE FROM gold.dim_employee;
        DELETE FROM gold.dim_register;
        DELETE FROM gold.dim_store;
        DELETE FROM gold.dim_promotion;
        DELETE FROM gold.dim_product;
        DELETE FROM gold.dim_customer;
        DELETE FROM gold.dim_date;

        DBCC CHECKIDENT ('gold.dim_warehouse', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_employee',  RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_register',  RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_store',     RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_promotion', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_product',   RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.dim_customer',  RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.fact_online_sales', RESEED, 0) WITH NO_INFOMSGS;
        DBCC CHECKIDENT ('gold.fact_store_sales',  RESEED, 0) WITH NO_INFOMSGS;

        -- ============================================================
        -- DIM_DATE
        -- ============================================================
        SET @table_name = 'gold.dim_date';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_date
        (Date_Key, Full_Date, Day_Number_Of_Week, Day_Name, Day_Number_Of_Month,
         Day_Number_Of_Year, Week_Number_Of_Year, Month_Number, Month_Name,
         Quarter_Number, Year_Number, Is_Weekend)
        SELECT
            CONVERT(INT, CONVERT(CHAR(8), d.Full_Date, 112)) AS Date_Key,
            d.Full_Date,
            DATEPART(WEEKDAY, d.Full_Date),
            DATENAME(WEEKDAY, d.Full_Date),
            DATEPART(DAY, d.Full_Date),
            DATEPART(DAYOFYEAR, d.Full_Date),
            DATEPART(WEEK, d.Full_Date),
            DATEPART(MONTH, d.Full_Date),
            DATENAME(MONTH, d.Full_Date),
            DATEPART(QUARTER, d.Full_Date),
            DATEPART(YEAR, d.Full_Date),
            CASE WHEN DATENAME(WEEKDAY, d.Full_Date) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
        FROM (
            SELECT DISTINCT Transaction_Date AS Full_Date
            FROM silver.pos_transactions
            WHERE Transaction_Date IS NOT NULL
            UNION
            SELECT DISTINCT Order_Date AS Full_Date
            FROM silver.online_orders
            WHERE Order_Date IS NOT NULL
        ) d;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_CUSTOMER
        -- ============================================================
        SET @table_name = 'gold.dim_customer';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_customer
        (Customer_ID, First_Name, Last_Name, Full_Name, Gender, City, Loyalty_Level, Email)
        SELECT Customer_ID, First_Name, Last_Name, Full_Name, Gender, City, Loyalty_Level, Email
        FROM silver.customers;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_PRODUCT
        -- ============================================================
        SET @table_name = 'gold.dim_product';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_product
        (Product_ID, SKU, Product_Name, Brand_ID, Brand_Name, Department_ID, Department_Name, Package_Size)
        SELECT Product_ID, SKU, Product_Name, Brand_ID, Brand_Name, Department_ID, Department_Name, Package_Size
        FROM silver.products;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_PROMOTION
        -- ============================================================
        SET @table_name = 'gold.dim_promotion';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_promotion
        (Promotion_ID, Promo_Type, Discount_Percent, Start_Date, End_Date, Promo_Duration_Days)
        VALUES (0, 'No Promotion', 0, NULL, NULL, 0);

        INSERT INTO gold.dim_promotion
        (Promotion_ID, Promo_Type, Discount_Percent, Start_Date, End_Date, Promo_Duration_Days)
        SELECT Promotion_ID, Promo_Type, Discount_Percent, Start_Date, End_Date, Promo_Duration_Days
        FROM silver.promotions;

        SET @rows = @@ROWCOUNT + 1; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_STORE
        -- ============================================================
        SET @table_name = 'gold.dim_store';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_store
        (Store_ID, Store_Name, City, State, Region, Opening_Date)
        SELECT Store_ID, Store_Name, City, State, Region, Opening_Date
        FROM silver.stores;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_REGISTER
        -- ============================================================
        SET @table_name = 'gold.dim_register';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_register
        (Register_ID, Store_ID, Register_Number)
        SELECT Register_ID, Store_ID, Register_Number
        FROM silver.registers;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_EMPLOYEE
        -- ============================================================
        SET @table_name = 'gold.dim_employee';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_employee
        (Employee_ID, Employee_Name, Gender, Position, Store_ID, Hire_Date, Tenure_Years)
        SELECT Employee_ID, Name, Gender, Position, Store_ID, Hire_Date, Tenure_Years
        FROM silver.employees;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- DIM_WAREHOUSE
        -- ============================================================
        SET @table_name = 'gold.dim_warehouse';
        SET @start_time = GETDATE();

        INSERT INTO gold.dim_warehouse
        (Warehouse_ID, Warehouse_Name, City, State)
        SELECT Warehouse_ID, Warehouse_Name, City, State
        FROM silver.warehouses;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- FACT_STORE_SALES
        -- ============================================================
        SET @table_name = 'gold.fact_store_sales';
        SET @start_time = GETDATE();

        INSERT INTO gold.fact_store_sales
        (Date_Key, Customer_Key, Product_Key, Store_Key, Register_Key, Employee_Key,
         Promotion_Key, Transaction_Number, Transaction_Line_No, Quantity, Unit_Price,
         Gross_Sales_Amount, Discount_Amount, Net_Sales_Amount)
        SELECT
            dd.Date_Key,
            dc.Customer_Key,
            dp.Product_Key,
            ds.Store_Key,
            dr.Register_Key,
            de.Employee_Key,
            dpr.Promotion_Key,
            ti.Transaction_ID,
            ti.Line_ID,
            ti.Quantity,
            ti.Unit_Price,
            ti.Sales_Amount,
            ISNULL(ti.Discount_Amount, 0),
            ISNULL(ti.Net_Sales_Amount, ti.Sales_Amount)
        FROM silver.transaction_items ti
        INNER JOIN silver.pos_transactions pt
            ON ti.Transaction_ID = pt.Transaction_ID
        INNER JOIN gold.dim_date dd
            ON CONVERT(INT, CONVERT(CHAR(8), pt.Transaction_Date, 112)) = dd.Date_Key
        INNER JOIN gold.dim_customer dc
            ON pt.Customer_ID = dc.Customer_ID
        INNER JOIN gold.dim_product dp
            ON ti.Product_ID = dp.Product_ID
        INNER JOIN gold.dim_store ds
            ON pt.Store_ID = ds.Store_ID
        INNER JOIN gold.dim_register dr
            ON pt.Register_ID = dr.Register_ID
        INNER JOIN gold.dim_employee de
            ON pt.Employee_ID = de.Employee_ID
        INNER JOIN gold.dim_promotion dpr
            ON ti.Promotion_ID = dpr.Promotion_ID;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        -- ============================================================
        -- FACT_ONLINE_SALES
        -- ============================================================
        SET @table_name = 'gold.fact_online_sales';
        SET @start_time = GETDATE();

        INSERT INTO gold.fact_online_sales
        (Date_Key, Customer_Key, Product_Key, Warehouse_Key, Promotion_Key,
         Order_Number, Order_Item_Number, Order_Status, Quantity, Unit_Price,
         Gross_Sales_Amount, Discount_Amount, Net_Sales_Amount)
        SELECT
            dd.Date_Key,
            dc.Customer_Key,
            dp.Product_Key,
            dw.Warehouse_Key,
            dpr.Promotion_Key,
            oi.Order_ID,
            oi.Order_Item_ID,
            oo.Order_Status,
            oi.Quantity,
            oi.Unit_Price,
            oi.Sales_Amount,
            ISNULL(oi.Discount_Amount, 0),
            ISNULL(oi.Net_Sales_Amount, oi.Sales_Amount)
        FROM silver.online_order_items oi
        INNER JOIN silver.online_orders oo
            ON oi.Order_ID = oo.Order_ID
        INNER JOIN gold.dim_date dd
            ON CONVERT(INT, CONVERT(CHAR(8), oo.Order_Date, 112)) = dd.Date_Key
        INNER JOIN gold.dim_customer dc
            ON oo.Customer_ID = dc.Customer_ID
        INNER JOIN gold.dim_product dp
            ON oi.Product_ID = dp.Product_ID
        INNER JOIN gold.dim_warehouse dw
            ON oo.Warehouse_ID = dw.Warehouse_ID
        INNER JOIN gold.dim_promotion dpr
            ON oi.Promotion_ID = dpr.Promotion_ID;

        SET @rows = @@ROWCOUNT; SET @end_time = GETDATE();
        INSERT INTO gold.load_log VALUES (@proc_name,@table_name,@start_time,@end_time,DATEDIFF(SECOND,@start_time,@end_time),@rows,'SUCCESS',NULL);

        COMMIT TRANSACTION;

        PRINT '======================================================';
        PRINT 'Gold Layer Load Completed Successfully';
        PRINT 'End Time: ' + CAST(GETDATE() AS NVARCHAR(50));
        PRINT '======================================================';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '!! ERROR ON TABLE: ' + ISNULL(@table_name,'UNKNOWN');
        PRINT '!! ' + ERROR_MESSAGE();

        INSERT INTO gold.load_log
        VALUES (
            @proc_name,
            @table_name,
            @start_time,
            GETDATE(),
            NULL,
            NULL,
            'FAILED',
            ERROR_MESSAGE()
        );
    END CATCH
END;
GO

PRINT 'Procedure gold.load_gold created successfully.';
PRINT 'Run: EXEC gold.load_gold';
