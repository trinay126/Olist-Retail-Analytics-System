WITH monthly AS (
    SELECT
        year,
        -- Add MONTH() extraction from order_purchase_date
        MONTH(order_purchase_date) AS month,  
        month_name,
        ROUND(SUM(total_item_value), 2) AS revenue,
        COUNT(DISTINCT order_id) AS total_orders
    FROM gold.vw_master_orders
    WHERE order_status = 'delivered'
    GROUP BY year, MONTH(order_purchase_date), month_name
)
SELECT
    CAST(year AS VARCHAR) + '-' + RIGHT('0' + CAST(month AS VARCHAR), 2) AS period,
    month_name,
    year,
    revenue,
    total_orders,
    LAG(revenue) OVER (ORDER BY year, month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY year, month))
        * 100.0 / NULLIF(LAG(revenue) OVER (ORDER BY year, month), 0) , 2) AS mom_growth_pct
FROM monthly
ORDER BY year, month;
