USE world_bank_project;

CREATE TABLE raw_world_bank_data (
    country_name VARCHAR(255),
    country_code VARCHAR(50),
    region VARCHAR(255),
    income_group VARCHAR(255),
    year VARCHAR(50),
    gdp_usd VARCHAR(255),
    population VARCHAR(255),
    life_expectancy VARCHAR(255),
    unemployment_rate VARCHAR(255),
    co2_emissions_per_capita VARCHAR(255),
    access_to_electricity_pct VARCHAR(255),
    source_file VARCHAR(255),
    ingested_at VARCHAR(255)
);