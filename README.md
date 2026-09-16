# World Bank SQL Data Pipeline

## Project Overview

In this project, I use SQL to clean, validate and analyse country-level development data. The raw data contains deliberate errors, so I check and clean it before using it for analysis.

I first built the project in MySQL and later converted the pipeline to PostgreSQL. I use Tableau for the visualisations.

## Research Question

How are CO₂ emissions, unemployment and access to electricity related to life expectancy? How do GDP and population relate to these indicators?

## Dataset

The dataset covers 30 countries from 2000 to 2023. It includes GDP, population, life expectancy, unemployment rate, CO₂ emissions per capita, access to electricity, country, region and income group.

This is a synthetic dataset made to resemble World Bank data. It includes missing values, duplicates, incorrect formats and inconsistent country information. The results are not official World Bank findings.

I also included a Python script that can retrieve similar indicators from the World Bank API for future work with real data.

## Project Workflow

1. **Data ingestion** - Load the raw data.
2. **Data profiling** - Find missing, duplicate and invalid values.
3. **Data cleaning** - Correct or exclude records and log the decisions.
4. **Data validation** - Check the cleaned data.
5. **Data transformation** - Prepare the data for analysis.
6. **SQL analysis** - Explore relationships between the indicators.
7. **Data visualisation** - Present the results in Tableau.

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

- `data/raw/` - Original dataset
- `data/reference/` - Country reference data
- `data/processed/` - Processed data
- `docs/` - Data dictionary and data quality notes
- `sql/` - SQL files for the pipeline and analysis
- `scripts/` - Python scripts for generating and retrieving data
- `dashboard/` - Tableau files

## Tools

PostgreSQL, pgAdmin 4, SQL, Python, pandas, Tableau, Git and GitHub. I used MySQL for the first version of the project.

## Cleaning Results

The raw table has 729 records. After cleaning, there are 718 unique country-year records. Seven records were quarantined and four duplicates were excluded.

I corrected a population error for Korea, Rep. in 2018 and recorded the change in an audit log. The raw value was kept in the raw table.

## Key Findings

- Electricity access and life expectancy had a positive correlation of 0.740.
- Countries with larger increases in electricity access from 2000 to 2023 generally had larger increases in life expectancy. The correlation was 0.737.
- GDP per capita and life expectancy had a positive correlation of 0.676 across the dataset.
- Population had weak correlations with CO₂ emissions per capita, unemployment and electricity access.

These are relationships in the synthetic data. They do not prove that one indicator caused a change in another. The conflicting Korea, Rep. 2000 duplicate also affects how its change from 2000 to 2023 should be interpreted.

## Current Progress

- [x] Project setup and data ingestion
- [x] Data profiling
- [x] Data cleaning
- [x] Data validation
- [x] Data transformation
- [x] SQL analysis
- [x] Tableau visualisations
