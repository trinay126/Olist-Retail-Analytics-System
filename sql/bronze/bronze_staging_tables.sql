-- Add load timestamp (auto-populated) and source file name to all staging tables
ALTER TABLE bronze.stg_orders      ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_customers   ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_order_items ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_payments    ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_reviews     ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_products    ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_sellers     ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_geolocation ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);
ALTER TABLE bronze.stg_category    ADD load_ts DATETIME DEFAULT GETDATE(), src_file VARCHAR(100);

-- Populate src_file for each table:
UPDATE bronze.stg_orders      SET load_ts = GETDATE(), src_file = 'olist_orders_dataset.csv';
UPDATE bronze.stg_customers   SET load_ts = GETDATE(), src_file = 'olist_customers_dataset.csv';
UPDATE bronze.stg_order_items SET load_ts = GETDATE(), src_file = 'olist_order_items_dataset.csv';
UPDATE bronze.stg_payments    SET load_ts = GETDATE(), src_file = 'olist_order_payments_dataset.csv';
UPDATE bronze.stg_reviews     SET load_ts = GETDATE(), src_file = 'olist_order_reviews_dataset.csv';
UPDATE bronze.stg_products    SET load_ts = GETDATE(), src_file = 'olist_products_dataset.csv';
UPDATE bronze.stg_sellers     SET load_ts = GETDATE(), src_file = 'olist_sellers_dataset.csv';
UPDATE bronze.stg_geolocation SET load_ts = GETDATE(), src_file = 'olist_geolocation_dataset.csv';
UPDATE bronze.stg_category    SET load_ts = GETDATE(), src_file = 'product_category_name_translation.csv';

PRINT 'Audit columns added and populated for all 9 tables.';


SELECT 'bronze.stg_customers'      AS table_name, COUNT(*) AS row_count FROM bronze.stg_customers    UNION ALL
SELECT 'bronze.stg_orders',                       COUNT(*)              FROM bronze.stg_orders        UNION ALL
SELECT 'bronze.stg_order_items',                  COUNT(*)              FROM bronze.stg_order_items   UNION ALL
SELECT 'bronze.stg_payments',                     COUNT(*)              FROM bronze.stg_payments      UNION ALL
SELECT 'bronze.stg_reviews',                      COUNT(*)              FROM bronze.stg_reviews       UNION ALL
SELECT 'bronze.stg_products',                     COUNT(*)              FROM bronze.stg_products      UNION ALL
SELECT 'bronze.stg_sellers',                      COUNT(*)              FROM bronze.stg_sellers       UNION ALL
SELECT 'bronze.stg_geolocation',                  COUNT(*)              FROM bronze.stg_geolocation   UNION ALL
SELECT 'bronze.stg_category',                     COUNT(*)              FROM bronze.stg_category;
