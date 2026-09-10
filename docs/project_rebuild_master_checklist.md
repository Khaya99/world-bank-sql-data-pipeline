# World Bank SQL Data Pipeline — Master Rebuild Checklist

**Owner:** Khaya Nyawose  
**Start date:** 10 September 2026  
**Database decision:** PostgreSQL  
**Visualisation tool:** Tableau  
**Working method:** I will complete, validate, document, and commit one checkpoint at a time.

This is my working checklist for rebuilding the project. I keep the reasoning behind each major decision in `project_evolution_and_decision_log.md`.

---

## Current position

### Already completed

- [x] Original MySQL pipeline phases 1–7
- [x] Raw ingestion, profiling, cleaning, validation, transformation, and SQL analysis
- [x] Original baseline: 729 raw, 720 cleaned, and 7 quarantined rows
- [x] Two exact duplicates removed in the original process
- [x] Two Tableau dashboards designed
- [x] Git history with progressive commits
- [x] Detailed project evolution and decision log drafted

### Still requiring correction or verification

- [ ] Confirm where EUU-2021 and WLD-2015 exist and exclude aggregate entities from country-level analysis
- [ ] Resolve the conflicting Korea, Rep. 2000 and Vietnam 2013 duplicate groups using an explicit rule
- [ ] Migrate the active implementation from MySQL to PostgreSQL
- [ ] Add log-transformed GDP-per-capita analysis
- [ ] Add correlations, paired sample sizes, and regression diagnostics
- [ ] Refresh Tableau using the corrected PostgreSQL output
- [ ] Publish exact findings and supporting images in the README
- [ ] Align the actual repository with the documented structure
- [ ] Add dbt, then FastAPI, Streamlit, Airflow, and Docker Compose

---

# Stage 0 — Protect the completed MySQL version

**Goal:** Preserve the existing project before changing database engines.

## Step 0.1 — Confirm the repository is clean

From the repository folder in my VS Code terminal:

```bash
git status
```

- [ ] Confirm that no intended files are unsaved or untracked.
- [ ] If there are project changes, review and commit them before continuing.
- [ ] Record the current branch name.
- [ ] Record the current commit hash with `git rev-parse HEAD`.

## Step 0.2 — Add the documentation

I will keep both planning documents under `docs/`:

```text
docs/
├── project_evolution_and_decision_log.md
└── project_rebuild_master_checklist.md
```

- [ ] Add both documents.
- [ ] Confirm that planned work is labelled **Planned**, not **Completed**.
- [ ] Commit:

```bash
git add docs
git commit -m "docs: add project evolution and rebuild plan"
```

## Step 0.3 — Tag the MySQL baseline

Once I have confirmed that the original MySQL version is complete:

```bash
git tag -a mysql-v1-complete -m "Completed MySQL version before PostgreSQL migration"
git push origin main
git push origin mysql-v1-complete
```

- [ ] Confirm the tag appears on GitHub.
- [ ] Add the tag name and commit hash to the decision log.

## Step 0.4 — Create a migration branch

```bash
git switch -c feature/postgresql-migration
```

- [ ] Confirm the terminal shows `feature/postgresql-migration`.

### Stage 0 exit check

I will move on once:

- the working tree is clean;
- the MySQL baseline is tagged and pushed;
- the documentation is committed;
- the PostgreSQL migration branch exists.

---

# Stage 1 — Set up PostgreSQL locally

**Goal:** Create a clean PostgreSQL environment without changing the dataset yet.

I will use PostgreSQL locally on Windows with pgAdmin for the migration. I will add Docker once the pipeline is working correctly.

## Step 1.1 — Install and verify PostgreSQL

- [ ] Install a supported PostgreSQL release and pgAdmin.
- [ ] Save the database administrator password securely.
- [ ] Confirm the PostgreSQL Windows service is running.
- [ ] Open pgAdmin and connect to the local server.

## Step 1.2 — Create the project database

Create:

```text
world_bank_analytics
```

- [ ] Confirm the new database appears in pgAdmin.

## Step 1.3 — Create data-layer schemas

I will use five schemas:

| Schema | Purpose |
|---|---|
| `raw` | Immutable source data loaded as received |
| `reference` | Country reference and classification data |
| `staging` | Cleaned, typed, country-level records |
| `audit` | Excluded records and reasons |
| `analytics` | Reusable analytical views or marts |

My first PostgreSQL setup file will be:

```text
sql/01_create_database_objects.sql
```

- [ ] Create all schemas with `CREATE SCHEMA IF NOT EXISTS`.
- [ ] Run the script twice to confirm it is safe to rerun.
- [ ] Commit after validation.

### Stage 1 exit check

- PostgreSQL is running.
- `world_bank_analytics` exists.
- All five schemas exist.
- The setup script can be rerun without failing.

---

# Stage 2 — Port the raw ingestion layer

**Goal:** Reproduce the raw 729-row dataset in PostgreSQL without cleaning it during import.

## Step 2.1 — Design the raw table

Create:

```text
raw.world_bank_data
```

My raw-layer rules:

- Add a unique `raw_record_id` identity column for traceability.
- Keep imported indicator and year values as `TEXT` in the raw layer.
- Keep `source_file`.
- Use `TIMESTAMPTZ` for the ingestion timestamp.
- Never edit or delete records from the raw table.

## Step 2.2 — Port the load procedure

- [ ] Replace MySQL loading syntax with PostgreSQL `COPY` or pgAdmin import.
- [ ] Load the same original CSV—not a manually edited copy.
- [ ] Record the source filename and load timestamp.

## Step 2.3 — Validate ingestion

Required checks:

- [ ] Row count is exactly 729.
- [ ] Column count and names match the data dictionary.
- [ ] Malformed values are still visible as text.
- [ ] Source rows have unique `raw_record_id` values.
- [ ] The raw CSV and raw table have matching record counts.

## Step 2.4 — Document and commit

I will record the PostgreSQL version, import method, row count, and validation result in the decision log.

Planned commit:

```text
feat: port raw World Bank ingestion to PostgreSQL
```

### Stage 2 exit check

I will start cleaning once I have confirmed the raw count is 729 and the raw table remains unmodified.

---

# Stage 3 — Port profiling and build explicit record classification

**Goal:** Identify every record that may not belong in the clean country-level dataset.

## Step 3.1 — Port the profiling checks

Create or port:

```text
sql/03_data_profiling.sql
```

Profile:

- missing values;
- duplicate country-year keys;
- invalid country codes and country-name mismatches;
- invalid years;
- malformed numeric values;
- impossible or unrealistic indicator ranges;
- aggregate entities;
- record counts by classification.

## Step 3.2 — Load and validate the country reference

Create:

```text
reference.country_reference
```

- [ ] Import the reference CSV.
- [ ] Confirm each valid country code is unique.
- [ ] Confirm the code-to-name mapping is unique.
- [ ] Decide whether the reference table needs an `entity_type` column.

Planned `entity_type` values:

```text
country
region
world
```

## Step 3.3 — Locate EUU and WLD everywhere

Search the raw, reference, staging, audit, transformation, analysis, and Tableau source layers for:

```text
EUU
WLD
European Union
World
```

- [ ] Record the raw record IDs.
- [ ] Record whether they were included in the old cleaned count of 720.
- [ ] Confirm they are aggregates rather than countries.
- [ ] Exclude them from every country-level output.
- [ ] Preserve them in `audit` with the reason `aggregate_entity`.

I will classify aggregates once upstream so individual analysis queries can use the same country-level dataset.

## Step 3.4 — Resolve exact duplicates

For identical country-year records:

- Keep one deterministic canonical record.
- Classify the repeated raw record as `exact_duplicate`.
- Preserve its raw record ID in the audit layer.
- Do not physically delete it from the immutable raw table.

## Step 3.5 — Resolve conflicting duplicates

Conflicting groups I need to investigate:

```text
Korea, Rep. — 2000
Vietnam — 2013
```

Decision rule:

1. If an authoritative source identifies the correct record, keep that record and classify the other one as rejected.
2. If no trustworthy source exists, do not average the two values and do not choose one arbitrarily.
3. When unresolved, exclude both conflicting rows from country-level analysis and classify both as `conflicting_duplicate_unresolved`.

- [ ] Record the chosen rule for Korea.
- [ ] Record the chosen rule for Vietnam.
- [ ] Update the Tableau note after the database rule is applied.

## Step 3.6 — Stop predicting the final counts

The earlier estimate of 718 cleaned and 9 quarantined rows considered only EUU and WLD. Conflicting duplicates may change those figures further.

I will calculate the final totals from record-level classifications and keep estimates separate from confirmed results.

### Stage 3 exit check

- Every excluded raw record has a reason.
- EUU and WLD cannot enter country-level analysis.
- Korea and Vietnam each have a documented resolution.
- Exact and conflicting duplicates are treated differently.
- No result depends on Tableau filtering to correct a database problem.

---

# Stage 4 — Port cleaning and validation

**Goal:** Produce one trusted, typed country-year dataset.

## Step 4.1 — Create the audit layer

Create an audit table or reproducible model containing at least:

```text
raw_record_id
country_name
country_code
year_raw
exclusion_reason
exclusion_detail
classified_at
```

Exclusion reasons I plan to use:

```text
invalid_year
invalid_country_code
aggregate_entity
exact_duplicate
conflicting_duplicate_unresolved
```

I will keep rows with malformed or out-of-range indicators where the country-year identity is valid, setting the affected values to `NULL` under documented rules. I will exclude entire records when their country-year identity is unreliable or outside scope.

## Step 4.2 — Create the typed staging table or view

Create:

```text
staging.world_bank_country_year
```

Requirements:

- valid country entity only;
- one row per country and year;
- year from 2000 through 2023;
- standardised country name, code, region, and income group;
- numeric PostgreSQL types for indicators;
- malformed and impossible indicator values converted to `NULL` only under documented rules;
- source `raw_record_id` retained for lineage.

## Step 4.3 — Re-run known quality checks

Confirm the handling of the previously identified issues:

- Kenya missing values;
- China missing unemployment;
- Nigeria missing GDP;
- Türkiye missing population;
- Egypt life expectancy outlier;
- United Kingdom unemployment outlier;
- South Africa negative CO2 value;
- Egypt electricity access above 100%;
- Türkiye 2015 malformed GDP;
- Canada 2010 malformed life expectancy;
- India 2021 malformed unemployment;
- South Africa 2015 malformed CO2;
- Norway 2013 malformed electricity access.

## Step 4.4 — Validate invariants

Required tests:

- [ ] `country_code + year` is unique in staging.
- [ ] All years are from 2000 through 2023.
- [ ] Only `entity_type = 'country'` appears in staging.
- [ ] GDP and population are non-negative when present.
- [ ] Life expectancy is within the accepted project range when present.
- [ ] Unemployment is between 0 and 100 when present.
- [ ] CO2 per capita is non-negative when present.
- [ ] Electricity access is between 0 and 100 when present.
- [ ] All accepted country codes exist in the reference table.

## Step 4.5 — Reconcile all 729 raw records

Use one auditable classification rule so that every raw row is either:

- accepted into staging; or
- excluded with a recorded reason.

I will fill in this table after validation. The raw count of 729 and zero unclassified rows are targets until confirmed in PostgreSQL:

| Measure | Confirmed PostgreSQL result |
|---|---:|
| Raw records | 729 |
| Accepted country-year records |  |
| Excluded records |  |
| Unclassified records | 0 |

The required equation is:

```text
raw records = accepted records + excluded records
```

## Step 4.6 — Commit

Planned commits:

```text
feat: port cleaning and audit classification to PostgreSQL
fix: exclude aggregate entities from country-level data
fix: resolve conflicting country-year duplicates
test: add PostgreSQL quality and reconciliation checks
```

### Stage 4 exit check

I will run the final analysis once every invariant passes and the reconciliation difference is zero.

---

# Stage 5 — Rebuild transformations and answer the research question

**Goal:** Move from descriptive grouped averages to measured relationships.

## Step 5.1 — Build analytical variables

Create a reusable analytical view or table containing:

- GDP per capita: `gdp_usd / population`;
- natural log of GDP per capita: `LN(gdp_per_capita)`;
- the original selected indicators;
- country, region, income group, and year;
- data-completeness flags where useful.

Rules:

- Do not divide by zero.
- Only calculate `LN()` for positive GDP-per-capita values.
- Do not replace missing analytical values with zero.

## Step 5.2 — Keep the descriptive analysis

Retain useful existing queries such as:

- trends by year;
- averages by country, region, and income group;
- country rankings;
- changes from 2000 to 2023;
- indicator buckets.

I will keep these queries for context and use the relationship analysis to address the research question more directly.

## Step 5.3 — Add relationship analysis

For life expectancy, calculate relationships with:

- CO2 emissions per capita;
- unemployment rate;
- access to electricity;
- GDP per capita;
- log GDP per capita;
- population or log population where analytically justified.

For every relationship, return:

- paired observation count;
- Pearson correlation using `CORR()`;
- simple regression slope using `REGR_SLOPE()`;
- simple-model R-squared using `REGR_R2()`.

## Step 5.4 — Compare raw and log income relationships

Create a direct comparison:

| Predictor | Paired observations | Correlation with life expectancy | R-squared |
|---|---:|---:|---:|
| GDP per capita |  |  |  |
| LN(GDP per capita) |  |  |  |

I will fill in these values from the corrected PostgreSQL dataset.

## Step 5.5 — Interpret responsibly

Wording for describing the associations:

```text
was positively associated with
was negatively associated with
showed a weak/moderate/strong relationship in this dataset
```

Claims these results cannot support:

```text
caused
proved
guaranteed
```

The dataset is synthetic, so the findings demonstrate analytical methods and pipeline design rather than real-world policy evidence.

### Stage 5 exit check

- The SQL directly addresses every variable in the research question.
- Paired sample sizes appear beside statistics.
- Raw and log GDP-per-capita results are compared.
- Conclusions say association, not causation.
- All figures can be reproduced from saved SQL.

---

# Stage 6 — Refresh Tableau and publish the findings

**Goal:** Show the corrected results clearly so someone can read the findings without running SQL.

## Step 6.1 — Refresh the data source

- [ ] Connect Tableau to the corrected PostgreSQL output or a controlled export from it.
- [ ] Confirm that EUU and WLD are absent from country-level views.
- [ ] Confirm that Korea and Vietnam follow the database decision.
- [ ] Remove Tableau-only filters that were compensating for unresolved database quality issues.

## Step 6.2 — Revalidate the two existing dashboards

- [ ] Check titles, axes, units, tooltips, filters, legends, and source notes.
- [ ] Compare headline values with PostgreSQL query outputs.
- [ ] Add a visible note that the dataset is synthetic.
- [ ] Export final dashboard images.

## Step 6.3 — Add relationship visuals

I will add visuals that help answer the research question, such as:

- life expectancy versus log GDP per capita;
- life expectancy versus electricity access;
- an indicator correlation summary;
- selected trends by income group.

## Step 6.4 — Add exact findings to the README

Include:

- three to five numerical findings;
- the sample size for relationship measures;
- a concise data-quality summary;
- a limitations section;
- final dashboard screenshots;
- a Tableau Public link if published;
- links to the SQL or dbt models that produced the results.

### Stage 6 exit check

Every number in Tableau and the README agrees with the corrected PostgreSQL data.

---

# Stage 7 — Repository hygiene

**Goal:** Keep the repository complete, accurate, and easy to follow.

## Step 7.1 — Use an accurate structure

Target structure before dbt is added:

```text
world-bank-sql-data-pipeline/
├── data/
│   ├── raw/
│   ├── reference/
│   └── processed/
│       └── README.md
├── dashboard/
│   ├── README.md
│   └── images/
├── docs/
│   ├── project_evolution_and_decision_log.md
│   └── project_rebuild_master_checklist.md
├── sql/
├── scripts/
├── .gitignore
├── LICENSE
└── README.md
```

I will update the README folder tree as I add the actual folders and files.

## Step 7.2 — Add supporting files

- [ ] `.gitignore` for secrets, environments, caches, exports, and local database artifacts.
- [ ] A `LICENSE` that matches how I want the project to be used.
- [ ] `dashboard/README.md` describing the dashboards and files.
- [ ] `data/processed/README.md` explaining whether outputs are generated or committed.
- [ ] A data dictionary.
- [ ] Clear setup and SQL execution instructions.

I will add Python dependency management with the first Python component.

## Step 7.3 — Run a reviewer test

I will read through the project from a new visitor's perspective and check:

- Is the research question clear within a minute?
- Is it clear that the data is synthetic?
- Are the main findings visible without installing PostgreSQL?
- Are the instructions enough to reproduce the work?
- Does every documented folder and file exist?

### Stage 7 exit check

The README matches reality and contains no promised but missing outputs.

---

# Stage 8 — Restructure the validated SQL with dbt

**Goal:** Convert working SQL into a tested analytics engineering project.

## Step 8.1 — Map existing work to dbt

| Existing work | dbt destination |
|---|---|
| Raw PostgreSQL tables | dbt sources |
| Cleaning and casting | staging models |
| Reusable calculations | intermediate models |
| Analysis-ready tables | marts |
| Validation queries | generic and singular tests |

## Step 8.2 — Add tests

My initial tests will cover:

- unique country-year key;
- non-null keys;
- reference relationships;
- accepted ranges;
- accepted entity types;
- exclusion of EUU and WLD from country marts;
- raw-to-classification reconciliation.

## Step 8.3 — Validate dbt outputs

- [ ] `dbt build` succeeds.
- [ ] Mart row counts match the validated PostgreSQL version.
- [ ] Analytical statistics match the pre-dbt outputs.
- [ ] dbt documentation displays clear source-to-mart lineage.

### Stage 8 exit check

The dbt outputs match the validated SQL, with any differences explained in the decision log.

---

# Stage 9 — Add FastAPI

**Goal:** Provide a read-only interface to selected analytical marts.

- [ ] Define a small set of useful endpoints.
- [ ] Keep SQL out of route handlers.
- [ ] Validate request parameters and response schemas.
- [ ] Store credentials in environment variables.
- [ ] Test API outputs against the marts.
- [ ] Add API instructions to the README.

I will keep credentials private and limit the API to the intended read-only results.

---

# Stage 10 — Add Streamlit

**Goal:** Build an application for exploring the results through the API.

- [ ] Results page using FastAPI data.
- [ ] Pipeline-health page showing freshness and test status.
- [ ] Loading, empty, and error states.
- [ ] Consistent numbers across Streamlit, Tableau, README, and PostgreSQL.
- [ ] Clear synthetic-data disclosure.

---

# Stage 11 — Add Airflow

**Goal:** Orchestrate processes that already work independently.

- [ ] Load task.
- [ ] dbt build task.
- [ ] Dependencies and retries.
- [ ] Idempotent reruns.
- [ ] Failure logging.
- [ ] Scheduled execution.
- [ ] Pipeline status exposed to the application where appropriate.

I will keep Airflow deferred until the load and dbt build work reliably on their own.

---

# Stage 12 — Docker Compose and final release

**Goal:** Make the completed system reproducible.

- [ ] PostgreSQL service.
- [ ] dbt execution environment.
- [ ] FastAPI service.
- [ ] Streamlit service.
- [ ] Airflow services when ready.
- [ ] Health checks and service dependencies.
- [ ] Example environment file without secrets.
- [ ] One documented startup procedure.
- [ ] Fresh-machine reproduction test.
- [ ] Final screenshots and architecture summary.
- [ ] Version tag for the completed project.

---

# Working rules for every stage

1. I will keep the raw source data unchanged.
2. I will fix data-quality issues in the pipeline before refreshing Tableau.
3. I will use a documented, defensible rule to resolve conflicting duplicates.
4. I will publish row counts as confirmed only after checking them.
5. I will retain raw record IDs so excluded records remain traceable.
6. I will validate before and after every material change.
7. I will update the decision log when a choice changes results or architecture.
8. I will keep each commit focused on one improvement.
9. I will push once the checkpoint passes local validation.
10. I will finish each stage and pass its exit check before adding the next major tool.

---

# Immediate next action

My next step is **Stage 0**: preserve the MySQL baseline and commit the planning documents. Once that is done, I will set up PostgreSQL. The other tools will follow in the stages above.

Details I need to record before moving on:

```text
Current branch:
Current commit hash:
Git status result:
MySQL baseline tag created: Yes/No
Migration branch created: Yes/No
```

