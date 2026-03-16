CREATE DATABASE RetailAnalytics; 
GO 
USE RetailAnalytics; 
GO
 -- Tables will be: bronze.stg_orders, silver.slv_orders, gold.fact_orders 
CREATE SCHEMA bronze; -- raw staging tables  (prefix: stg_) 
GO
CREATE SCHEMA silver;   -- cleaned and typed   (prefix: slv_) 
GO
CREATE SCHEMA gold;     -- star schema model   (prefix: dim_ / fact_) 
GO  