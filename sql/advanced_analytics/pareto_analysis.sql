-- ═══════════════════════════════════════════════════════════
-- ADVANCED ANALYTICS 1: Pareto Analysis
-- Find which products drive 80% of revenue
-- ═══════════════════════════════════════════════════════════

WITH product_revenue AS (
    SELECT
        product_id,
        category,
        ROUND(SUM(total_item_value), 2)      AS product_revenue,
        COUNT(DISTINCT order_id)             AS total_orders
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
    GROUP BY product_id, category
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY product_revenue DESC) AS revenue_rank,
        SUM(product_revenue) OVER ()                AS total_revenue,
        SUM(product_revenue) OVER (
            ORDER BY product_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND CURRENT ROW)               AS cumulative_revenue
    FROM product_revenue
)
SELECT
    product_id,
    category,
    revenue_rank,
    product_revenue,
    ROUND(product_revenue / total_revenue * 100, 2)      AS pct_of_total,
    ROUND(cumulative_revenue / total_revenue * 100, 2)   AS cumulative_pct,
    CASE
        WHEN cumulative_revenue / total_revenue <= 0.80
        THEN 'TOP 80% Revenue Driver'
        ELSE 'Long Tail'
    END                                                   AS pareto_segment
FROM ranked
ORDER BY revenue_rank;


-- Category-level Pareto (cleaner for dashboard)
WITH cat_revenue AS (
    SELECT
        category,
        ROUND(SUM(total_item_value), 2)      AS revenue,
        COUNT(DISTINCT order_id)             AS orders
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
    GROUP BY category
)
SELECT
    category,
    revenue,
    orders,
    RANK() OVER (ORDER BY revenue DESC)      AS rank,
    ROUND(revenue /
          SUM(revenue) OVER () * 100, 2)     AS pct_revenue,
    ROUND(SUM(revenue) OVER (
          ORDER BY revenue DESC
          ROWS BETWEEN UNBOUNDED PRECEDING
                   AND CURRENT ROW) /
          SUM(revenue) OVER () * 100, 2)     AS cumulative_pct
FROM cat_revenue
ORDER BY revenue DESC;
-- INSIGHT TO QUOTE: 'Top X categories drive 80% of revenue'
-- Count the rows where cumulative_pct <= 80
