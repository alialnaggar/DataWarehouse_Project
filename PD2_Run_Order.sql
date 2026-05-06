/*
PD2 execution order in SSMS.
Enable SQLCMD Mode before running this file because it uses :r includes.
Run against the SQL Server VM where the DataWarehouse database will be created.
CSV files should be available under C:\sql\datasets\.
*/

:r .\Scripts\init_database.sql
:r .\Scripts\Bronze\ddl_bronze.sql
:r .\Scripts\Bronze\proc_load_bronze.sql
EXEC bronze.load_bronze;

:r .\Scripts\Silver\ddl_silver.sql
:r .\Scripts\Silver\proc_load_silver.sql
EXEC silver.load_silver;

:r .\Scripts\Gold\ddl_gold.sql
:r .\Scripts\Gold\proc_load_gold.sql
EXEC gold.load_gold;

:r .\Scripts\Gold\validate_gold.sql

/*
After validation passes, open Scripts\PD2-SubmissionScript-Final.sql in SSMS
and run it on the live DataWarehouse database. Capture both Results and
Messages tabs, including the anti-plagiarism token in Messages.
*/
