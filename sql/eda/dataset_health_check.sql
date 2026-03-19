-- ═══════════════════════════════════════════════════════════
-- EDA STEP 1: Dataset Shape & NULL Health Check
-- Run on Silver (cleaned) tables
-- ═══════════════════════════════════════════════════════════

-- 1A: Row counts across all Silver tables
-- Row counts across Gold layer tables
SELECT 'gold.dim_customer'      AS table_name, COUNT(*) AS row_count FROM gold.dim_customer     UNION ALL
SELECT 'gold.dim_product',                     COUNT(*)              FROM gold.dim_product      UNION ALL
SELECT 'gold.dim_seller',                      COUNT(*)              FROM gold.dim_seller       UNION ALL
SELECT 'gold.dim_date',                        COUNT(*)              FROM gold.dim_date         UNION ALL
SELECT 'gold.dim_geolocation',                 COUNT(*)              FROM gold.dim_geolocation  UNION ALL
SELECT 'gold.fact_orders',                     COUNT(*)              FROM gold.fact_orders      UNION ALL
SELECT 'gold.fact_order_items',                COUNT(*)              FROM gold.fact_order_items UNION ALL
SELECT 'gold.fact_payments',                   COUNT(*)              FROM gold.fact_payments    UNION ALL
SELECT 'gold.fact_reviews',                    COUNT(*)              FROM gold.fact_reviews     UNION ALL
SELECT 'vw_master_orders',                     COUNT(*)              FROM gold.vw_master_orders;

-- 1B: NULL rates per key column in vw_master_orders
SELECT
    COUNT(*)                                                           AS total_rows,
    SUM(CASE WHEN order_status        IS NULL THEN 1 ELSE 0 END)      AS null_status,
    SUM(CASE WHEN order_purchase_date IS NULL THEN 1 ELSE 0 END)      AS null_purchase_date,
    SUM(CASE WHEN actual_delivery_date IS NULL THEN 1 ELSE 0 END)     AS null_delivery,
    SUM(CASE WHEN review_score        IS NULL THEN 1 ELSE 0 END)      AS null_review,
    SUM(CASE WHEN customer_lat        IS NULL THEN 1 ELSE 0 END)      AS null_customer_lat,
    ROUND(SUM(CASE WHEN actual_delivery_date IS NULL
              THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2)              AS null_delivery_pct,
    ROUND(SUM(CASE WHEN review_score IS NULL
              THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2)              AS null_review_pct
FROM gold.vw_master_orders;

-- 1C: Category distribution in Gold (all English now)
SELECT
    COUNT(*)                                                        AS total_products,
    SUM(CASE WHEN category = 'uncategorized' THEN 1 ELSE 0 END)    AS uncategorized_count,
    COUNT(DISTINCT category)                                        AS unique_categories,
    ROUND(SUM(CASE WHEN category = 'uncategorized'
              THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2)           AS uncategorized_pct
FROM gold.vw_master_orders;

-- 1D: Unique value counts (cardinality check)
SELECT
    COUNT(DISTINCT customer_id)          AS unique_customers,
    COUNT(DISTINCT order_id)             AS unique_orders,
    COUNT(DISTINCT product_id)           AS unique_products,
    COUNT(DISTINCT seller_id)            AS unique_sellers,
    COUNT(DISTINCT category)             AS unique_categories,
    COUNT(DISTINCT customer_state)       AS unique_customer_states,
    COUNT(*)                             AS total_view_rows
FROM gold.vw_master_orders;

-- 1E: Order status distribution
SELECT
    order_status,
    COUNT(*)                                     AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM gold.vw_master_orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 1F: Date range of the entire dataset
SELECT
    MIN(order_purchase_date)            AS earliest_order,
    MAX(order_purchase_date)            AS latest_order,
    DATEDIFF(DAY,
        MIN(order_purchase_date),
        MAX(order_purchase_date))       AS dataset_span_days,
    DATEDIFF(MONTH,
        MIN(order_purchase_date),
        MAX(order_purchase_date))       AS dataset_span_months,
    COUNT(DISTINCT
        CAST(order_purchase_date AS DATE)) AS active_days
FROM gold.vw_master_orders
WHERE order_purchase_date IS NOT NULL;

-- 1G: Orders per year (volume trend)
SELECT
    YEAR(order_purchase_date)           AS order_year,
    COUNT(*)                            AS total_orders,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2)       AS pct_of_total
FROM gold.vw_master_orders
WHERE order_purchase_date IS NOT NULL
GROUP BY YEAR(order_purchase_date)
ORDER BY order_year;

