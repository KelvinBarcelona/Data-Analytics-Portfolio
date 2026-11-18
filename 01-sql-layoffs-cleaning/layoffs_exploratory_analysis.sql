-- =====================================================================
-- PROJECT:  World Layoffs - Exploratory Data Analysis (EDA)
-- AUTHOR:   Kelvin Barcelona
-- TOOL:     MySQL Workbench (MySQL 8)
-- TABLE:    layoffs_staging2 (the cleaned table from
--           layoffs_data_cleaning.sql)
--
-- GOAL:     Explore the cleaned data to find which companies, industries,
--           countries, and time periods were hit hardest by layoffs.
--
-- QUESTIONS THIS SCRIPT ANSWERS:
--   1. How big were the biggest layoffs?
--   2. Which companies, industries, countries, and funding stages had
--      the most layoffs?
--   3. What time period does the data cover?
--   4. How did layoffs change by year and by month?
--   5. Which companies had the most layoffs in each year?
--
-- NOTE:     The "-- FINDING:" lines under the queries summarize what
--           each result showed.
-- =====================================================================

-- Quick look at the cleaned data
SELECT *
FROM layoffs_staging2;


-- =====================================================================
-- 1. SIZE OF THE LAYOFFS
-- =====================================================================

-- Largest single layoff and the highest percentage laid off
SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;
-- FINDING: The largest single layoff was 12,000 employees, and some companies laid off 100% of their staff.

-- Companies that laid off 100% of their staff (percentage_laid_off = 1),
-- sorted by how much funding they had raised
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;


-- =====================================================================
-- 2. TOTAL LAYOFFS BY CATEGORY
-- =====================================================================

-- By company
SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;
-- FINDING: The top 3 companies by total layoffs were Amazon (18,150), Google (12,000), and Meta (11,000).

-- By industry
SELECT industry, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;
-- FINDING: Consumer (45,182), Retail (43,613) and Transportation (33,748) had the most layoffs among named industries ("Other" at 36,289 is a catch-all category).

-- By country
SELECT country, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;
-- FINDING: The United States had 256,559 layoffs (about 67% of the total), far ahead of India (35,993) and the Netherlands (17,220).

-- By funding stage
SELECT stage, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;
-- FINDING: Post-IPO companies accounted for 204,132 layoffs (about 53% of the total), far more than any other stage.

-- Average percentage of staff laid off, per company
SELECT company, AVG(percentage_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;


-- =====================================================================
-- 3. TIME PERIOD COVERED
-- =====================================================================

-- First and last date in the dataset
SELECT MIN(`date`), MAX(`date`)
FROM layoffs_staging2;
-- FINDING: The data runs from 2020-03-11 to 2023-03-06. 2023 covers only about 2 months, yet already has 125,677 layoffs, far faster than 2022's pace.


-- =====================================================================
-- 4. LAYOFFS OVER TIME
-- =====================================================================

-- Total layoffs per year
SELECT YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;
-- FINDING: Layoffs peaked in 2022 (160,661 employees) and were lowest in 2021 (15,823 employees). 2023 already reached 125,677 in only the first two months of the year (the data ends on 2023-03-06).

-- Total layoffs per month (format: YYYY-MM)
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off)
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC;

-- Rolling total: add each month's layoffs to the running total.
-- A CTE calculates the monthly totals first, then a window function
-- SUM() OVER (ORDER BY ...) keeps the running sum.
WITH Rolling_Total AS
(
SELECT SUBSTRING(`date`,1,7) AS `MONTH`, SUM(total_laid_off) AS total_off
FROM layoffs_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
)
SELECT `MONTH`, total_off,
SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total
FROM Rolling_Total;
-- FINDING: Layoffs spiked in March-May 2020 (62,142, about 77% of that year's total). The running total reached 383,159 by 2023-03. The biggest single month was 2023-01 (84,714).


-- =====================================================================
-- 5. TOP COMPANIES PER YEAR
-- =====================================================================

-- Total layoffs per company per year
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC;

-- Rank companies within each year by layoffs and keep the top 5.
-- Two CTEs: (1) total per company per year, (2) rank within each year.
-- DENSE_RANK() gives tied companies the same rank without skipping numbers.
WITH Company_Year (company, years, total_laid_off) AS
(
SELECT company, YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
),
Company_Year_Rank AS
(
SELECT *, DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
FROM Company_Year
WHERE years IS NOT NULL
)
SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5;
-- FINDING: The #1 company by layoffs was Uber in 2020 (7,525), Bytedance in 2021 (3,600), Meta in 2022 (11,000), and Google in 2023 (12,000).
