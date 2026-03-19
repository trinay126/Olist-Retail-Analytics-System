-- ═══════════════════════════════════════════════════════════
-- EDA STEP 3: Bivariate Relationships
-- ═══════════════════════════════════════════════════════════

-- 3A: Does high freight cost = lower review score?
WITH freight_buckets AS (
    SELECT
        order_id,
        freight_value,
        review_score,
        CASE
            WHEN freight_value < 10  THEN '1. Under R$10'
            WHEN freight_value < 25  THEN '2. R$10-25'
            WHEN freight_value < 50  THEN '3. R$25-50'
            WHEN freight_value < 100 THEN '4. R$50-100'
            ELSE                         '5. Over R$100'
        END AS freight_bucket
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
      AND review_score IS NOT NULL
)
SELECT
    freight_bucket,
    COUNT(DISTINCT order_id)                    AS order_count,
    ROUND(AVG(CAST(review_score AS FLOAT)), 3)  AS avg_review_score,
    ROUND(AVG(freight_value), 2)                AS avg_freight_value
FROM freight_buckets
GROUP BY freight_bucket
ORDER BY freight_bucket;

-- 3B: Delivery delay vs review score correlation
WITH delay_buckets AS (
    SELECT
        order_id,
        delivery_delay_days,
        review_score,
        CASE
            WHEN delivery_delay_days < 0  THEN '1. Early'
            WHEN delivery_delay_days = 0  THEN '2. On Time'
            WHEN delivery_delay_days <= 3 THEN '3. 1-3 Days Late'
            WHEN delivery_delay_days <= 7 THEN '4. 4-7 Days Late'
            ELSE                                 '5. 7+ Days Late'
        END AS delay_bucket
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
      AND review_score IS NOT NULL
)
SELECT
    delay_bucket,
    COUNT(*)                                    AS orders,
    ROUND(AVG(CAST(review_score AS FLOAT)), 3)       AS avg_review,
    ROUND(AVG(CAST(delivery_delay_days AS FLOAT)), 1) AS avg_delay_days
FROM delay_buckets
GROUP BY delay_bucket
ORDER BY delay_bucket;

-- 3C: Revenue vs freight ratio by category (bivariate)
SELECT
    category,
    COUNT(DISTINCT order_id)                         AS total_orders,
    ROUND(AVG(price), 2)                             AS avg_price,
    ROUND(AVG(freight_value), 2)                     AS avg_freight,
    ROUND(AVG(freight_value) /
          NULLIF(AVG(price), 0) * 100, 2)            AS freight_to_price_pct,
    ROUND(AVG(CAST(review_score AS FLOAT)), 2)       AS avg_review
FROM  gold.vw_master_orders
WHERE order_status = 'delivered'
  AND review_score IS NOT NULL
GROUP BY category
HAVING COUNT(DISTINCT order_id) > 100
ORDER BY freight_to_price_pct DESC;

-- 3D: Customer state vs avg order value (geographic bivariate)
SELECT
    customer_state,
    COUNT(DISTINCT order_id)                              AS total_orders,
    ROUND(AVG(total_item_value), 2)                      AS avg_item_value,
    ROUND(SUM(total_item_value), 2)                      AS total_revenue,
    ROUND(AVG(CAST(delivery_delay_days AS FLOAT)), 2)    AS avg_delay
FROM  gold.vw_master_orders
WHERE order_status = 'delivered'
GROUP BY customer_state
ORDER BY total_revenue DESC;
