-- SQL Server does not allow column aliases in CASE WHEN of same SELECT.
-- Solution: wrap the aggregation in a CTE first.
WITH seller_base AS (
    SELECT
        seller_id,
        seller_state,
        COUNT(DISTINCT order_id)                             AS total_orders,
        SUM(CASE WHEN delivery_status = 'On Time'
                 THEN 1 ELSE 0 END)                          AS on_time,
        ROUND(SUM(CASE WHEN delivery_status = 'On Time'
                  THEN 1.0 ELSE 0 END)
              / NULLIF(COUNT(DISTINCT order_id),0)*100, 2)   AS reliability_pct,
        ROUND(AVG(CAST(delivery_delay_days AS FLOAT)),1)     AS avg_delay_days,
        ROUND(AVG(CAST(review_score AS FLOAT)),2)            AS avg_review
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
    GROUP BY seller_id, seller_state
)
SELECT *,
    RANK() OVER (ORDER BY reliability_pct DESC)              AS reliability_rank,
    CASE
        WHEN reliability_pct >= 90  THEN 'Tier 1 — Excellent'
        WHEN reliability_pct >= 75  THEN 'Tier 2 — Good'
        WHEN reliability_pct >= 60  THEN 'Tier 3 — Average'
        ELSE                             'Tier 4 — Poor'
    END                                                      AS seller_tier
FROM  seller_base
ORDER BY reliability_pct DESC;
