USE world_bank_project;

-- 1. Total number of rows
SELECT COUNT(*) AS total_rows
FROM raw_world_bank_data;

-- 2. Preview the first few rows
SELECT *
FROM raw_world_bank_data
LIMIT 10;

-- 3. Check the year range
SELECT 
    MIN(year) AS earliest_year,
    MAX(year) AS latest_year
FROM raw_world_bank_data;

-- 4. Count unique countries
SELECT COUNT(DISTINCT country_name) AS total_countries
FROM raw_world_bank_data;

-- 5. Check unique regions
SELECT DISTINCT region
FROM raw_world_bank_data
ORDER BY region;

-- 6. Check unique income groups
SELECT DISTINCT income_group
FROM raw_world_bank_data
ORDER BY income_group;