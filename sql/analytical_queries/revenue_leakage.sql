select
	category,
	count(distinct order_id) as total_orders,
	round(sum(price), 2) as gross_revenue,
	round(sum(freight_value), 2) as total_freight,
	ROUND(SUM(freight_value) /
          NULLIF(SUM(price),0) * 100, 2)               AS freight_leakage_pct,
    CASE
        WHEN SUM(freight_value)/NULLIF(SUM(price),0) > 0.30
             THEN 'HIGH LEAKAGE'
        WHEN SUM(freight_value)/NULLIF(SUM(price),0) > 0.15
             THEN 'MODERATE'
        ELSE      'Acceptable'
    END                                                AS leakage_flag
FROM  gold.vw_master_orders
WHERE order_status = 'delivered'
GROUP BY category
ORDER BY freight_leakage_pct DESC;
