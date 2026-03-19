-- ═══════════════════════════════════════════════════════════
-- EDA STEP 2: Univariate Distribution Analysis
-- ═══════════════════════════════════════════════════════════

-- 2A + 2B: Price and freight statistics in ONE scan using a CTE
-- PERCENTILE_CONT is expensive — calculate all percentiles ONCE
WITH price_percentiles AS (
    SELECT
        price,
        freight_value,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price)
            OVER ()              AS p25_price,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price)
            OVER ()              AS p50_price,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price)
            OVER ()              AS p75_price,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY price)
            OVER ()              AS p95_price,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY freight_value)
            OVER ()              AS p50_freight
    FROM gold.vw_master_orders
    WHERE order_status = 'delivered'
)
SELECT
    COUNT(*)                          AS total_items,
    ROUND(MIN(price), 2)              AS min_price,
    ROUND(MAX(price), 2)              AS max_price,
    ROUND(AVG(price), 2)              AS mean_price,
    ROUND(STDEV(price), 2)            AS std_dev_price,
    ROUND(STDEV(price)/NULLIF(AVG(price),0)*100, 2) AS cv_pct,
    ROUND(MAX(p25_price), 2)          AS p25_price,
    ROUND(MAX(p50_price), 2)          AS median_price,
    ROUND(MAX(p75_price), 2)          AS p75_price,
    ROUND(MAX(p95_price), 2)          AS p95_price,
    -- Freight stats reused from same CTE scan
    ROUND(MIN(freight_value), 2)      AS min_freight,
    ROUND(MAX(freight_value), 2)      AS max_freight,
    ROUND(AVG(freight_value), 2)      AS mean_freight,
    ROUND(STDEV(freight_value), 2)    AS std_dev_freight,
    ROUND(MAX(p50_freight), 2)        AS median_freight
FROM price_percentiles;

-- 2C: Payment value distribution
WITH AggregatedPayments AS (
    SELECT 
        payment_type,
        COUNT(*) AS transactions,
        MIN(payment_value) AS min_payment,
        MAX(payment_value) AS max_payment,
        AVG(payment_value) AS avg_payment,
        STDEV(payment_value) AS std_dev
    FROM gold.vw_master_orders  -- Fixed view name
    GROUP BY payment_type
),
MedianCalc AS (
    SELECT 
        payment_type,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY payment_value) 
            OVER (PARTITION BY payment_type) AS median_payment
    FROM gold.vw_master_orders
    GROUP BY payment_type, payment_value  -- Temp grouping for median
)
SELECT 
    a.payment_type,
    a.transactions,
    ROUND(a.min_payment, 2) AS min_payment,
    ROUND(a.max_payment, 2) AS max_payment,
    ROUND(a.avg_payment, 2) AS avg_payment,
    ROUND(a.std_dev, 2) AS std_dev,
    ROUND(m.median_payment, 2) AS median_payment
FROM AggregatedPayments a
JOIN MedianCalc m ON a.payment_type = m.payment_type
ORDER BY a.transactions DESC;

-- 2D: Review score frequency distribution
SELECT
    review_score,
    COUNT(*)                                          AS review_count,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)                  AS pct_of_total,
    REPLICATE('█', COUNT(*)/500)                     AS bar_chart
FROM gold.vw_master_orders
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

-- 2E: Delivery delay distribution
SELECT
    ROUND(MIN(CAST(delivery_delay_days AS FLOAT)),1) AS min_delay,
    ROUND(MAX(CAST(delivery_delay_days AS FLOAT)),1) AS max_delay,
    ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),2) AS avg_delay,
    ROUND(STDEV(CAST(delivery_delay_days AS FLOAT)),2) AS std_dev_delay,
    SUM(CASE WHEN delivery_delay_days < 0 THEN 1 ELSE 0 END) AS early_deliveries,
    SUM(CASE WHEN delivery_delay_days = 0 THEN 1 ELSE 0 END) AS on_time_exact,
    SUM(CASE WHEN delivery_delay_days BETWEEN 1 AND 7
             THEN 1 ELSE 0 END)                      AS slightly_late,
    SUM(CASE WHEN delivery_delay_days > 7
             THEN 1 ELSE 0 END)                      AS very_late
FROM gold.vw_master_orders
WHERE delivery_delay_days IS NOT NULL
  AND order_status = 'delivered';


