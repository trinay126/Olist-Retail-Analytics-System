USE RetailAnalytics;
GO

    -- customers
        WITH deduped_customers AS (
            SELECT *,
                ROW_NUMBER() OVER(
                    PARTITION BY customer_id 
                    ORDER BY customer_unique_id DESC
                ) AS rn
            FROM bronze.stg_customers
            WHERE customer_id IS NOT NULL 
              AND LTRIM(RTRIM(CAST(customer_id AS VARCHAR(50)))) <> ''
        )
        INSERT INTO silver.slv_customers
        SELECT
            customer_id,
            customer_unique_id,
            NULLIF(LTRIM(RTRIM(CAST(customer_zip_code_prefix AS VARCHAR(20))), ''), '') AS customer_zip_code_prefix,
            UPPER(LTRIM(RTRIM(CAST(customer_city AS VARCHAR(100))))) AS customer_city,
            UPPER(LEFT(LTRIM(RTRIM(CAST(customer_state AS VARCHAR(10)))), 2)) AS customer_state
        FROM deduped_customers
        WHERE rn = 1;

    -- ── PRODUCTS (with category translation + NULL imputation) ─
    -- STEP 1: Add the 2 missing translations into bronze.stg_category
    -- (pc_gamer and portateis_cozinha not in translation CSV)
        INSERT INTO bronze.stg_category (product_category_name, product_category_name_english)
        SELECT 'pc_gamer', 'pc_gamer'
        WHERE NOT EXISTS (
            SELECT 1 FROM bronze.stg_category
            WHERE product_category_name = 'pc_gamer'
        );

        INSERT INTO bronze.stg_category (product_category_name, product_category_name_english)
        SELECT 'portateis_cozinha_e_preparadores_de_alimentos',
               'portable_kitchen_food_preparers'
        WHERE NOT EXISTS (
            SELECT 1 FROM bronze.stg_category
            WHERE product_category_name =
                  'portateis_cozinha_e_preparadores_de_alimentos'
        );


    -- STEP 2: Insert products with English category translation
    -- 71 categories translated + 2 manually added above = 73 total
    -- 610 NULL categories → 'uncategorized'
    -- Translation logic: English from bronze.stg_category → else Portuguese → else uncategorized
        INSERT INTO silver.slv_products
        SELECT
            p.product_id,
            COALESCE(
                cat.product_category_name_english, 
                CASE 
                    WHEN p.product_category_name IS NULL OR p.product_category_name = '' 
                    THEN 'uncategorized' 
                    ELSE p.product_category_name  -- ✅ Use p. prefix
                END
            ) AS product_category_name,
            ISNULL(TRY_CAST(p.product_weight_g AS DECIMAL(10,2)), 0) AS product_weight_g,
            ISNULL(TRY_CAST(p.product_length_cm AS DECIMAL(10,2)), 0) AS product_length_cm,
            ISNULL(TRY_CAST(p.product_height_cm AS DECIMAL(10,2)), 0) AS product_height_cm,
            ISNULL(TRY_CAST(p.product_width_cm AS DECIMAL(10,2)), 0) AS product_width_cm
        FROM bronze.stg_products p
        LEFT JOIN bronze.stg_category cat 
            ON p.product_category_name = cat.product_category_name  -- ✅ Clear join
        WHERE p.product_id IS NOT NULL AND p.product_id <> '';

    -- VERIFY: Check translation coverage after insert
        SELECT
            product_category_name,
            COUNT(*)                AS product_count,
            CASE
                WHEN product_category_name = 'uncategorized' THEN 'NULL in source'
                WHEN product_category_name NOT IN (SELECT product_category_name_english FROM bronze.stg_category WHERE product_category_name_english IS NOT NULL)
                     AND product_category_name NOT IN (
                         SELECT product_category_name_english FROM bronze.stg_category)
                THEN 'Still Portuguese — check bronze.stg_category'
                ELSE 'Translated to English'
            END                     AS translation_status
        FROM silver.slv_products
        GROUP BY product_category_name
        ORDER BY product_count DESC;

    -- ── SELLERS ─────────────────────────────────────────────────
        WITH deduped_sellers AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY seller_id
                    ORDER BY seller_zip_code_prefix DESC) AS rn
            FROM bronze.stg_sellers
            WHERE seller_id IS NOT NULL 
              AND LTRIM(RTRIM(CAST(seller_id AS VARCHAR(50)))) <> ''
        )
        INSERT INTO silver.slv_sellers
        SELECT
            seller_id,
            NULLIF(LTRIM(RTRIM(CAST(seller_zip_code_prefix AS VARCHAR(20))), ''), '') AS seller_zip_code_prefix,
            UPPER(LTRIM(RTRIM(CAST(seller_city AS VARCHAR(100))))) AS seller_city,
            UPPER(LEFT(LTRIM(RTRIM(CAST(seller_state AS VARCHAR(10)))), 2)) AS seller_state
        FROM deduped_sellers WHERE rn = 1;

    -- ── ORDERS (deduplicate + cast dates) ───────────────────────
        WITH deduped AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY order_id
                       ORDER BY order_purchase_timestamp) AS rn
            FROM bronze.stg_orders
            WHERE order_id IS NOT NULL AND order_id <> ''
        )
        INSERT INTO silver.slv_orders
        SELECT
            order_id,
            customer_id,
            LOWER(TRIM(order_status)),
            TRY_CAST(order_purchase_timestamp AS DATE),
            TRY_CAST(order_approved_at AS DATE),
            TRY_CAST(order_delivered_carrier_date AS DATE),
            TRY_CAST(order_delivered_customer_date AS DATE),
            TRY_CAST(order_estimated_delivery_date AS DATE)
        FROM deduped
        WHERE rn = 1;

    -- ── ORDER ITEMS ──────────────────────────────────────────────
        INSERT INTO silver.slv_order_items
        SELECT
            order_id,
            TRY_CAST(order_item_id  AS INT),
            product_id,
            seller_id,
            TRY_CAST(price          AS DECIMAL(10,2)),
            TRY_CAST(freight_value  AS DECIMAL(10,2))
        FROM bronze.stg_order_items
        WHERE order_id IS NOT NULL AND order_id <> ''
          AND TRY_CAST(price AS DECIMAL(10,2)) > 0;



    -- ── PAYMENTS ─────────────────────────────────────────────────
        INSERT INTO silver.slv_payments
        SELECT
            order_id,
            TRY_CAST(payment_sequential AS INT),
            LOWER(LTRIM(RTRIM(CAST(payment_type AS VARCHAR(30))))),
            TRY_CAST(payment_installments AS INT),
            TRY_CAST(payment_value AS DECIMAL(10,2))
        FROM bronze.stg_payments
        WHERE order_id IS NOT NULL AND order_id <> ''
          AND payment_type NOT IN ('not_defined', '')
          AND TRY_CAST(payment_value AS DECIMAL(10,2)) > 0; 

    -- ── REVIEWS ──────────────────────────────────────────────────
    -- ROW_NUMBER dedup: partitioned by review_id (unique in Olist)
    -- Some orders have multiple VALID reviews — do NOT deduplicate by order_id
    -- Dedup by review_id removes only true duplicates (same review ingested twice)
        WITH deduped_reviews AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY review_id
                    ORDER BY review_creation_date ASC) AS rn
            FROM bronze.stg_reviews
            WHERE order_id IS NOT NULL AND TRIM(order_id) <> ''
              AND TRY_CAST(review_score AS TINYINT) BETWEEN 1 AND 5
        )
        INSERT INTO silver.slv_reviews
        SELECT
            review_id,
            order_id,
            TRY_CAST(review_score AS TINYINT),
            TRY_CAST(review_creation_date AS DATE)
        FROM deduped_reviews
        WHERE rn = 1;

    -- ── GEOLOCATION (Silver pre-clean before Gold dedup) ────────
    -- Load all rows into silver.slv_geolocation with encoding fix
    -- Deduplication happens in Gold (gold.dim_geolocation)
        INSERT INTO silver.slv_geolocation
        SELECT
            TRIM(CAST(geolocation_zip_code_prefix AS VARCHAR(10))) AS geolocation_zip_code_prefix,
            TRY_CAST(geolocation_lat AS DECIMAL(10,6)) AS geolocation_lat,
            TRY_CAST(geolocation_lng AS DECIMAL(10,6)) AS geolocation_lng,
            UPPER(TRIM(geolocation_city)) AS geolocation_city,
            UPPER(TRIM(geolocation_state)) AS geolocation_state
        FROM bronze.stg_geolocation
        WHERE geolocation_zip_code_prefix IS NOT NULL
          AND TRIM(CAST(geolocation_zip_code_prefix AS VARCHAR(10))) <> ''
          AND TRY_CAST(geolocation_lat AS DECIMAL(10,6)) IS NOT NULL;
