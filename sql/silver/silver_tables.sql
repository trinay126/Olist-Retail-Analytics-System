USE RetailAnalytics;
GO

-- ══════════════════════════════════════════════════════════
-- SILVER LAYER: Cleaned tables with proper data types
-- ══════════════════════════════════════════════════════════

IF OBJECT_ID('silver.slv_customers',    'U') IS NOT NULL DROP TABLE silver.slv_customers;
IF OBJECT_ID('silver.slv_products',     'U') IS NOT NULL DROP TABLE silver.slv_products;
IF OBJECT_ID('silver.slv_sellers',      'U') IS NOT NULL DROP TABLE silver.slv_sellers;
IF OBJECT_ID('silver.slv_orders',       'U') IS NOT NULL DROP TABLE silver.slv_orders;
IF OBJECT_ID('silver.slv_order_items',  'U') IS NOT NULL DROP TABLE silver.slv_order_items;
IF OBJECT_ID('silver.slv_payments',     'U') IS NOT NULL DROP TABLE silver.slv_payments;
IF OBJECT_ID('silver.slv_reviews',      'U') IS NOT NULL DROP TABLE silver.slv_reviews;
IF OBJECT_ID('silver.slv_geolocation',  'U') IS NOT NULL DROP TABLE silver.slv_geolocation;
GO

CREATE TABLE silver.slv_customers (
    customer_id           VARCHAR(50)  NOT NULL,
    customer_unique_id    VARCHAR(50)  NOT NULL,
    customer_zip_code_prefix     VARCHAR(10),
    customer_city         VARCHAR(100),
    customer_state        CHAR(2)
);

CREATE TABLE silver.slv_products (
    product_id                   VARCHAR(50)   NOT NULL,
    product_category_name        VARCHAR(100)  NOT NULL DEFAULT 'uncategorized',
    product_weight_g             DECIMAL(10,2),
    product_length_cm            DECIMAL(10,2),
    product_height_cm            DECIMAL(10,2),
    product_width_cm             DECIMAL(10,2)
);

CREATE TABLE silver.slv_sellers (
    seller_id           VARCHAR(50)  NOT NULL,
    seller_zip_code_prefix     VARCHAR(10),
    seller_city         VARCHAR(100),
    seller_state        CHAR(2)
);

CREATE TABLE silver.slv_orders (
    order_id                    VARCHAR(50)  NOT NULL,
    customer_id                 VARCHAR(50)  NOT NULL,
    order_status                VARCHAR(30),
    order_purchase_date         DATE,
    order_approved_date         DATE,
    order_delivered_carrier_date     DATE,
    order_delivered_customer_date    DATE,
    order_estimated_delivery_date    DATE
);

CREATE TABLE silver.slv_order_items (
    order_id              VARCHAR(50)    NOT NULL,
    order_item_id         INT,
    product_id            VARCHAR(50),
    seller_id             VARCHAR(50),
    price                 DECIMAL(10,2),
    freight_value         DECIMAL(10,2)
);

CREATE TABLE silver.slv_payments (
    order_id                VARCHAR(50)   NOT NULL,
    payment_sequential      INT,
    payment_type            VARCHAR(30),
    payment_installments    INT,
    payment_value           DECIMAL(10,2)
);

CREATE TABLE silver.slv_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50)  NOT NULL,
    review_score            TINYINT,
    review_creation_date    DATE
);

CREATE TABLE silver.slv_geolocation (
    geolocation_zip_code_prefix   VARCHAR(10)    NOT NULL,
    geolocation_lat               DECIMAL(10,6),
    geolocation_lng               DECIMAL(10,6),
    geolocation_city              VARCHAR(100),
    geolocation_state             CHAR(2)
);

-- Primary Keys on Silver tables (prevent duplicates)
ALTER TABLE silver.slv_customers   ADD CONSTRAINT PK_slv_customers
    PRIMARY KEY (customer_id);
ALTER TABLE silver.slv_products    ADD CONSTRAINT PK_slv_products
    PRIMARY KEY (product_id);
ALTER TABLE silver.slv_sellers     ADD CONSTRAINT PK_slv_sellers
    PRIMARY KEY (seller_id);
ALTER TABLE silver.slv_orders      ADD CONSTRAINT PK_slv_orders
    PRIMARY KEY (order_id);

-- CHECK constraints: enforce data rules at the database level
ALTER TABLE silver.slv_reviews
    ADD CONSTRAINT CHK_review_score
    CHECK (review_score BETWEEN 1 AND 5);

ALTER TABLE silver.slv_order_items
    ADD CONSTRAINT CHK_price_positive
    CHECK (price > 0);

ALTER TABLE silver.slv_order_items
    ADD CONSTRAINT CHK_freight_nonneg
    CHECK (freight_value >= 0);

ALTER TABLE silver.slv_payments
    ADD CONSTRAINT CHK_payment_positive
    CHECK (payment_value > 0);

-- Foreign Key constraints (referential integrity on Silver)
-- Answers interviewer question: 'Why no relationships?'
ALTER TABLE silver.slv_orders ADD CONSTRAINT FK_slv_orders_customer
    FOREIGN KEY (customer_id) REFERENCES silver.slv_customers(customer_id);

ALTER TABLE silver.slv_order_items ADD CONSTRAINT FK_slv_items_order
    FOREIGN KEY (order_id) REFERENCES silver.slv_orders(order_id);

ALTER TABLE silver.slv_order_items ADD CONSTRAINT FK_slv_items_product
    FOREIGN KEY (product_id) REFERENCES silver.slv_products(product_id);

ALTER TABLE silver.slv_order_items ADD CONSTRAINT FK_slv_items_seller
    FOREIGN KEY (seller_id) REFERENCES silver.slv_sellers(seller_id);

ALTER TABLE silver.slv_payments ADD CONSTRAINT FK_slv_payments_order
    FOREIGN KEY (order_id) REFERENCES silver.slv_orders(order_id);

ALTER TABLE silver.slv_reviews ADD CONSTRAINT FK_slv_reviews_order
    FOREIGN KEY (order_id) REFERENCES silver.slv_orders(order_id);

PRINT 'Silver tables created with PK and FK constraints.';
