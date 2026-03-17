DECLARE @dataset_end DATE = (
    SELECT MAX(order_purchase_date) FROM gold.fact_orders
);  -- Dynamic: resolves to 2018-10-17 for Olist; auto-updates on live data

SELECT
    p.product_id,
    p.category,
    COUNT(i.order_id)                                        AS total_orders,
    MAX(o.order_purchase_date)                               AS last_order_date,
    -- ISNULL handles products that were never sold (NULL date)
    ISNULL(
        DATEDIFF(DAY, MAX(o.order_purchase_date), @dataset_end),
        999)                                                 AS days_since_last_sale,
    -- ISNULL handles products with no sales (LEFT JOIN gives NULL)
    ROUND(ISNULL(SUM(i.price), 0), 2)                       AS lifetime_revenue,
    CASE
        WHEN MAX(o.order_purchase_date) IS NULL
             THEN 'NEVER SOLD'
        WHEN DATEDIFF(DAY, MAX(o.order_purchase_date),
             @dataset_end)  > 180  THEN 'DEAD STOCK'
        WHEN DATEDIFF(DAY, MAX(o.order_purchase_date),
             @dataset_end)  > 90   THEN 'SLOW MOVING'
        ELSE 'Active'
    END                                                      AS inventory_status
FROM       gold.dim_product      p
LEFT JOIN  gold.fact_order_items i  ON p.product_id = i.product_id
LEFT JOIN  gold.fact_orders      o  ON i.order_id   = o.order_id
GROUP BY p.product_id, p.category
ORDER BY days_since_last_sale DESC;
