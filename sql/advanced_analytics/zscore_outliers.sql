WITH category_stats AS (
    SELECT
        category,
        AVG(price) AS cat_mean_price,
        STDEV(price) AS cat_std_price,
        COUNT(*) AS cat_item_count
    FROM gold.vw_master_orders  -- Your view ✓
    WHERE price > 0
    GROUP BY category
    HAVING COUNT(*) >= 30
),
z_scored_items AS (
    SELECT
        m.order_id,
        m.product_id,
        m.category,           -- ✅ Qualified 'm'
        m.price,
        cs.cat_mean_price,
        cs.cat_std_price,
        ROUND((m.price - cs.cat_mean_price) /
              NULLIF(cs.cat_std_price, 0), 3) AS z_score
    FROM gold.vw_master_orders m          -- ✅ Alias 'm'
    JOIN category_stats cs ON m.category = cs.category  -- ✅ Qualified JOIN
    WHERE m.price > 0
)
SELECT
    z.category,
    z.product_id,
    z.price,
    ROUND(z.cat_mean_price, 2) AS category_avg_price,
    z.z_score,
    CASE
        WHEN z.z_score >  3 THEN 'PRICE TOO HIGH — investigate'
        WHEN z.z_score < -3 THEN 'PRICE TOO LOW  — investigate'
        WHEN z.z_score >  2 THEN 'Slightly High'
        WHEN z.z_score < -2 THEN 'Slightly Low'
        ELSE 'Normal'
    END AS price_flag
FROM z_scored_items z
WHERE ABS(z.z_score) > 2
ORDER BY ABS(z.z_score) DESC;
