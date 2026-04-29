https://docs.google.com/forms/d/e/1FAIpQLSf-9UFBxh9yyNGYrRIxWXcvamFsOE_pgy1IfpVWAIWnVfqzxw/viewform
# Retail Data Warehouse — Business Intelligence Project

**Course:** Business Intelligence and Data Analytics (BINF 602)
**Institution:** German International University
**Instructor:** Dr. Shaimaa Masry

---

## Project Overview

A fully functional end-to-end Data Warehouse built on the **Medallion Architecture** (Bronze → Silver → Gold), ingesting raw retail OLTP data from 19 CSV source files, applying progressive data quality transformations, and exposing analytical star schemas for Power BI dashboards.

---

## Architecture

```
Sources (CSV) → Bronze Layer → Silver Layer → Gold Layer → Power BI
```

| Layer | Purpose | Tables |
|-------|---------|--------|
| Bronze | Raw staging — data loaded as-is from CSV | 19 tables |
| Silver | Cleaned, standardized, enriched data | 19 tables |
| Gold | Star schema dimensional model | Fact + Dimension tables |

---

## Dataset

19 CSV source files from a retail CRM/ERP system covering:

- 4,000 customers across 15 US cities
- 600 products across 12 departments and 30 brands
- 64 stores, 218 registers, 800 employees
- 14,962 in-store transaction line items
- 7,151 online order line items
- 1,927 delivery records across 8 courier providers
- 3,600 inventory snapshots

---

## Repository Structure

```
├── bronze/
│   ├── init_database.sql               # Creates DataWarehouse DB and schemas
│   ├── ddl_bronze.sql                  # Creates all 19 Bronze tables
│   ├── Procedures_log_Bronze_layer.sql # Bronze load stored procedure
│   └── Execute_and_check_procedure.sql # Execution and validation script
│
├── silver/
│   ├── ddl_silver.sql                  # Creates all 19 Silver tables
│   └── proc_load_silver.sql            # Silver transformation stored procedure
│
└── gold/
    ├── ddl_gold.sql                    # Creates dimension and fact tables
    └── proc_load_gold.sql              # Gold load stored procedure
```

---

## Star Schemas

### Schema 1 — Store Sales Performance
Grain: One row per line item per POS transaction

**Fact Table:** `gold.fact_store_sales`
**Dimensions:** `dim_date`, `dim_store`, `dim_product`, `dim_customer`, `dim_employee`, `dim_promotion`

### Schema 2 — Online Sales Performance
Grain: One row per line item per online order

**Fact Table:** `gold.fact_online_sales`
**Dimensions:** `dim_date`, `dim_customer`, `dim_product`, `dim_warehouse`, `dim_promotion`

**Conformed Dimensions:** `dim_date`, `dim_customer`, `dim_product`, `dim_promotion` are shared across both schemas forming a Galaxy (Fact Constellation) schema.

---

## How to Run

> Requires: SQL Server, SSMS, CSV files placed in `C:\sql\datasets\`

Run scripts in this order:

```sql
-- 1. Initialize database and schemas
init_database.sql

-- 2. Create Bronze tables
bronze/ddl_bronze.sql

-- 3. Load Bronze layer
EXEC bronze.load_bronze;

-- 4. Create Silver tables
silver/ddl_silver.sql

-- 5. Load Silver layer
EXEC silver.load_silver;

-- 6. Create Gold tables
gold/ddl_gold.sql

-- 7. Load Gold layer
EXEC gold.load_gold;
```

---

## Key Transformations (Silver Layer)

- NULL handling across all tables
- Gender standardization: M/F → Male/Female/Unknown
- Loyalty tier standardization: Bronze/Silver/Gold/Platinum
- Order status standardization: Canceled → Cancelled
- Date casting: NVARCHAR → DATE/DATETIME using TRY_CAST
- Deduplication via ROW_NUMBER() on business keys
- Derived columns: Full_Name, Tenure_Years, Sales_Amount, Net_Sales_Amount, Reorder_Flag, On_Time_Flag, Days_to_Ship, Days_to_Deliver

---

## Deliverables

| Code | Deliverable | Status |
|------|------------|--------|
| PD1 | Bronze and Silver Layers
| PD2 | Gold Layer (Star Schemas) 
| PD3 | Power BI Dashboard 

---

## Team Members

- Ali Alnaggar
