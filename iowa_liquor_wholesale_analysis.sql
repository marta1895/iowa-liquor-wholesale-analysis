-- Before I start working on the business question, I noticed that the sale_dollars column has negative values during the dataset investigation
-- It most likely not a formatting bug, and it means that the negative rows = returns from retailers back to the state distribution system. So, they're not data errors, they're real events

-- Find the number of such negative values in the datatset for whole picture
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(sale_dollars < 0) AS negative_rows,
  ROUND(COUNTIF(sale_dollars < 0) * 100.0 / COUNT(*), 2) AS pct_negative,
  SUM(CASE WHEN sale_dollars < 0 THEN sale_dollars ELSE 0 END) AS total_returns
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE date BETWEEN '2023-01-01' AND '2023-12-31';
-- Findings: Returns made up only ~0.14% of rows, totaling about $571K in 2023 
-- representing a very small share of total activity


-- Q1 - How have Iowa liquor sales changed over time?

-- Note: Iowa is a control state. This dataset shows wholesale sales from the state to retailers, not direct customer purchases
-- Seasonal trends reflect retailer stocking patterns rather than consumer demand
-- Goal: Analyze total sales by year and month since 2012, and identify growth and seasonal trends
 
 
-- 1.1. - Yearly growth with YoY change
WITH yearly_sales AS (
  SELECT
    EXTRACT(YEAR FROM date) AS sales_year,
    ROUND(SUM(sale_dollars), 2) AS total_sales
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE date >= '2012-01-01' AND date < '2026-01-01'
  GROUP BY sales_year
)
SELECT
  sales_year,
  total_sales,
  LAG(total_sales) OVER (ORDER BY sales_year) AS prev_year_sales,
  ROUND(
    (total_sales - LAG(total_sales) OVER (ORDER BY sales_year))
    / LAG(total_sales) OVER (ORDER BY sales_year) * 100,
    2
  ) AS yoy_growth_pct
FROM yearly_sales
ORDER BY sales_year;
 
-- Finding: Iowa liquor revenue grew from $255M in 2012 to $447M in 2024, 
-- with steady growth until 2019. Sales jumped by 13.6% during the 2020 COVID lockdown, 
-- while 2025 shows the first decline in the dataset at -5.0%
 
 
-- 1.2. - Monthly seasonality across all years
SELECT
  EXTRACT(YEAR FROM date) AS sales_year,
  EXTRACT(MONTH FROM date) AS sales_month,
  ROUND(SUM(sale_dollars), 2) AS total_sales
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE date >= '2012-01-01' AND date < '2026-01-01'
GROUP BY sales_year, sales_month
ORDER BY sales_year, sales_month;
 
-- Observation: October sales are consistently higher than most other months,
-- sometimes even higher than December - the holidays month
-- The next query ranks monthly sales within each year to check if this
-- pattern is consistent across all years
 
 
-- 1.3. - Verification of October's rank within each year
WITH monthly_sales AS (
  SELECT
    EXTRACT(YEAR FROM date) AS sales_year,
    EXTRACT(MONTH FROM date) AS sales_month,
    ROUND(SUM(sale_dollars), 2) AS total_sales
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE date >= '2012-01-01' AND date < '2026-01-01'
  GROUP BY sales_year, sales_month
),
ranked_months AS (
  SELECT
    sales_year,
    sales_month,
    total_sales,
    RANK() OVER (PARTITION BY sales_year ORDER BY total_sales DESC) AS rank_in_year
  FROM monthly_sales
)
SELECT
  sales_year,
  sales_month,
  total_sales,
  rank_in_year
FROM ranked_months
WHERE sales_month = 10
ORDER BY sales_year;
 
-- Confirmed: October is always among the top 3 sales months and ranks
-- #1 or #2 in 11 out of 14 years, showing a consistent seasonal trend

-- SUMMARY: October and December are the strongest wholesale sales months,
-- averaging about $34–36M. This likely reflects retailer stock increases
-- before major holiday periods. January is consistently the weakest month,
-- averaging around $24M in sales


-- Q2 - Has the category mix shifted over time?

-- 2.1. - Defining years gap for the analysis
-- I selected 2014 as a start year since by this year the dataset has been running 3+ years
-- and any ramp-up issues should be well behind
-- And 2024 as a last year, because current 2026 is incomplete yet,
-- and 2025 is a first year in dataset with decline, so i consider this year as unstable one
 
WITH category_year AS (
  -- Total bottles per category per year
  SELECT
    EXTRACT(YEAR FROM date) AS sales_year,
    category_name,
    SUM(bottles_sold) AS bottles
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE EXTRACT(YEAR FROM date) IN (2014, 2024)
    AND bottles_sold > 0           -- exclude returns
    AND category_name IS NOT NULL  -- exclude missing category
  GROUP BY sales_year, category_name
),
with_share AS (
  -- Each category's share of its year's total bottles
  SELECT
    sales_year,
    category_name,
    bottles,
    ROUND(bottles * 100.0 / SUM(bottles) OVER (PARTITION BY sales_year), 2) AS share_pct
  FROM category_year
)
 
-- Pivot to one row per category with 2014 and 2024 side by side
-- 'MAX(CASE WHEN' pulls the value from one year-row per category
-- the other row evaluates to NULL and MAX ignores it
SELECT
  category_name,
  MAX(CASE WHEN sales_year = 2014 THEN bottles END) AS bottles_2014,
  MAX(CASE WHEN sales_year = 2024 THEN bottles END) AS bottles_2024,
  MAX(CASE WHEN sales_year = 2014 THEN share_pct END) AS share_2014,
  MAX(CASE WHEN sales_year = 2024 THEN share_pct END) AS share_2024,
  -- COALESCE keeps categories that exist in only one year visible in the sort
  ROUND(
    COALESCE(MAX(CASE WHEN sales_year = 2024 THEN share_pct END), 0)
    - COALESCE(MAX(CASE WHEN sales_year = 2014 THEN share_pct END), 0),
    2
  ) AS share_change_pp
FROM with_share
GROUP BY category_name
ORDER BY share_change_pp DESC;

-- After I ran the queries above, I noticed that a lot of categories were missed in 2014 but exist in 2024, and vice versa
-- From further observation, it seems that Iowa restructured its category taxonomy

-- 2.2. - I will run the next query to find when the category restructuring happened

SELECT
  EXTRACT(YEAR FROM date) AS sales_year,
  COUNT(DISTINCT category_name) AS distinct_categories
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE date >= '2012-01-01' AND date < '2026-01-01'
  AND category_name IS NOT NULL
GROUP BY sales_year
ORDER BY sales_year;
-- Observation: The category restructuring took place in 2017.
-- In 2016, both old and new category systems were used at the same time,
-- with the full transition completed in 2017.
-- To make the comparison accurate, the analysis was changed to 2018 vs 2024.
-- This is confirmed by the big jump in distinct categories

-- 2.3. - Updated years gap analysis (2018 vs. 2024)

WITH category_year AS (
  -- Total bottles per category per year
  SELECT
    EXTRACT(YEAR FROM date) AS sales_year,
    category_name,
    SUM(bottles_sold) AS bottles
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE EXTRACT(YEAR FROM date) IN (2018, 2024)
    AND bottles_sold > 0           -- exclude returns
    AND category_name IS NOT NULL  -- exclude missing category
  GROUP BY sales_year, category_name
),
with_share AS (
  -- Each category's share of its year's total bottles
  SELECT
    sales_year,
    category_name,
    bottles,
    ROUND(bottles * 100.0 / SUM(bottles) OVER (PARTITION BY sales_year), 2) AS share_pct
  FROM category_year
)
 
-- Pivot to one row per category with 2018 and 2024 side by side
-- 'MAX(CASE WHEN' pulls the value from one year-row per category
-- the other row evaluates to NULL and MAX ignores it
SELECT
  category_name,
  MAX(CASE WHEN sales_year = 2018 THEN bottles END) AS bottles_2018,
  MAX(CASE WHEN sales_year = 2024 THEN bottles END) AS bottles_2024,
  MAX(CASE WHEN sales_year = 2018 THEN share_pct END) AS share_2018,
  MAX(CASE WHEN sales_year = 2024 THEN share_pct END) AS share_2024,
  -- COALESCE keeps categories that exist in only one year visible in the sort
  ROUND(
    COALESCE(MAX(CASE WHEN sales_year = 2024 THEN share_pct END), 0)
    - COALESCE(MAX(CASE WHEN sales_year = 2018 THEN share_pct END), 0),
    2
  ) AS share_change_pp
FROM with_share
GROUP BY category_name
ORDER BY share_change_pp DESC;
-- SUMMARY: Between 2018 and 2024, WHISKEY LIQUEUR showed the biggest growth
-- (+8.87%), while AMERICAN CORDIALS & LIQUEURS had the largest decline (-3.34%)
-- Premium spirits like tequila and bourbon gained market share, while
-- imported vodkas and sweet liqueurs lost share


-- Q3 (CORE) - Where does revenue concentrate?

-- Goal: Rank Iowa counties by total sales and per-store sales. How concentrated is revenue, is it driven by a handful of counties or spread evenly?

WITH county_sales AS (
  SELECT
    county,
    ROUND(SUM(sale_dollars), 2) AS total_sales,
    COUNT(DISTINCT store_number) AS store_cnt
  FROM `bigquery-public-data.iowa_liquor_sales.sales`
  WHERE date >= '2012-01-01' AND date < '2026-01-01'
    AND sale_dollars > 0           -- exclude returns
    AND county IS NOT NULL         -- exclude missing county
  GROUP BY county
)
SELECT
  RANK() OVER (ORDER BY total_sales DESC) AS county_rank,
  county,
  total_sales,
  store_cnt,
  ROUND(total_sales / store_cnt, 2) AS sales_per_store,
  ROUND(
    SUM(total_sales) OVER (ORDER BY total_sales DESC)
    * 100.0 / SUM(total_sales) OVER (),
    2
  ) AS cumulative_pct_of_statewide
FROM county_sales
ORDER BY total_sales DESC
LIMIT 20;
-- SUMMARY: Iowa liquor revenue is heavily concentrated. 
-- Polk County alone drives 22.9% of statewide revenue; the top 5 counties cover ~50%,
-- and the top 20 capture ~78% out of 99 counties total 
-- College-town counties like Johnson (Iowa City) also stand out for outsized per-store revenue


-- Q4 - Are there meaningful price tiers, and do categories price differently?

-- Note: state_bottle_retail is the wholesale price charged by Iowa
-- (the state distributor) to retailers, not the consumer retail price.

SELECT
  category_name,
  COUNT(*) AS transactions,
  ROUND(AVG(state_bottle_retail), 2) AS mean_price,
  ROUND(STDDEV(state_bottle_retail), 2) AS stddev_price,
  APPROX_QUANTILES(state_bottle_retail, 100)[OFFSET(25)] AS p25,
  APPROX_QUANTILES(state_bottle_retail, 100)[OFFSET(50)] AS median_price,
  APPROX_QUANTILES(state_bottle_retail, 100)[OFFSET(75)] AS p75
FROM `bigquery-public-data.iowa_liquor_sales.sales`
WHERE EXTRACT(YEAR FROM date) = 2024  -- single recent year (2025 anomalous,
                                      -- 2026 incomplete), avoids price inflation 
                                      -- across multi-year window
  AND state_bottle_retail > 0         -- exclude returns and zero-priced rows
  AND category_name IS NOT NULL       -- exclude missing category
GROUP BY category_name
ORDER BY median_price DESC;

-- APPROACH: 44 categories in the output. To test whether premium and value
-- tiers really do price differently, I picked one high-performer and one
-- low-performer for a t-test
-- For the t-test, I selected SINGLE MALT SCOTCH from the top 10 (one of the
-- highest-priced categories) and AMERICAN VODKAS from the bottom 10. I picked
-- American Vodkas specifically because, despite an enormous transaction number (403,838),
-- its mean, median, and quartile prices are all extremely low,
-- making it the clearest "value" category to test against a "premium" one

-- SUMMARY: Single Malt Scotch wholesales at $67.59 per bottle on average, roughly 6× the $10.64 
-- price of American Vodkas. The difference is statistically significant (p < 0.001), confirming 
-- a clear premium-vs-value pricing tier in Iowa's wholesale liquor market