-- 1. Drop existing table
DROP TABLE IF EXISTS gold.dim_date;

-- 2. Recreate with explicit schema (date_id NOT NULL)
CREATE TABLE gold.dim_date (
    date_id DATE NOT NULL,
    day TINYINT,
    month TINYINT,
    month_name VARCHAR(20),
    quarter TINYINT,
    year SMALLINT,
    week_number TINYINT,
    is_weekend BIT,
    is_month_end BIT,
    is_quarter_start BIT,
    day_name VARCHAR(20),
    day_of_week_num TINYINT,
    fiscal_year SMALLINT,
    fiscal_quarter TINYINT,
    is_holiday BIT,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_id)
);

-- 3. Populate
WITH numbers AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a1 CROSS JOIN sys.all_objects a2
),
date_range AS (
    SELECT DATEADD(DAY, n, CAST('2016-01-01' AS DATE)) AS date_id
    FROM numbers 
    WHERE n <= DATEDIFF(DAY, '2016-01-01', '2018-12-31')
)
INSERT INTO gold.dim_date
SELECT
    date_id,
    DAY(date_id), MONTH(date_id), DATENAME(MONTH, date_id),
    DATEPART(QUARTER, date_id), YEAR(date_id), DATEPART(WEEK, date_id),
    CASE WHEN DATEPART(WEEKDAY, date_id) IN (1,7) THEN 1 ELSE 0 END,
    CASE WHEN date_id = EOMONTH(date_id) THEN 1 ELSE 0 END,
    CASE WHEN DAY(date_id) = 1 AND MONTH(date_id) IN (1,4,7,10) THEN 1 ELSE 0 END,
    DATENAME(WEEKDAY, date_id), DATEPART(WEEKDAY, date_id),
    YEAR(date_id), DATEPART(QUARTER, date_id),
    CASE 
        WHEN date_id IN ('2016-01-01','2016-04-21','2016-05-01','2016-09-07','2016-10-12',
                         '2016-11-02','2016-11-15','2016-12-25','2017-01-01','2017-04-21',
                         '2017-05-01','2017-09-07','2017-10-12','2017-11-02','2017-11-15',
                         '2017-12-25','2018-01-01','2018-04-21','2018-05-01','2018-09-07',
                         '2018-10-12','2018-11-02','2018-11-15','2018-12-25') THEN 1 
        ELSE 0 
    END
FROM date_range;

PRINT 'gold.dim_date created: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows (1,096 total)';

-- GOLD LAYER: Star Schema
IF OBJECT_ID('gold.fact_order_items',  'U') IS NOT NULL DROP TABLE gold.fact_order_items;
IF OBJECT_ID('gold.fact_payments',     'U') IS NOT NULL DROP TABLE gold.fact_payments;
IF OBJECT_ID('gold.fact_reviews',      'U') IS NOT NULL DROP TABLE gold.fact_reviews;
IF OBJECT_ID('gold.fact_orders',       'U') IS NOT NULL DROP TABLE gold.fact_orders;
IF OBJECT_ID('gold.dim_customer',      'U') IS NOT NULL DROP TABLE gold.dim_customer;
IF OBJECT_ID('gold.dim_product',       'U') IS NOT NULL DROP TABLE gold.dim_product;
IF OBJECT_ID('gold.dim_seller',        'U') IS NOT NULL DROP TABLE gold.dim_seller;
IF OBJECT_ID('gold.dim_geolocation',   'U') IS NOT NULL DROP TABLE gold.dim_geolocation;
GO

-- Dimension: Customer (includes zip_code_prefix for geolocation join)
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
INTO gold.dim_customer
FROM silver.slv_customers
WHERE customer_id IS NOT NULL;

ALTER TABLE gold.dim_customer ADD CONSTRAINT PK_dim_customer PRIMARY KEY (customer_id);


-- Dimension: Product
SELECT DISTINCT
    product_id,
    product_category_name AS category,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
INTO gold.dim_product
FROM silver.slv_products
WHERE product_id IS NOT NULL;

ALTER TABLE gold.dim_product ADD CONSTRAINT PK_dim_product PRIMARY KEY (product_id);


-- Dimension: Seller (includes zip_code_prefix for geolocation join)
SELECT DISTINCT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
INTO gold.dim_seller
FROM silver.slv_sellers
WHERE seller_id IS NOT NULL;

ALTER TABLE gold.dim_seller ADD CONSTRAINT PK_dim_seller PRIMARY KEY (seller_id);


-- ── GEOLOCATION (3 problems to solve) ──────────────────────
-- Problem 1: Encoding corruption — city names like 'sÃ£o paulo'
--            UTF-8 bytes read as Latin-1 → fix with REPLACE chain
-- Problem 2: Duplicate zip codes — same zip has 3-5 different rows
--            Fix with ROW_NUMBER() PARTITION BY zip_code_prefix
-- Problem 3: Mixed case cities — some 'sao paulo', some 'SAO PAULO'
--            Fix with UPPER() after encoding repair

-- Step 1: Create a helper function for encoding fix
-- (We use an inline REPLACE chain — no function needed)

-- Silver already fixed encoding + cast types
-- Gold only needs to deduplicate (1 row per zip code)
SELECT
TRIM(geolocation_zip_code_prefix)   AS zip_code_prefix,
ROUND(AVG(geolocation_lat), 6)          AS latitude,
ROUND(AVG(geolocation_lng), 6)          AS longitude,
MAX(geolocation_city)                   AS city,
MAX(geolocation_state)                  AS state
INTO gold.dim_geolocation
FROM silver.slv_geolocation
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND TRIM(geolocation_zip_code_prefix) <> ''
  AND geolocation_lat IS NOT NULL
  AND geolocation_lng IS NOT NULL
GROUP BY TRIM(geolocation_zip_code_prefix);

DELETE FROM gold.dim_geolocation WHERE zip_code_prefix IS NULL;

ALTER TABLE gold.dim_geolocation 
ALTER COLUMN zip_code_prefix VARCHAR(10) NOT NULL;

ALTER TABLE gold.dim_geolocation 
ADD CONSTRAINT PK_dim_geolocation PRIMARY KEY (zip_code_prefix);

-- VERIFY encoding fix worked:
SELECT TOP 20
    zip_code_prefix, city, state, latitude, longitude
FROM gold.dim_geolocation
WHERE city LIKE '%Ã%'    -- should return 0 rows if fix worked
ORDER BY zip_code_prefix;

-- VERIFY row count (should be ~19,015 unique zip codes):
SELECT COUNT(*) AS unique_zip_codes FROM gold.dim_geolocation;

-- Fact: Orders (core fact table)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_date,
    o.order_delivered_customer_date   AS actual_delivery_date,
    o.order_estimated_delivery_date   AS estimated_delivery_date,
    DATEDIFF(DAY,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date) AS delivery_delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
        THEN 'Pending'
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
        THEN 'On Time'
        ELSE 'Late'
    END                          AS delivery_status
INTO gold.fact_orders
FROM silver.slv_orders o
WHERE o.order_id IS NOT NULL;

ALTER TABLE gold.fact_orders ADD CONSTRAINT PK_fact_orders PRIMARY KEY (order_id);

-- Fact: Order Items
SELECT
    i.order_id,
    i.order_item_id,
    product_id,
    i.seller_id,
    price,
    freight_value,
    (i.price + i.freight_value)  AS total_item_value
INTO gold.fact_order_items
FROM silver.slv_order_items i
WHERE i.order_id IN (SELECT order_id FROM gold.fact_orders);


-- Fact: Payments (aggregated to prevent fan-out duplication)
-- Olist allows multiple payments per order (credit_card + voucher etc)
-- Aggregating here means the view join is always 1-to-1 with orders
SELECT
    p.order_id,
    SUM(p.payment_value)                      AS payment_value,
    -- STRING_AGG shows full payment mix (e.g. 'credit_card,voucher')
    -- Preserves info when order paid by multiple methods
    -- STRING_AGG here: one order may have credit_card + voucher combined
    -- STRING_AGG(DISTINCT ...) prevents credit_card,credit_card,voucher duplicates
    -- Use below for SQL Server 2022+; or wrap in subquery to dedup first
    STRING_AGG(p.payment_type, ',') WITHIN GROUP (ORDER BY p.payment_type) AS payment_type,
    MAX(p.payment_installments)                 AS payment_installments,
    COUNT(*)                                    AS payment_count
INTO gold.fact_payments
FROM silver.slv_payments p
WHERE p.order_id IN (SELECT order_id FROM gold.fact_orders)
GROUP BY p.order_id;


-- Fact: Reviews (aggregated to order grain — prevents LEFT JOIN duplication)
-- Some orders have multiple reviews; AVG gives a fair combined score
SELECT
    order_id,
    ROUND(AVG(CAST(review_score AS FLOAT)), 2)  AS review_score,
    MIN(review_creation_date)                    AS review_creation_date
INTO gold.fact_reviews
FROM silver.slv_reviews
WHERE order_id IN (SELECT order_id FROM gold.fact_orders)
GROUP BY order_id;

PRINT 'Gold star schema created successfully.';

-- ── PERFORMANCE INDEXES ─────────────────────────────────
-- Critical for vw_master_orders performance with 100K+ rows
CREATE INDEX idx_fact_orders_customer
    ON gold.fact_orders(customer_id);
CREATE INDEX idx_fact_orders_date
    ON gold.fact_orders(order_purchase_date);
CREATE INDEX idx_fact_orders_status
    ON gold.fact_orders(order_status);
CREATE INDEX idx_fact_items_product
    ON gold.fact_order_items(product_id);
CREATE INDEX idx_fact_items_order
    ON gold.fact_order_items(order_id);
CREATE INDEX idx_fact_items_seller
    ON gold.fact_order_items(seller_id);
CREATE INDEX idx_fact_payments_order
    ON gold.fact_payments(order_id);
CREATE INDEX idx_fact_reviews_order
    ON gold.fact_reviews(order_id);
CREATE INDEX idx_dim_geo_zip
    ON gold.dim_geolocation(zip_code_prefix);



-- Indexes on dimension tables (for JOIN performance)
CREATE INDEX idx_dim_customer_id
    ON gold.dim_customer(customer_id);
CREATE INDEX idx_dim_product_id
    ON gold.dim_product(product_id);
CREATE INDEX idx_dim_seller_id
    ON gold.dim_seller(seller_id);
CREATE INDEX idx_dim_date_id
    ON gold.dim_date(date_id);

-- Clustered indexes: physically sort the table by most-used range scan column
-- Dramatically speeds up date-range queries on large fact tables
CREATE CLUSTERED INDEX cix_fact_orders_date
    ON gold.fact_orders(order_purchase_date);
CREATE CLUSTERED INDEX cix_fact_items_order
    ON gold.fact_order_items(order_id);

CREATE INDEX idx_fact_orders_date_customer
    ON gold.fact_orders(order_purchase_date, customer_id);
    -- Composite: covers date-range + customer filter in one scan

PRINT 'All indexes created (non-clustered + clustered + composite).'
