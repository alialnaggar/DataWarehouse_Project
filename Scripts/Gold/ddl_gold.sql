/*
===============================================================================
DDL Script: ddl_gold.sql
Purpose:    Creates the Gold dimensional layer as a Galaxy Schema.
            Star 1: Store Sales Performance
            Star 2: Online Sales Performance
Run order:  After silver.load_silver has completed successfully.
===============================================================================
*/

USE DataWarehouse;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

-- ============================================================
-- DROP EXISTING GOLD TABLES
-- Facts first because they hold foreign keys to dimensions.
-- ============================================================
IF OBJECT_ID('gold.fact_online_sales', 'U') IS NOT NULL DROP TABLE gold.fact_online_sales;
IF OBJECT_ID('gold.fact_store_sales',  'U') IS NOT NULL DROP TABLE gold.fact_store_sales;

IF OBJECT_ID('gold.dim_payment_method', 'U') IS NOT NULL DROP TABLE gold.dim_payment_method;
IF OBJECT_ID('gold.dim_order_status',   'U') IS NOT NULL DROP TABLE gold.dim_order_status;
IF OBJECT_ID('gold.dim_warehouse', 'U') IS NOT NULL DROP TABLE gold.dim_warehouse;
IF OBJECT_ID('gold.dim_employee',  'U') IS NOT NULL DROP TABLE gold.dim_employee;
IF OBJECT_ID('gold.dim_store',     'U') IS NOT NULL DROP TABLE gold.dim_store;
IF OBJECT_ID('gold.dim_promotion', 'U') IS NOT NULL DROP TABLE gold.dim_promotion;
IF OBJECT_ID('gold.dim_product',   'U') IS NOT NULL DROP TABLE gold.dim_product;
IF OBJECT_ID('gold.dim_customer',  'U') IS NOT NULL DROP TABLE gold.dim_customer;
IF OBJECT_ID('gold.dim_date',      'U') IS NOT NULL DROP TABLE gold.dim_date;
GO

-- ============================================================
-- CONFORMED DIMENSIONS
-- ============================================================
CREATE TABLE gold.dim_date (
    date_key              INT IDENTITY(1,1) NOT NULL,
    full_date             DATE              NOT NULL,
    day_number            TINYINT           NOT NULL,
    month_number          TINYINT           NOT NULL,
    month_name            NVARCHAR(20)      NOT NULL,
    quarter_number        TINYINT           NOT NULL,
    year_number           SMALLINT          NOT NULL,
    day_of_week_number    TINYINT           NOT NULL,
    day_name              NVARCHAR(20)      NOT NULL,
    is_weekend            BIT               NOT NULL,
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key),
    CONSTRAINT uq_dim_date_full_date UNIQUE (full_date)
);

CREATE TABLE gold.dim_customer (
    customer_key      INT IDENTITY(1,1) NOT NULL,
    customer_id       INT               NOT NULL,
    first_name        NVARCHAR(100)     NOT NULL,
    last_name         NVARCHAR(100)     NOT NULL,
    full_name         NVARCHAR(200)     NOT NULL,
    gender            NVARCHAR(10)      NOT NULL,
    city              NVARCHAR(100)     NULL,
    loyalty_level     NVARCHAR(20)      NULL,
    email             NVARCHAR(200)     NULL,
    CONSTRAINT pk_dim_customer PRIMARY KEY (customer_key),
    CONSTRAINT uq_dim_customer_customer_id UNIQUE (customer_id)
);

CREATE TABLE gold.dim_product (
    product_key       INT IDENTITY(1,1) NOT NULL,
    product_id        INT               NOT NULL,
    sku               NVARCHAR(50)      NOT NULL,
    product_name      NVARCHAR(200)     NOT NULL,
    brand_id          INT               NULL,
    brand_name        NVARCHAR(100)     NULL,
    department_id     INT               NULL,
    department_name   NVARCHAR(100)     NULL,
    package_size      NVARCHAR(100)     NULL,
    CONSTRAINT pk_dim_product PRIMARY KEY (product_key),
    CONSTRAINT uq_dim_product_product_id UNIQUE (product_id)
);

CREATE TABLE gold.dim_promotion (
    promotion_key         INT IDENTITY(1,1) NOT NULL,
    promotion_id          INT               NOT NULL,
    promo_type            NVARCHAR(100)     NOT NULL,
    discount_percent      DECIMAL(5,2)      NOT NULL,
    start_date            DATE              NULL,
    end_date              DATE              NULL,
    promo_duration_days   INT               NULL,
    CONSTRAINT pk_dim_promotion PRIMARY KEY (promotion_key),
    CONSTRAINT uq_dim_promotion_promotion_id UNIQUE (promotion_id)
);

-- ============================================================
-- STAR-SPECIFIC DIMENSIONS
-- ============================================================
CREATE TABLE gold.dim_store (
    store_key       INT IDENTITY(1,1) NOT NULL,
    store_id        INT               NOT NULL,
    store_name      NVARCHAR(150)     NOT NULL,
    city            NVARCHAR(100)     NULL,
    state           NVARCHAR(50)      NULL,
    region          NVARCHAR(100)     NULL,
    opening_date    DATE              NULL,
    CONSTRAINT pk_dim_store PRIMARY KEY (store_key),
    CONSTRAINT uq_dim_store_store_id UNIQUE (store_id)
);

CREATE TABLE gold.dim_employee (
    employee_key    INT IDENTITY(1,1) NOT NULL,
    employee_id     INT               NOT NULL,
    employee_name   NVARCHAR(150)     NOT NULL,
    gender          NVARCHAR(10)      NOT NULL,
    position        NVARCHAR(100)     NULL,
    store_id        INT               NULL,
    hire_date       DATE              NULL,
    tenure_years    INT               NULL,
    CONSTRAINT pk_dim_employee PRIMARY KEY (employee_key),
    CONSTRAINT uq_dim_employee_employee_id UNIQUE (employee_id)
);

CREATE TABLE gold.dim_warehouse (
    warehouse_key     INT IDENTITY(1,1) NOT NULL,
    warehouse_id      INT               NOT NULL,
    warehouse_name    NVARCHAR(150)     NOT NULL,
    city              NVARCHAR(100)     NULL,
    state             NVARCHAR(50)      NULL,
    CONSTRAINT pk_dim_warehouse PRIMARY KEY (warehouse_key),
    CONSTRAINT uq_dim_warehouse_warehouse_id UNIQUE (warehouse_id)
);

CREATE TABLE gold.dim_order_status (
    order_status_key    INT IDENTITY(1,1) NOT NULL,
    status_name         NVARCHAR(50)      NOT NULL,
    status_description  NVARCHAR(200)     NOT NULL,
    CONSTRAINT pk_dim_order_status PRIMARY KEY (order_status_key),
    CONSTRAINT uq_dim_order_status_status_name UNIQUE (status_name)
);

CREATE TABLE gold.dim_payment_method (
    payment_method_key   INT IDENTITY(1,1) NOT NULL,
    payment_method_name  NVARCHAR(100)     NOT NULL,
    payment_provider     NVARCHAR(100)     NOT NULL,
    CONSTRAINT pk_dim_payment_method PRIMARY KEY (payment_method_key),
    CONSTRAINT uq_dim_payment_method_name UNIQUE (payment_method_name)
);

-- ============================================================
-- FACT TABLES
-- ============================================================
CREATE TABLE gold.fact_store_sales (
    fact_store_sales_sk    BIGINT IDENTITY(1,1) NOT NULL,
    date_key               INT                  NOT NULL,
    store_key              INT                  NOT NULL,
    product_key            INT                  NOT NULL,
    customer_key           INT                  NOT NULL,
    employee_key           INT                  NOT NULL,
    promotion_key          INT                  NOT NULL,
    source_line_number     INT                  NOT NULL,
    transaction_number     NVARCHAR(50)         NOT NULL,
    transaction_time       DATETIME             NULL,
    quantity               INT                  NOT NULL,
    unit_price             DECIMAL(10,2)        NOT NULL,
    gross_sales_amount     DECIMAL(12,2)        NOT NULL,
    discount_percent       DECIMAL(5,2)         NOT NULL,
    discount_amount        DECIMAL(12,2)        NOT NULL,
    net_sales_amount       DECIMAL(12,2)        NOT NULL,
    load_datetime          DATETIME             NOT NULL CONSTRAINT df_fact_store_sales_load_datetime DEFAULT GETDATE(),
    CONSTRAINT pk_fact_store_sales PRIMARY KEY (fact_store_sales_sk),
    CONSTRAINT fk_fact_store_sales_date      FOREIGN KEY (date_key)      REFERENCES gold.dim_date(date_key),
    CONSTRAINT fk_fact_store_sales_store     FOREIGN KEY (store_key)     REFERENCES gold.dim_store(store_key),
    CONSTRAINT fk_fact_store_sales_product   FOREIGN KEY (product_key)   REFERENCES gold.dim_product(product_key),
    CONSTRAINT fk_fact_store_sales_customer  FOREIGN KEY (customer_key)  REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT fk_fact_store_sales_employee  FOREIGN KEY (employee_key)  REFERENCES gold.dim_employee(employee_key),
    CONSTRAINT fk_fact_store_sales_promotion FOREIGN KEY (promotion_key) REFERENCES gold.dim_promotion(promotion_key)
);

CREATE TABLE gold.fact_online_sales (
    fact_online_sales_sk    BIGINT IDENTITY(1,1) NOT NULL,
    date_key                INT                  NOT NULL,
    customer_key            INT                  NOT NULL,
    product_key             INT                  NOT NULL,
    warehouse_key           INT                  NOT NULL,
    promotion_key           INT                  NOT NULL,
    order_status_key        INT                  NOT NULL,
    payment_method_key      INT                  NOT NULL,
    source_order_item_number INT                 NOT NULL,
    source_order_number     INT                  NOT NULL,
    quantity                INT                  NOT NULL,
    unit_price              DECIMAL(10,2)        NOT NULL,
    gross_sales_amount      DECIMAL(12,2)        NOT NULL,
    discount_percent        DECIMAL(5,2)         NOT NULL,
    discount_amount         DECIMAL(12,2)        NOT NULL,
    net_sales_amount        DECIMAL(12,2)        NOT NULL,
    order_total             DECIMAL(10,2)        NULL,
    load_datetime           DATETIME             NOT NULL CONSTRAINT df_fact_online_sales_load_datetime DEFAULT GETDATE(),
    CONSTRAINT pk_fact_online_sales PRIMARY KEY (fact_online_sales_sk),
    CONSTRAINT fk_fact_online_sales_date      FOREIGN KEY (date_key)      REFERENCES gold.dim_date(date_key),
    CONSTRAINT fk_fact_online_sales_customer  FOREIGN KEY (customer_key)  REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT fk_fact_online_sales_product   FOREIGN KEY (product_key)   REFERENCES gold.dim_product(product_key),
    CONSTRAINT fk_fact_online_sales_warehouse FOREIGN KEY (warehouse_key) REFERENCES gold.dim_warehouse(warehouse_key),
    CONSTRAINT fk_fact_online_sales_promotion FOREIGN KEY (promotion_key) REFERENCES gold.dim_promotion(promotion_key),
    CONSTRAINT fk_fact_online_sales_order_status FOREIGN KEY (order_status_key) REFERENCES gold.dim_order_status(order_status_key),
    CONSTRAINT fk_fact_online_sales_payment_method FOREIGN KEY (payment_method_key) REFERENCES gold.dim_payment_method(payment_method_key)
);
GO

PRINT 'All Gold tables created successfully.';
