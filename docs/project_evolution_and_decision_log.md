# World Bank SQL Data Pipeline — Project Evolution and Decision Log


## 1. What this document is for

I use this log to track how the project develops from a MySQL analysis into an analytics engineering project, including what I change and why.

### Documentation rule

I only mark a change **Completed** once its validation checks pass. Until then, I keep planned results and expected row counts separate from confirmed findings.

### Status labels

- **Planned** — accepted but not started.
- **In progress** — implementation has started but validation is incomplete.
- **Completed** — implemented, tested, documented, and committed.
- **Deferred** — intentionally postponed, with a reason recorded.

---

## 2. Baseline before the improvement work

The first version was built with MySQL 8.0 and consisted of seven numbered SQL files covering ingestion, profiling, cleaning, validation, transformation, and analysis.

### Verified baseline

| Measure | Confirmed result |
|---|---:|
| Raw records loaded | 729 |
| Cleaned records | 720 |
| Quarantined records | 7 |
| Exact duplicate records removed | 2 |
| Numbered SQL phases completed | 1–7 |

The pipeline deliberately loaded raw indicator fields as `VARCHAR`. This allowed malformed values to enter the raw layer without causing ingestion to fail. Cleaning and type conversion were then handled in controlled downstream steps.

The cleaning process also:

- distinguished exact duplicates from conflicting duplicates;
- used a country reference table to standardise names, codes, regions, and income groups;
- quarantined invalid records instead of inventing or estimating missing values;
- preserved a `quarantine_reason` for auditability;
- converted invalid numeric and out-of-range values to `NULL` only after investigation.


---

## 3. Improvement roadmap

| ID | Change | Status | Main reason |
|---|---|---|---|
| DEC-001 | Migrate the active database from MySQL to PostgreSQL | Planned | PostgreSQL offers a smoother path to dbt and includes analytical functions such as `corr()` and `regr_r2()` |
| DQ-001 | Identify and exclude aggregate entities such as EUU and WLD | Planned | Regional and world totals must not be treated as countries |
| AN-001 | Add log transformations, correlations, and regression diagnostics | Planned | The existing grouped averages do not directly measure relationships in the research question |
| DOC-001 | Publish numerical findings in the README | Planned | Reviewers should be able to see results without running the entire project |
| REPO-001 | Align the documented and actual repository structure | Planned | Repository documentation must match the files that actually exist |
| ENG-001 | Restructure SQL logic as dbt models and tests | Planned | Introduce modular transformations, lineage, documentation, and automated data tests |
| API-001 | Add a FastAPI read layer over the marts | Planned | Make curated results available without placing SQL in request handlers |
| APP-001 | Add a Streamlit application | Planned | Provide an accessible interface for results and pipeline-health information |
| ORCH-001 | Add Airflow orchestration | Deferred | Orchestration adds value after the load and transformation steps are stable |
| OPS-001 | Add Docker Compose and final run instructions | Planned | Make the full project reproducible with one documented startup process |

---

## 4. Detailed decision records

## DEC-001 — Migrate from MySQL to PostgreSQL

**Status:** Planned  
**Decision date:** 10 September 2026

### Context

The original project was completed in MySQL 8.0. The next stage introduces dbt, an API, a Streamlit application, and eventually Airflow. Migrating after these dependencies are added would require more rework because multiple layers would already depend on MySQL-specific behaviour.

### Decision

I will use PostgreSQL for the next version of the project and keep the MySQL version and its Git history as the original working implementation.

### Reasoning

- The migration is relatively small while the project is still primarily CSV and SQL based.
- PostgreSQL has a mature, first-class dbt adapter.
- PostgreSQL provides built-in statistical aggregates such as `corr()`, `regr_slope()`, and `regr_r2()`.
- Using PostgreSQL will give me experience connecting analytical models, APIs, and containerised applications.
- Migrating now prevents dbt models, API code, and orchestration tasks from becoming tied to a database that may later need to be replaced.

### Porting principles

1. Preserve the raw-layer pattern: source indicator values must still land as text before controlled cleaning and casting.
2. Preserve original source files and the MySQL SQL files for traceability.
3. Port one phase at a time and validate its output before continuing.
4. Do not silently alter cleaning rules during syntax conversion.
5. Record PostgreSQL-specific changes, including:
   - MySQL backticks replaced by PostgreSQL-safe identifiers;
   - `AUTO_INCREMENT` replaced by an identity column where required;
   - MySQL regular expressions replaced by PostgreSQL `~` expressions;
   - MySQL file-loading commands replaced by PostgreSQL `COPY` or `\copy`;
   - date and numeric conversions reviewed for PostgreSQL behaviour;
   - `LN()` used when the natural logarithm is required.

### Preservation step

Before porting, I will record the current MySQL commit hash and tag it `mysql-v1-complete`. I can then compare the migration against the working MySQL version.

### Validation required before completion

- All source CSV rows load successfully.
- Raw text values are unchanged after ingestion.
- Cleaning rules produce the intended valid, rejected, and deduplicated populations.
- Country-reference checks return no unintended mismatches.
- Numeric fields have the correct PostgreSQL types in the cleaned layer.
- All analysis queries execute successfully.
- Results that should be database-independent agree with the MySQL baseline, except where a documented correction intentionally changes them.

### Completion evidence to add later

- PostgreSQL version:
- Migration commit:
- MySQL baseline tag:
- Final raw count:
- Final cleaned count:
- Final quarantined count:
- Important result differences and explanations:

---

## DQ-001 — Exclude regional and world aggregate rows

**Status:** Planned

### Problem

The source data includes `EUU-2021` for the European Union and `WLD-2015` for the world. These are aggregate entities, not individual countries. If they remain in country-level analysis tables, they can distort averages, rankings, and comparisons.

### Decision

During the PostgreSQL migration, I will classify these records as aggregate entities and exclude them from country-level marts. I will keep them in quarantine or a separate aggregate table and record the reason for excluding them.

### Reasoning

- A world value represents the combined population or economy of many countries and is not comparable to a single country row.
- The European Union overlaps with its member countries, creating double counting.
- Country-level statistics should operate on one row per valid country-year.
- Keeping the excluded rows with a reason maintains traceability.

### Preferred implementation

I plan to identify valid country codes through the reference layer, or add an `entity_type` field with values such as `country`, `region`, and `world`. This keeps the exclusions in one place.

Quarantine reason to use:

```text
Aggregate entity excluded from country-level analysis
```

### Expected reconciliation — not yet confirmed

If both aggregate rows are currently included among the 720 cleaned rows, the expected reconciliation is:

| Population | Expected count |
|---|---:|
| Raw | 729 |
| Cleaned country-level rows | 718 |
| Quarantined rows | 9 |
| Exact duplicate rows removed | 2 |

Check: `718 + 9 + 2 = 729`.

These counts are **expected**. I still need to confirm where EUU and WLD currently reside and check the counts in PostgreSQL.

### Validation required before completion

- Search the raw, cleaned, quarantine, transformation, and analysis layers for `EUU` and `WLD`.
- Confirm that neither code is present in a country-level mart.
- Confirm that both source records remain traceable.
- Re-run all rankings and country averages after exclusion.
- Record the confirmed reconciliation counts here and in the README.

---

## AN-001 — Add log transformations and relationship measures

**Status:** Planned

### Problem

The research question asks whether CO2 emissions per capita, unemployment, and electricity access are related to variation in life expectancy, and how GDP and population relate to these indicators. Grouped averages and value buckets describe patterns, but do not directly quantify the strength or direction of relationships.

### Decision

I will add a relationship-analysis section containing:

- Pearson correlations between life expectancy and each selected indicator;
- GDP per capita rather than total GDP for country comparisons;
- `LN(gdp_per_capita)` to test a non-linear income–health relationship;
- regression diagnostics such as slope and R-squared where appropriate;
- sample-size and missing-value counts beside every result.

### Reasoning

- Total GDP is strongly influenced by country size; GDP per capita is more suitable for comparing living standards.
- The relationship between income and life expectancy is often non-linear, so a natural-log transformation can reveal a pattern hidden by raw-scale comparisons.
- Correlation provides a clear measure of direction and strength.
- R-squared shows how much variation is associated with a single predictor in a simple linear model.
- Reporting sample size prevents results based on missing values from appearing more complete than they are.

### Interpretation rule

I will interpret these results as **associations**. They cannot establish whether an indicator causes life expectancy to change, and pairwise correlations do not control for other variables. I may add a Python model later if I need multivariable analysis.

### PostgreSQL functions expected

```sql
LN(gdp_per_capita)
CORR(life_expectancy, predictor)
REGR_R2(life_expectancy, predictor)
REGR_SLOPE(life_expectancy, predictor)
```

### Validation required before completion

- Exclude non-country entities before calculating relationships.
- Use only positive GDP-per-capita values before applying `LN()`.
- Let each calculation exclude `NULL` pairs consistently.
- Report `COUNT(*)` or paired observation count for every measure.
- Compare the raw GDP-per-capita correlation with the log-transformed result.
- Record unexpected results and the limitations of the analysis.

---

## DOC-001 — Add findings to the README

**Status:** Planned

### Problem

The existing SQL contains the analysis, but a reviewer cannot see the results without setting up the database and running every file.

### Decision

I will add a short **Key Findings** section to the README once I have validated the corrected PostgreSQL analysis.

### Reasoning

- The README needs to show what I found as well as how I built the pipeline.
- Including the figures makes the findings easier to check against the SQL outputs.
- The findings create a direct link between SQL outputs and Tableau dashboards.

### Findings format

For each main result, I will record:

1. the result in plain language;
2. the exact statistic and sample size;
3. the relevant SQL file or model;
4. the related Tableau view;
5. a limitation or caution where necessary.

I will only add figures I have reproduced from the corrected country-level dataset.

---

## REPO-001 — Align repository structure and supporting files

**Status:** Planned

### Problem

The README lists `dashboard/` and `data/processed/`, but these folders are missing from the repository. I also need to add the supporting files listed below as the project develops.

### Decision

I will update the repository tree to match the files that exist and add supporting files as they become necessary.

### Reasoning

- The folder structure in the README needs to be accurate so someone can follow it.
- Empty folders are not tracked by Git, so each required folder should contain a useful README or an actual artifact.
- A `.gitignore` prevents credentials, local database files, virtual environments, caches, and generated artifacts from being committed.
- A `LICENSE` tells other people what they may do with the work.
- `requirements.txt` should be added when Python dependencies are introduced; it should not be an empty placeholder.

### Planned actions

- Add `dashboard/README.md`, dashboard images, and the Tableau Public link or packaged workbook when appropriate.
- Add `data/processed/README.md` explaining whether processed data is versioned or generated.
- Add a project-specific `.gitignore`.
- Choose and add a licence.
- Add Python dependency files with the first Python component.
- Update the README repository tree after the actual files exist.

---

## ENG-001 — Introduce dbt

**Status:** Planned

### Decision

I will organise the existing SQL into dbt models:

- cleaning logic becomes staging models;
- reusable transformations become intermediate models where necessary;
- analytical tables become marts;
- validation queries become dbt tests;
- source tables are declared as dbt sources.

### Reasoning

Most of the logic is already in the SQL files. I want to use dbt to organise it into models, manage dependencies, document lineage, and run builds and tests consistently.

### Completion criteria

- `dbt build` succeeds from a clean PostgreSQL environment.
- Primary keys, accepted values, relationships, non-null rules, and custom business rules are tested.
- Generated documentation clearly shows source-to-mart lineage.
- Mart outputs reconcile with the validated PostgreSQL SQL version.

---

## API-001 — Add FastAPI over the marts

**Status:** Planned

### Decision

I will expose selected analytical results through read-only FastAPI endpoints. Route handlers will call a data-access or service layer so the SQL stays separate from request handling.

### Reasoning

The API will let an application use the cleaned results while keeping data access in one place for maintenance and testing.

### Completion criteria

- Read-only endpoints return documented schemas.
- Inputs are validated.
- Database credentials are supplied through environment variables and never committed.
- API results match the underlying marts.

---

## APP-001 — Add a Streamlit interface

**Status:** Planned

### Decision

I will build a Streamlit application that gets its data from the API, with separate views for analytical results and pipeline health.

### Reasoning

This will make the results easier to explore while keeping the interface, API, and data models separate.

### Completion criteria

- The application uses API endpoints for its data.
- Loading, empty, and error states are handled.
- Charts display the same validated findings as the README and Tableau dashboards.
- The pipeline-health view reports freshness and test status without exposing secrets.

---

## ORCH-001 — Add Airflow after the pipeline is stable

**Status:** Deferred

### Decision

I will add Airflow once PostgreSQL, dbt, FastAPI, and Streamlit are working independently.

### Reasoning

I need the load and transformation steps to work reliably before scheduling them. Leaving Airflow until later lets me finish and validate each part first.

### Intended scope

- schedule the data load and `dbt build`;
- define task dependencies;
- support retries and observable failures;
- make reruns idempotent;
- record run status and timestamps.

---

## OPS-001 — Add Docker Compose and final run instructions

**Status:** Planned

### Decision

I will package the components with Docker Compose once each one works reliably on its own.

### Reasoning

A single startup process will make it easier for someone else to run the project and reproduce the results.

### Completion criteria

- Services start with one documented command.
- No credentials are stored in the repository.
- Database initialisation is repeatable.
- Health checks and service dependencies are defined.
- A fresh setup reproduces the documented results.

---

## 5. Implementation order

I will work through the changes in this order:

1. Preserve and tag the completed MySQL baseline.
2. Port ingestion, cleaning, validation, transformation, and analysis to PostgreSQL.
3. During the port, verify and remove EUU and WLD from all country-level outputs.
4. Reconcile row counts and rerun all existing analysis.
5. Add GDP-per-capita log transformations, correlations, and regression diagnostics.
6. Record exact findings in the README and connect them to Tableau.
7. Add the missing repository files and update the folder documentation.
8. Restructure the validated SQL as dbt models and tests.
9. Add FastAPI.
10. Add Streamlit.
11. Add Airflow.
12. Add Docker Compose and perform the final README pass.

I will start with PostgreSQL and check the aggregate rows as part of the migration.

---

## 6. Change-entry template

I will use this template to record completed changes:

```markdown
### CHANGE-ID — Short title

**Status:** Completed  
**Date:** YYYY-MM-DD  
**Commit:** `<commit-hash>`

**Problem**  
What was wrong, missing, or limited?

**Decision**  
What was changed?

**Reasoning**  
Why was this option selected instead of the alternatives?

**Files changed**
- `path/to/file`

**Validation**
- Query or test performed
- Expected result
- Actual result

**Impact**  
What downstream results, tables, dashboards, or conclusions changed?

**Limitations or follow-up**  
What remains unresolved?
```

---

## 7. Git commit plan

I plan to keep commits small and match them to the decision records, using messages such as:

```text
docs: add project evolution and decision log
chore: preserve completed MySQL baseline
feat: port raw ingestion to PostgreSQL
feat: port cleaning and quarantine logic to PostgreSQL
fix: exclude aggregate entities from country-level data
test: add PostgreSQL validation and reconciliation checks
feat: add log-transformed relationship analysis
docs: publish validated findings and Tableau outputs
chore: align repository structure and supporting files
feat: restructure transformations as dbt models
feat: expose analytical marts through FastAPI
feat: add Streamlit results and pipeline health views
feat: orchestrate load and dbt build with Airflow
chore: add Docker Compose and reproducible run guide
```

I will keep each commit focused on one change and update its documentation at the same time. Results will be committed with the query or test that produced them.

---

## 8. README project-evolution summary

Draft paragraph for the final README, to update as I complete the work:

> The project began as a seven-phase MySQL pipeline covering raw ingestion, profiling, cleaning, validation, transformation, and SQL analysis. The raw layer intentionally stored source indicators as text so malformed values could be captured and investigated rather than rejected during ingestion. After reviewing the first version, I preserved it as a baseline and migrated the active implementation to PostgreSQL to support stronger analytical functions and a first-class dbt workflow. I also corrected the treatment of regional and world aggregate rows, added log-transformed relationship analysis, and documented validated findings. The later architecture separates PostgreSQL and dbt transformations, a read-only FastAPI layer, a Streamlit interface, and Airflow orchestration.

I will only move these claims into the README once the corresponding decisions are marked **Completed**.

