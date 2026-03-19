-- ═══════════════════════════════════════════════════════════
-- EDA STEP 5: Statistical Outlier Detection
-- Z-Score: values beyond ±3 standard deviations
-- ═══════════════════════════════════════════════════════════

WITH price_stats AS (
    SELECT
        AVG(price)   AS mean_price,
        STDEV(price) AS std_price
    FROM gold.vw_master_orders
    WHERE price > 0
),
z_scored AS (
    SELECT
        order_id,
        product_id,
        price,
        category          AS category,
        s.mean_price,
        s.std_price,
        ROUND((price - s.mean_price) /
              NULLIF(s.std_price, 0), 3) AS z_score
    FROM  gold.vw_master_orders
    CROSS JOIN price_stats s
    WHERE price > 0
)
SELECT
    order_id,
    product_id,
    category,
    price,
    ROUND(mean_price, 2)                AS dataset_mean,
    z_score,
    CASE
        WHEN ABS(z_score) > 3 THEN 'EXTREME OUTLIER'
        WHEN ABS(z_score) > 2 THEN 'Moderate Outlier'
        ELSE 'Normal'
    END                                 AS outlier_flag
FROM z_scored
WHERE ABS(z_score) > 2
ORDER BY ABS(z_score) DESC;


-- IQR Method: outliers below Q1-1.5*IQR or above Q3+1.5*IQR
WITH iqr_stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY freight_value) OVER () AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY freight_value) OVER () AS q3
    FROM gold.vw_master_orders
    WHERE freight_value > 0
),
bounds AS (
    SELECT DISTINCT
        q1,
        q3,
        q3 - q1                          AS iqr,
        q1 - 1.5 * (q3 - q1)            AS lower_bound,
        q3 + 1.5 * (q3 - q1)            AS upper_bound
    FROM iqr_stats
)
SELECT
    order_id,
    freight_value,
    b.lower_bound,
    b.upper_bound,
    CASE
        WHEN freight_value > b.upper_bound THEN 'HIGH OUTLIER'
        WHEN freight_value < b.lower_bound THEN 'LOW OUTLIER'
        ELSE 'Normal'
    END                                  AS freight_outlier_flag
FROM  gold.vw_master_orders
CROSS JOIN bounds b
WHERE freight_value > b.upper_bound
   OR freight_value < b.lower_bound
ORDER BY freight_value DESC;
