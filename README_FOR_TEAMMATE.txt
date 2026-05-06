PD2 FINAL HANDOFF - GIU BINF602 BUSINESS INTELLIGENCE AND ANALYTICS

This package contains the files needed to run the PD2 Gold Layer, execute the
official PD2 audit, add the required screenshots to the report, and prepare the
final submission ZIP.

Included:
- DataWarehouse_Project-main\                     Clean runnable project copy
- PD2_Submission.zip                              Current submission draft
- PD1_Technical_Report.docx                       Current report draft
- PD2_Run_Order.sql                               Main run script
- Scripts\Gold\ddl_gold.sql                      Gold DDL
- Scripts\Gold\proc_load_gold.sql                Gold load procedure
- Scripts\Gold\validate_gold.sql                 Gold validation checks
- Scripts\PD2-SubmissionScript-Final.sql         Official PD2 audit script
- Datasets\                                       CSV files only

Exact steps:
1. Install/open SQL Server + SSMS.
2. Copy CSVs to C:\sql\datasets\.
   - Create C:\sql\datasets\ if it does not already exist.
   - Copy every CSV from this handoff's Datasets\ folder into C:\sql\datasets\.
3. Open PD2_Run_Order.sql.
   - Recommended: open the top-level PD2_Run_Order.sql from this handoff
     folder. It points into DataWarehouse_Project-main\Scripts\.
   - Alternative: open DataWarehouse_Project-main\PD2_Run_Order.sql from
     inside the project folder. That copy uses the repo-style .\Scripts\ paths.
4. Enable Query -> SQLCMD Mode.
5. Run script.
   - It runs database init, Bronze DDL/load, Silver DDL/load, Gold DDL/load,
     and Gold validation.
   - If any error appears, stop and report the exact SSMS error message.
6. Run official Scripts\PD2-SubmissionScript-Final.sql.
   - Run it in the same VM/database/login after the Gold load succeeds.
   - Do not edit the generated token or reuse old output.
7. Screenshot Results tab, Messages tab with token, and Gold schema.
   - Required screenshot 1: official audit Results tab.
   - Required screenshot 2: official audit Messages tab including token.
   - Required screenshot 3: SQL Server Gold schema/database diagram.
8. Insert screenshots into PD1_Technical_Report.docx.
   - Insert them into the PD2 validation/audit evidence section.
   - Make sure no screenshot placeholders remain.
   - Keep all PD1 content; PD2 is appended, not replacing PD1.
9. Rebuild PD2_Submission.zip.
   - Include the updated report .docx.
   - Include Scripts\Gold\ddl_gold.sql.
   - Include Scripts\Gold\proc_load_gold.sql.
   - Include Scripts\Gold\validate_gold.sql.
   - Include PD2_Run_Order.sql.
   - Include Scripts\PD2-SubmissionScript-Final.sql.
   - Include the real PD2 audit Results screenshot.
   - Include the real PD2 audit Messages screenshot.
   - Include the real Gold schema screenshot.
10. Submit/report back errors.
   - Submit the final rebuilt ZIP to CMS.
   - If anything fails, report the exact step number, script name, and full
     SSMS error text.

Quality checklist before submission:
- Official audit has no warnings about missing gold schema.
- Official audit has no warnings about missing dim_ tables.
- Official audit has no warnings about missing fact_ tables.
- Official audit has no warnings about missing primary keys.
- gold.fact_store_sales and gold.fact_online_sales both have rows.
- Dimension tables have rows.
- Fact foreign-key columns are not null.
- No duplicate natural keys appear in dimensions.
- Facts join successfully to every referenced dimension.
- Report contains real screenshots, not placeholders.
