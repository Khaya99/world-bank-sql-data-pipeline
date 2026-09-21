# Brazil and Mexico data corrections

Date: 21 September 2026

## What changed and why

The source defect manifest and generator identify two recoverable scale errors:

| Record | Measurement | Raw value | Cleaned value | Rule |
|---|---|---:|---:|---|
| Brazil 2022 | Life expectancy | 7.5 | 75.0 years | Reverse the documented division by 10 |
| Mexico 2023 | GDP | 1,815,091.26 | 1,815,091,260,000 USD | Convert millions of USD to USD |

The raw values are preserved. Each correction is recorded in `audit.data_quality_log` with the affected raw ID, column, issue type, original value, cleaned value and action.

Mexico's source value was rounded to two decimal places after conversion to millions. Multiplying it by 1,000,000 restores the unit, but cannot recover the precision discarded by that rounding. The replacement is therefore a documented unit conversion, not a claim to recover the exact pre-error synthetic GDP.

## Files

- `sql/05_data_cleaning.sql` logs these corrections and applies them whenever staging is rebuilt.
- `sql/06_data_validation.sql` adds checks for the corrected values, original raw values and audit records.
- `sql/maintenance/fix_brazil_mexico.sql` applies the same changes to an already-loaded database in one transaction. It verifies the expected source values and counts before changing anything.

## Verification

The original CSV and reference CSV were loaded into a separate PostgreSQL 18.6 test database. The original pipeline reproduced the previously reported correlations before the changes were applied. The corrected pipeline passed these checks:

- Only Brazil 2022 life expectancy and Mexico 2023 GDP changed, apart from their cleaning timestamps.
- Raw records remained unchanged.
- Counts remained 729 raw, 718 cleaned, 7 quarantined and 4 excluded duplicates.
- All 718 accepted country-year combinations remained unique.
- Existing reference, required-field, range and exclusion checks returned no failures.
- Both new correction checks passed.
- Rerunning the maintenance script did not change the data or add duplicate audit entries.
- A full staging rebuild retained the corrections, and a second rebuild produced the same results.
- An unexpected raw value caused the maintenance script to abort and roll back.
- All saved SQL analysis queries executed successfully.

## Updated findings from the test rebuild

| Relationship | Before | After |
|---|---:|---:|
| Electricity access and life expectancy | 0.740 | 0.780 |
| GDP per capita and life expectancy | 0.676 | 0.702 |
| CO2 emissions per capita and life expectancy | 0.488 | 0.500 |
| Population and life expectancy | -0.149 | -0.154 |
| GDP per capita change and life expectancy change, 2000 to 2023 | -0.305 | -0.365 |

The electricity-access change correlation remains 0.737. Mexico 2023 GDP per capita is now 14,125.28. The 2022 average life expectancy is 76.37, and the 2023 average GDP per capita is 28,653.38.

These are associations in synthetic data and do not establish causation.

## Apply to the existing local database

The test rebuild is separate from the existing `world_bank_analytics` database. That database requires its existing authentication; it was not changed during these tests.

1. In pgAdmin, open Query Tool connected to `world_bank_analytics`.
2. Open `sql/maintenance/fix_brazil_mexico.sql` and run the whole file.
3. Confirm Brazil 2022 life expectancy is 75.00, Mexico 2023 GDP is 1815091260000.00, and Mexico GDP per capita is 14125.28.
4. Confirm the displayed counts are 729, 718, 7 and 4.
5. Run `sql/06_data_validation.sql`. The two new correction checks must both show true.
6. Run `sql/08_sql_analysis.sql` and compare the results with the table above.

If a check fails within the transaction, run `ROLLBACK;` before investigating. Do not skip the precondition checks to force the update.

The analytics view reads staging automatically. The saved Tableau workbook still uses MySQL, so it also needs its source changed to the PostgreSQL analytics view before these corrections appear in the dashboards.
