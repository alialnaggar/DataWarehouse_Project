/*
===============================================================================
DDL Script: ddl_gold.sql
Purpose:    Creates the Gold layer dimensional model.

Business process 1: Store Sales Performance
Grain: one row per product line item on a POS transaction.

Business process 2: Online Sales Performance
Grain: one row per product line item on an online order.

Conformed dimensions: dim_date, dim_customer, dim_product, dim_promotion.
===============================================================================
*/

USE DataWarehouse;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- ============================================================
-- DROP EXISTING GOLD TABLES
-- ============================================================
IF OBJECT_ID('gold.fact_online_sales', 'U') IS NOT NULL DROP TABLE gold.fact_online_sales;
IF OBJECT_ID('gold.fact_store_sales',  'U') IS NOT NULL DROP TABLE gold.fact_store_sales;

IF OBJECT_ID('gold.dim_warehouse',     'U') IS NOT NULL DROP TABLE gold.dim_warehouse;
IF OBJECT_ID('gold.dim_employee',      'U') IS NOT NULL DROP TABLE gold.dim_employee;
IF OBJECT_ID('gold.dim_register',      'U') IS NOT NULL DROP TABLE gold.dim_register;
IF OBJECT_ID('gold.dim_store',         'U') IS NOT NULL DROP TABLE gold.dim_store;
IF OBJECT_ID('gold.dim_promotion',     'U') IS NOT NULL DROP TABLE gold.dim_promotion;
IF OBJECT_ID('gold.dim_product',       'U') IS NOT NULL DROP TABLE gold.dim_product;
IF OBJECT_ID('gold.dim_customer',      'U') IS NOT NULL DROP TABLE gold.dim_customer;
IF OBJECT_ID('gold.dim_date',          'U') IS NOT NULL DROP TABLE gold.dim_date;
IF OBJECT_ID('gold.load_log',          'U') IS NOT NULL DROP TABLE gold.load_log;
GO

-- ============================================================
-- CONFORMED DIMENSIONS
-- ============================================================
CREATE TABLE gold.dim_date (
    Date_Key              INT           NOT NULL PRIMARY KEY, -- YYYYMMDD
    Full_Date             DATE          NOT NULL UNIQUE,
    Day_Number_Of_Week    TINYINT       NOT NULL,
    Day_Name              NVARCHAR(20)  NOT NULL,
    Day_Number_Of_Month   TINYINT       NOT NULL,
    Day_Number_Of_Year    SMALLINT      NOT NULL,
    Week_Number_Of_Year   TINYINT       NOT NULL,
    Month_Number          TINYINT       NOT NULL,
    Month_Name            NVARCHAR(20)  NOT NULL,
    Quarter_Number        TINYINT       NOT NULL,
    Year_Number           SMALLINT      NOT NULL,
    Is_Weekend            BIT           NOT NULL
);

CREATE TABLE gold.dim_customer (
    Customer_Key      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Customer_ID       INT               NOT NULL UNIQUE,
    First_Name        NVARCHAR(100)     NOT NULL,
    Last_Name         NVARCHAR(100)     NOT NULL,
    Full_Name         NVARCHAR(200)     NOT NULL,
    Gender            NVARCHAR(10)      NOT NULL,
    City              NVARCHAR(100),
    Loyalty_Level     NVARCHAR(20),
    Email             NVARCHAR(200)
);

CREATE TABLE gold.dim_product (
    Product_Key       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Product_ID        INT               NOT NULL UNIQUE,
    SKU               NVARCHAR(50)      NOT NULL,
    Product_Name      NVARCHAR(200)     NOT NULL,
    Brand_ID          INT,
    Brand_Name        NVARCHAR(100),
    Department_ID     INT,
    Department_Name   NVARCHAR(100),
    Package_Size      NVARCHAR(100)
);

CREATE TABLE gold.dim_promotion (
    Promotion_Key          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Promotion_ID           INT               NOT NULL UNIQUE,
    Promo_Type             NVARCHAR(100)     NOT NULL,
    Discount_Percent       DECIMAL(5,2)      NOT NULL,
    Start_Date             DATE,
    End_Date               DATE,
    Promo_Duration_Days    INT
);

-- ============================================================
-- STORE SALES DIMENSIONS
-- ============================================================
CREATE TABLE gold.dim_store (
    Store_Key       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Store_ID        INT               NOT NULL UNIQUE,
    Store_Name      NVARCHAR(150)     NOT NULL,
    City            NVARCHAR(100),
    State           NVARCHAR(50),
    Region          NVARCHAR(100),
    Opening_Date    DATE
);

CREATE TABLE gold.dim_register (
    Register_Key      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Register_ID       INT               NOT NULL UNIQUE,
    Store_ID          INT               NOT NULL,
    Register_Number   INT
);

CREATE TABLE gold.dim_employee (
    Employee_Key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Employee_ID     INT               NOT NULL UNIQUE,
    Employee_Name   NVARCHAR(150)     NOT NULL,
    Gender          NVARCHAR(10)      NOT NULL,
    Position        NVARCHAR(100),
    Store_ID        INT,
    Hire_Date       DATE,
    Tenure_Years    INT
);

-- ============================================================
-- ONLINE SALES DIMENSIONS
-- ============================================================
CREATE TABLE gold.dim_warehouse (
    Warehouse_Key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Warehouse_ID      INT               NOT NULL UNIQUE,
    Warehouse_Name    NVARCHAR(150)     NOT NULL,
    City              NVARCHAR(100),
    State             NVARCHAR(50)
);

-- ============================================================
-- FACT TABLES
-- ============================================================
CREATE TABLE gold.fact_store_sales (
    Store_Sales_SK        BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Date_Key              INT                  NOT NULL,
    Customer_Key          INT                  NOT NULL,
    Product_Key           INT                  NOT NULL,
    Store_Key             INT                  NOT NULL,
    Register_Key          INT                  NOT NULL,
    Employee_Key          INT                  NOT NULL,
    Promotion_Key         INT                  NOT NULL,
    Transaction_Number    NVARCHAR(50)         NOT NULL,
    Transaction_Line_No   INT                  NOT NULL,
    Quantity              INT                  NOT NULL,
    Unit_Price            DECIMAL(10,2)        NOT NULL,
    Gross_Sales_Amount    DECIMAL(12,2)        NOT NULL,
    Discount_Amount       DECIMAL(12,2)        NOT NULL,
    Net_Sales_Amount      DECIMAL(12,2)        NOT NULL,

    CONSTRAINT UQ_fact_store_sales_grain UNIQUE (Transaction_Number, Transaction_Line_No),
    CONSTRAINT FK_fact_store_sales_date
        FOREIGN KEY (Date_Key) REFERENCES gold.dim_date(Date_Key),
    CONSTRAINT FK_fact_store_sales_customer
        FOREIGN KEY (Customer_Key) REFERENCES gold.dim_customer(Customer_Key),
    CONSTRAINT FK_fact_store_sales_product
        FOREIGN KEY (Product_Key) REFERENCES gold.dim_product(Product_Key),
    CONSTRAINT FK_fact_store_sales_store
        FOREIGN KEY (Store_Key) REFERENCES gold.dim_store(Store_Key),
    CONSTRAINT FK_fact_store_sales_register
        FOREIGN KEY (Register_Key) REFERENCES gold.dim_register(Register_Key),
    CONSTRAINT FK_fact_store_sales_employee
        FOREIGN KEY (Employee_Key) REFERENCES gold.dim_employee(Employee_Key),
    CONSTRAINT FK_fact_store_sales_promotion
        FOREIGN KEY (Promotion_Key) REFERENCES gold.dim_promotion(Promotion_Key)
);

CREATE TABLE gold.fact_online_sales (
    Online_Sales_SK       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Date_Key              INT                  NOT NULL,
    Customer_Key          INT                  NOT NULL,
    Product_Key           INT                  NOT NULL,
    Warehouse_Key         INT                  NOT NULL,
    Promotion_Key         INT                  NOT NULL,
    Order_Number          INT                  NOT NULL,
    Order_Item_Number     INT                  NOT NULL,
    Order_Status          NVARCHAR(50)         NOT NULL,
    Quantity              INT                  NOT NULL,
    Unit_Price            DECIMAL(10,2)        NOT NULL,
    Gross_Sales_Amount    DECIMAL(12,2)        NOT NULL,
    Discount_Amount       DECIMAL(12,2)        NOT NULL,
    Net_Sales_Amount      DECIMAL(12,2)        NOT NULL,

    CONSTRAINT UQ_fact_online_sales_grain UNIQUE (Order_Number, Order_Item_Number),
    CONSTRAINT FK_fact_online_sales_date
        FOREIGN KEY (Date_Key) REFERENCES gold.dim_date(Date_Key),
    CONSTRAINT FK_fact_online_sales_customer
        FOREIGN KEY (Customer_Key) REFERENCES gold.dim_customer(Customer_Key),
    CONSTRAINT FK_fact_online_sales_product
        FOREIGN KEY (Product_Key) REFERENCES gold.dim_product(Product_Key),
    CONSTRAINT FK_fact_online_sales_warehouse
        FOREIGN KEY (Warehouse_Key) REFERENCES gold.dim_warehouse(Warehouse_Key),
    CONSTRAINT FK_fact_online_sales_promotion
        FOREIGN KEY (Promotion_Key) REFERENCES gold.dim_promotion(Promotion_Key)
);

-- ============================================================
-- GOLD LOAD LOG
-- ============================================================
CREATE TABLE gold.load_log (
    log_id              INT IDENTITY(1,1) PRIMARY KEY,
    procedure_name      NVARCHAR(200),
    table_name          NVARCHAR(200),
    load_start_time     DATETIME,
    load_end_time       DATETIME,
    duration_seconds    INT,
    rows_inserted       INT,
    status              NVARCHAR(20),
    error_message       NVARCHAR(MAX)
);
GO

PRINT 'All Gold tables created successfully.';
