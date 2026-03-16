USE RetailAnalytics;
GO

IF OBJECT_ID('gold.vw_master_orders','V') IS NOT NULL DROP VIEW gold.vw_master_orders;
GO

CREATE VIEW gold.vw_master_orders AS
SELECT
    -- Order identifiers
    o.order_id,
    o.order_status,
    o.order_purchase_date,
    o.actual_delivery_date,
    o.estimated_delivery_date,
    o.delivery_delay_days,
    o.delivery_status,
    -- Customer
    c.customer_id,
    c.customer_city,
    c.customer_state,
    -- Product
    p.product_id,
    p.category,
    p.product_weight_g,
    -- Seller
    s.seller_id,
    s.seller_city,
    s.seller_state,
    -- Financials
    price,
    freight_value,
    i.total_item_value,
    pay.payment_value,
    pay.payment_type,
    pay.payment_installments,
    -- Review
    review_score,
    -- Date Intelligence
    d.month_name,
    d.quarter,
    d.year,
    d.week_number,
    d.is_weekend,
    -- Geolocation (customer)
    gc.latitude                          AS customer_lat,
    gc.longitude                         AS customer_lng,
    -- Geolocation (seller)
    gs.latitude                          AS seller_lat,
    gs.longitude                         AS seller_lng
-- NOTE: gold.fact_payments aggregated first to prevent row duplication
-- Olist allows multiple payments per order (credit+voucher etc)
-- Without aggregation: 2 items × 2 payments = 4 rows (revenue inflated)
FROM       gold.fact_orders      o
JOIN       gold.dim_customer     c    ON o.customer_id             = c.customer_id
JOIN       gold.fact_order_items i    ON o.order_id                = i.order_id
JOIN       gold.dim_product      p    ON i.product_id              = p.product_id
JOIN       gold.dim_seller       s    ON i.seller_id               = s.seller_id
-- gold.fact_payments is pre-aggregated (1 row per order) — direct join safe
JOIN gold.fact_payments              pay ON o.order_id              = pay.order_id
JOIN       gold.dim_date         d    ON o.order_purchase_date     = d.date_id
LEFT JOIN  gold.fact_reviews     r    ON o.order_id                = r.order_id
LEFT JOIN  gold.dim_geolocation  gc   ON c.customer_zip_code_prefix = gc.zip_code_prefix
LEFT JOIN  gold.dim_geolocation  gs   ON s.seller_zip_code_prefix   = gs.zip_code_prefix;
GO


-- Quick test
SELECT TOP 5 * FROM gold.vw_master_orders;
