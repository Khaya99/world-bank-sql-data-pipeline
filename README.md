# World Bank SQL Data Pipeline

## Project Overview

This project focuses on building a SQL data pipeline to clean, validate and analyse economic and development data.

The dataset contains country-level indicators covering GDP, population, life expectancy, unemployment, CO₂ emissions and access to electricity.

The project starts with deliberately messy raw data so that data quality issues can be identified and handled before performing the final analysis.

## Research Question

Do CO₂ emissions per capita, unemployment rate and access to electricity explain variation in life expectancy, and how do GDP and population relate to each?

## Dataset

The dataset covers 30 countries from 2000 to 2023 and includes:

- GDP (current USD)
- Population
- Life expectancy
- Unemployment rate
- CO₂ emissions per capita
- Access to electricity
- Country
- Region
- Income group

The dataset is synthetically generated and designed to resemble World Bank development data. It contains deliberate data quality problems such as missing values, duplicates, incorrect formats, invalid values and inconsistent country information.

A Python script is also included to retrieve corresponding indicators from the World Bank World Development Indicators API for future use with real data.

## Project Workflow

1. **Data ingestion** - Load the raw dataset into MySQL
2. **Data profiling** - Identify missing, duplicate, inconsistent and invalid values
3. **Data cleaning** - Fix the identified data quality issues
4. **Data validation** - Check data against defined rules and reference data
5. **Data transformation** - Prepare the data for analysis
6. **SQL analysis** - Use SQL queries to identify relationships
7. **Data visualisation** - Use Tableau to visualise the analysis

## Repository Structure

```text
world-bank-sql-data-pipeline/
  data/
    raw/
    reference/
    processed/
  docs/
  sql/
  scripts/
  dashboard/
  README.md
```

## Folder Description

- **data/raw/** - Original raw dataset
- **data/reference/** - Country reference data used for validation
- **data/processed/** - Cleaned and transformed data
- **docs/** - Data dictionary and data quality documentation
- **sql/** - SQL queries used for profiling, cleaning, validation and analysis
- **scripts/** - Python scripts for dataset generation and API data retrieval
- **dashboard/** - Tableau dashboard and visualisation files
- **README.md** - Overview and documentation of the project

## Tools

- MySQL
- SQL
- Python
- Pandas
- Tableau
- Git
- GitHub
- World Bank API

## Current Progress

## Current Progress

* [x] **Phase 1: Project Setup** - Created the repository structure and added the source files.
* [x] **Phase 2: Data Ingestion** - Created the MySQL database and raw table, then loaded the raw dataset.
* [x] **Phase 3: Data Profiling** - Examined the data for missing values, duplicates, invalid values and inconsistencies against the country reference data.
* [ ] **Phase 4: Data Cleaning** - Clean and standardise the identified data quality issues.
* [ ] **Phase 5: Data Validation** - Confirm that the cleaned data meets the required quality rules.
* [ ] **Phase 6: Data Transformation** - Prepare the cleaned data and create derived metrics for analysis.
* [ ] **Phase 7: SQL Analysis** - Analyse relationships between the economic and development indicators.
* [ ] **Phase 8: Data Visualisation** - Build Tableau visualisations to present the findings.
