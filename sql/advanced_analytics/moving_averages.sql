-- ═══════════════════════════════════════════════════════════
-- ADVANCED ANALYTICS 3: Moving Averages
-- 7-day and 30-day rolling averages on daily order volume
-- Uses ROWS BETWEEN window frame
-- ═══════════════════════════════════════════════════════════

WITH daily_orders AS (
    SELECT
        order_purchase_date                  AS order_date,
        COUNT(DISTINCT order_id)             AS daily_orders,
        ROUND(SUM(total_item_value), 2)      AS daily_revenue
    FROM  gold.vw_master_orders
    WHERE order_purchase_date IS NOT NULL
    GROUP BY order_purchase_date
)
SELECT
    order_date,
    daily_orders,
    daily_revenue,
    -- 7-day rolling average (smooths weekly patterns)
    ROUND(AVG(CAST(daily_orders AS FLOAT)) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS rolling_7d_orders,
    -- 30-day rolling average (shows monthly momentum)
    ROUND(AVG(CAST(daily_orders AS FLOAT)) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 1) AS rolling_30d_orders,
    -- 7-day rolling revenue
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2)  AS rolling_7d_revenue,
    -- Running total
    SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW)                       AS cumulative_revenue
FROM daily_orders
ORDER BY order_date;
-- Export this result to Power BI for the trend line visual



