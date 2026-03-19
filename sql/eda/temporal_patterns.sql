-- ═══════════════════════════════════════════════════════════
-- EDA STEP 4: Temporal Pattern Analysis
-- ═══════════════════════════════════════════════════════════

-- 4A: Orders by day of week
SELECT
    DATENAME(WEEKDAY, order_purchase_date)  AS day_of_week,
    DATEPART(WEEKDAY, order_purchase_date)  AS day_number,
    COUNT(*)                                AS total_orders,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)         AS pct_of_total,
    REPLICATE('█', COUNT(*)/300)            AS volume_bar
FROM gold.vw_master_orders
WHERE order_purchase_date IS NOT NULL
GROUP BY
    DATENAME(WEEKDAY, order_purchase_date),
    DATEPART(WEEKDAY, order_purchase_date)
ORDER BY day_number;

-- 4B: Monthly seasonality (which month is peak?)
SELECT
    DATENAME(MONTH, order_purchase_date)    AS month_name,
    DATEPART(MONTH, order_purchase_date)    AS month_num,
    COUNT(*)                                AS total_orders,
    ROUND(AVG(total_item_value), 2)         AS avg_item_value,
    ROUND(SUM(total_item_value), 2)         AS total_revenue
FROM  gold.vw_master_orders
WHERE order_purchase_date IS NOT NULL
GROUP BY
    DATENAME(MONTH, order_purchase_date),
    DATEPART(MONTH, order_purchase_date)
ORDER BY month_num;

-- 4C: Weekend vs weekday comparison
SELECT
    CASE WHEN DATEPART(WEEKDAY, order_purchase_date) IN (1,7)
         THEN 'Weekend' ELSE 'Weekday'
    END                                     AS day_type,
    COUNT(*)                                AS total_orders,
    ROUND(AVG(total_item_value), 2)         AS avg_item_value,
    ROUND(SUM(total_item_value), 2)         AS total_revenue,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)         AS pct_of_orders
FROM  gold.vw_master_orders
WHERE order_purchase_date IS NOT NULL
GROUP BY
    CASE WHEN DATEPART(WEEKDAY, order_purchase_date) IN (1,7)
         THEN 'Weekend' ELSE 'Weekday' END;
