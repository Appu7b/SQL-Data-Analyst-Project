/* =====================================================
   Superstore Sales Analysis  (SQL Server / T-SQL)
   Question: Where is the shop losing money?
   Table: orders (5,030 raw rows -> 5,000 after cleaning)
   ===================================================== */

USE SalesProject;
GO

/* ---------- PART 1: CLEANING ---------- */

-- 1.1 Backup the raw data (original stays safe in orders_raw)
IF OBJECT_ID('orders_raw') IS NULL
    SELECT * INTO orders_raw FROM orders;
GO

-- 1.2 Remove extra spaces from state names
UPDATE orders
SET state = TRIM(state);
GO

-- 1.3 Standardise state spelling (TEXAS / texas -> Texas)
UPDATE o
SET o.state = s.name
FROM orders o
JOIN (VALUES ('California'), ('Florida'), ('Georgia'), ('Illinois'),
             ('New York'), ('North Carolina'), ('Ohio'),
             ('Pennsylvania'), ('Texas'), ('Washington')) AS s(name)
  ON o.state = s.name;
GO

-- 1.4 Remove duplicate orders (keep one row per order_id)
WITH numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY (SELECT NULL)) AS rn
    FROM orders
)
DELETE FROM numbered
WHERE rn > 1;
GO

-- 1.5 Store discount as an exact decimal (avoids 0.2 comparison errors)
ALTER TABLE orders
ALTER COLUMN discount DECIMAL(4,2);
GO

-- 1.6 Checks: expect 5000 rows and 10 states
SELECT COUNT(*) AS total_rows FROM orders;
SELECT DISTINCT state FROM orders ORDER BY state;
GO

/* ---------- PART 2: ANALYSIS ---------- */

-- Q0: Overall totals and profit margin
SELECT SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(sales), 2) AS margin_pct
FROM orders;
GO

-- Q1: Which sub-categories lose money? (losses first)
SELECT sub_category,
       SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS margin_pct
FROM orders
GROUP BY sub_category
ORDER BY total_profit ASC;
GO

-- Q2: How do discounts affect profit?
SELECT CASE
           WHEN discount = 0   THEN '1. No discount'
           WHEN discount <= 0.2 THEN '2. Up to 20%'
           ELSE '3. Above 20%'
       END AS discount_band,
       COUNT(*)    AS orders,
       SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit
FROM orders
GROUP BY CASE
           WHEN discount = 0   THEN '1. No discount'
           WHEN discount <= 0.2 THEN '2. Up to 20%'
           ELSE '3. Above 20%'
         END
ORDER BY discount_band;
GO

-- Q3: Which states have the lowest profit margin?
SELECT state,
       SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS margin_pct
FROM orders
GROUP BY state
ORDER BY margin_pct ASC;
GO

-- Q4: Monthly sales and profit trend
SELECT LEFT(CONVERT(varchar(10), order_date, 23), 7) AS month,
       SUM(sales)  AS total_sales,
       SUM(profit) AS total_profit
FROM orders
GROUP BY LEFT(CONVERT(varchar(10), order_date, 23), 7)
ORDER BY month;
GO

-- Q5 (bonus): Rank sub-categories by profit inside each category
SELECT category,
       sub_category,
       SUM(profit) AS total_profit,
       RANK() OVER (PARTITION BY category ORDER BY SUM(profit) DESC) AS rank_in_category
FROM orders
GROUP BY category, sub_category
ORDER BY category, rank_in_category;
GO