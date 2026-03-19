-- IMPORTANT: Use dataset end date, NOT GETDATE().
-- Olist data ends 2018 — GETDATE() would make every customer 2800+ days old,
-- destroying RFM segmentation. @dataset_end = last order date dynamically.
DECLARE @rfm_end DATE = (SELECT MAX(order_purchase_date) FROM gold.vw_master_orders);

WITH rfm_base AS (
    SELECT
        customer_id,
        DATEDIFF(DAY, MAX(order_purchase_date), @rfm_end)    AS recency,
        COUNT(DISTINCT order_id)                             AS frequency,
        -- monetary = total item value; grain-safe on item-level view
        ROUND(SUM(total_item_value), 2)                      AS monetary
    FROM  gold.vw_master_orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
rfm_scored AS (
    SELECT *,
        -- recency ASC: lower days-since-purchase = better = higher score
        NTILE(5) OVER (ORDER BY recency   ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency     ) AS f_score,
        NTILE(5) OVER (ORDER BY monetary      ) AS m_score
    FROM rfm_base
)
SELECT *,
    (r_score + f_score + m_score)  AS rfm_total,
    CASE
        WHEN r_score >= 4 AND f_score >= 4  THEN 'Champion'
        WHEN r_score >= 3 AND f_score >= 3  THEN 'Loyal Customer'
        WHEN r_score >= 4 AND f_score <  3  THEN 'Potential Loyalist'
        WHEN r_score <= 2 AND f_score >= 3  THEN 'At Risk'
        WHEN r_score =  1                   THEN 'Lost'
        ELSE 'Needs Attention'
    END AS customer_segment
FROM  rfm_scored
ORDER BY rfm_total DESC;




