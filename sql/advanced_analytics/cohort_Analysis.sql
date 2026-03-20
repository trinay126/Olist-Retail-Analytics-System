-- ═══════════════════════════════════════════════════════════
-- ADVANCED ANALYTICS 2: Cohort Analysis
-- Group customers by first purchase month
-- Track how many reorder in subsequent months
-- ═══════════════════════════════════════════════════════════

WITH first_purchase AS (
    -- Step 1: Find each customer's first order month
    SELECT
        customer_id,
        MIN(order_purchase_date)             AS first_order_date,
        DATEFROMPARTS(
            YEAR(MIN(order_purchase_date)),
            MONTH(MIN(order_purchase_date)),
            1)                               AS cohort_month
    FROM gold.vw_master_orders
    WHERE order_purchase_date IS NOT NULL
    GROUP BY customer_id
),
order_months AS (
    -- Step 2: Get every month each customer ordered
    SELECT DISTINCT
        customer_id,
        DATEFROMPARTS(
            YEAR(order_purchase_date),
            MONTH(order_purchase_date),
            1)                               AS order_month
    FROM gold.vw_master_orders
    WHERE order_purchase_date IS NOT NULL
),
cohort_data AS (
    -- Step 3: Calculate months since first purchase
    SELECT
        f.cohort_month,
        DATEDIFF(MONTH, f.cohort_month,
                 om.order_month)             AS month_number,
        COUNT(DISTINCT om.customer_id)       AS active_customers
    FROM  first_purchase f
    JOIN  order_months   om ON f.customer_id = om.customer_id
    GROUP BY f.cohort_month,
             DATEDIFF(MONTH, f.cohort_month, om.order_month)
),
cohort_size AS (
    -- Step 4: Get cohort size (month 0 = starting customers)
    SELECT cohort_month, active_customers AS cohort_customers
    FROM   cohort_data
    WHERE  month_number = 0
)
SELECT
    cd.cohort_month,
    cd.month_number,
    cd.active_customers,
    cs.cohort_customers,
    ROUND(cd.active_customers * 100.0 /
          NULLIF(cs.cohort_customers, 0), 2) AS retention_rate_pct
FROM  cohort_data  cd
JOIN  cohort_size  cs ON cd.cohort_month = cs.cohort_month
WHERE cd.month_number <= 6   -- Show first 6 months of retention
ORDER BY cd.cohort_month, cd.month_number;
-- INSIGHT TO QUOTE: 'Month 1 retention is X% — meaning X% of
-- customers who bought in month 0 returned the following month'
