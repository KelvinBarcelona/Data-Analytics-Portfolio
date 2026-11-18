-- =====================================================================
-- PROJECT:  World Layoffs - Data Cleaning
-- AUTHOR:   Kelvin Barcelona
-- TOOL:     MySQL Workbench (MySQL 8)
-- DATASET:  layoffs (raw table in the world_layoffs schema)
--
-- GOAL:     Turn the raw layoffs data into a clean table that is ready
--           for analysis, without ever touching the raw table.
--
-- STEPS:    1. Create staging tables (protect the raw data)
--           2. Remove duplicates
--           3. Standardize the data
--           4. Handle NULL and blank values
--           5. Remove unnecessary rows and columns
-- =====================================================================

-- Quick look at the raw data
SELECT *
FROM layoffs;

-- Row count BEFORE cleaning
SELECT COUNT(*) AS raw_row_count
FROM layoffs;


-- =====================================================================
-- STEP 1: CREATE A STAGING TABLE
-- Work on a copy so the raw data stays untouched if something goes wrong.
-- =====================================================================

-- Optional: uncomment these two lines to re-run the whole script from scratch
-- DROP TABLE IF EXISTS layoffs_staging2;
-- DROP TABLE IF EXISTS layoffs_staging;

-- Create an empty table with the same structure as the raw table
CREATE TABLE layoffs_staging
LIKE layoffs;

-- Copy all rows from the raw table into the staging table
INSERT layoffs_staging
SELECT *
FROM layoffs;


-- =====================================================================
-- STEP 2: REMOVE DUPLICATES
-- The table has no unique ID, so we number identical rows with
-- ROW_NUMBER(). Any row numbered 2 or higher is a duplicate.
-- =====================================================================

-- Preview: add a row_num column that counts identical rows
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off,
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- Use a CTE to list only the duplicate rows (row_num > 1)
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off,
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- MySQL can't DELETE directly from a CTE, so create a second staging
-- table that has the row_num column built in.
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Fill it with the staging data plus the row_num column
INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY company, location, industry, total_laid_off,
percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

-- Delete the duplicates
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Verify: count the unique rows in the staging copy.
-- Duplicates removed = raw rows - unique rows
-- Result: 2,361 raw rows - 2,356 unique rows = 5 duplicates removed
SELECT COUNT(*) AS unique_rows
FROM (SELECT DISTINCT * FROM layoffs_staging) AS t;


-- =====================================================================
-- STEP 3: STANDARDIZE THE DATA
-- Find inconsistencies column by column and fix them.
-- =====================================================================

-- 3a. company: remove extra spaces at the start and end
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- 3b. industry: "Crypto" and "Crypto Currency" are the same industry
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- 3c. location: checked all distinct values, no issues found
SELECT DISTINCT location
FROM layoffs_staging2;

-- 3d. country: some rows say "United States." with a trailing period
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- 3e. date: convert the text (m/d/Y) into a real DATE
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Change the column's data type from TEXT to DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


-- =====================================================================
-- STEP 4: HANDLE NULL AND BLANK VALUES
-- Where possible, fill the gaps using other rows of the same company.
-- =====================================================================

-- Rows with no layoff information at all (handled in Step 5)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Convert blank industry values to NULL so they are handled consistently
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Check which rows have a missing industry (before the fix)
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
OR industry = '';

-- Self join: find rows with a missing industry where the same company
-- has an industry filled in on another row
SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- Fill the missing industry using the matching company's industry
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Re-check after the fix: any rows left here belong to companies that
-- appear only once, so there is no other row to copy an industry from
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;


-- =====================================================================
-- STEP 5: REMOVE UNNECESSARY ROWS AND COLUMNS
-- =====================================================================

-- Rows with neither total_laid_off nor percentage_laid_off can't be used
-- for layoff analysis, so we remove them.
-- Review them first:
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Drop the helper column we only needed for finding duplicates
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- =====================================================================
-- FINAL CHECK
-- =====================================================================

-- Cleaned data
SELECT *
FROM layoffs_staging2;

-- Row count AFTER cleaning
-- Result: 2,361 raw rows -> 2,356 after removing 5 duplicates
--         -> 1,995 after removing 361 rows with no layoff data
SELECT COUNT(*) AS clean_row_count
FROM layoffs_staging2;