CREATE OR ALTER PROCEDURE sp_monthly_executive_report
    @year  INT,
    @month INT
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '📊 OLIST E-COMMERCE: ' + CAST(@year AS VARCHAR) + '-' + RIGHT('0'+CAST(@month AS VARCHAR),2) + ' EXECUTIVE REPORT';
    PRINT '───────────────────────────────────────';

    -- Monthly KPIs (Vertical format for execs)
    SELECT
        '💰 Total Revenue'          AS kpi,
        'R$ ' + FORMAT(ROUND(SUM(total_item_value),2), 'N2') AS value
    FROM gold.vw_master_orders
    WHERE YEAR(order_purchase_date) = @year
      AND MONTH(order_purchase_date) = @month
      AND order_status = 'delivered'
    
    UNION ALL
    SELECT '📦 Total Orders',
           FORMAT(COUNT(DISTINCT order_id), 'N0')
    FROM gold.vw_master_orders
    WHERE YEAR(order_purchase_date) = @year 
      AND MONTH(order_purchase_date) = @month
      AND order_status = 'delivered'
    
    UNION ALL
    SELECT '✅ On-Time Delivery %',
           FORMAT(ROUND(SUM(CASE WHEN delivery_status='On Time' THEN 1.0 ELSE 0 END)
                       /NULLIF(COUNT(*),0)*100, 1), 'N1') + '%'
    FROM gold.vw_master_orders
    WHERE YEAR(order_purchase_date) = @year 
      AND MONTH(order_purchase_date) = @month
    
    UNION ALL
    SELECT '⭐ Avg Review Score',
           FORMAT(ROUND(AVG(review_score),1), 'N1') + '/5'
    FROM gold.vw_master_orders
    WHERE YEAR(order_purchase_date) = @year 
      AND MONTH(order_purchase_date) = @month;

    PRINT '';
    PRINT '🏆 TOP 5 CATEGORIES BY REVENUE ─────────────────────';
    
    SELECT TOP 5
        category,
        'R$ ' + FORMAT(ROUND(SUM(total_item_value),2), 'N2') AS revenue,
        FORMAT(COUNT(DISTINCT order_id), 'N0') + ' orders'
    FROM gold.vw_master_orders
    WHERE YEAR(order_purchase_date) = @year 
      AND MONTH(order_purchase_date) = @month
      AND order_status = 'delivered'
    GROUP BY category
    ORDER BY SUM(total_item_value) DESC;

    PRINT '───────────────────────────────────────';
    PRINT 'Report generated: ' + FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm');
END;
GO

EXEC sp_monthly_executive_report @year = 2018, @month = 8;
