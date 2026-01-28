-- Advanced SQL Techniques Showcase
-- This file demonstrates sophisticated SQL concepts for data analysis

-- Database setup
CREATE DATABASE IF NOT EXISTS advanced_analytics_sql;
USE advanced_analytics_sql;

-- 1. Complex Data Warehouse Schema
CREATE TABLE fact_sales (
    sale_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    customer_id INT,
    date_id INT,
    store_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    discount_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    profit_margin DECIMAL(5,2)
);

CREATE TABLE dim_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    brand VARCHAR(50),
    supplier VARCHAR(50),
    unit_cost DECIMAL(8,2),
    launch_date DATE,
    discontinue_date DATE
);

CREATE TABLE dim_customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    customer_segment VARCHAR(20),
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    age_group VARCHAR(20),
    income_bracket VARCHAR(20),
    loyalty_tier VARCHAR(20)
);

CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    week INT,
    day_of_week INT,
    day_name VARCHAR(10),
    month_name VARCHAR(10),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    season VARCHAR(10)
);

CREATE TABLE dim_stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(100),
    store_type VARCHAR(30),
    city VARCHAR(50),
    state VARCHAR(50),
    region VARCHAR(50),
    store_size VARCHAR(20),
    opening_date DATE
);

-- 2. Generate comprehensive sample data
INSERT INTO dim_date
SELECT 
    ROW_NUMBER() OVER (ORDER BY date_column) as date_id,
    date_column as full_date,
    YEAR(date_column) as year,
    QUARTER(date_column) as quarter,
    MONTH(date_column) as month,
    WEEK(date_column, 1) as week,
    DAYOFWEEK(date_column) as day_of_week,
    DAYNAME(date_column) as day_name,
    MONTHNAME(date_column) as month_name,
    DAYOFWEEK(date_column) IN (1,7) as is_weekend,
    date_column IN ('2023-01-01', '2023-07-04', '2023-12-25') as is_holiday,
    CASE 
        WHEN MONTH(date_column) IN (12,1,2) THEN 'Winter'
        WHEN MONTH(date_column) IN (3,4,5) THEN 'Spring'
        WHEN MONTH(date_column) IN (6,7,8) THEN 'Summer'
        ELSE 'Fall'
    END as season
FROM (
    SELECT DATE_ADD('2023-01-01', INTERVAL n DAY) as date_column
    FROM (
        SELECT a.N + b.N * 10 + c.N * 100 as n
        FROM (SELECT 0 as N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
        CROSS JOIN (SELECT 0 as N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
        CROSS JOIN (SELECT 0 as N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) c
    ) numbers
    WHERE n < 365
) dates;

INSERT INTO dim_products
SELECT 
    ROW_NUMBER() OVER () as product_id,
    CONCAT('Product ', ROW_NUMBER() OVER ()) as product_name,
    ELT(FLOOR(1 + RAND()*5), 'Electronics', 'Clothing', 'Home & Garden', 'Books', 'Sports') as category,
    CONCAT('Subcat ', FLOOR(1 + RAND()*3)) as subcategory,
    CONCAT('Brand ', ELT(FLOOR(1 + RAND()*10), 'A','B','C','D','E','F','G','H','I','J')) as brand,
    CONCAT('Supplier ', FLOOR(1 + RAND()*20)) as supplier,
    ROUND(10 + RAND()*990, 2) as unit_cost,
    DATE_ADD('2020-01-01', INTERVAL FLOOR(RAND()*1095) DAY) as launch_date,
    CASE WHEN RAND() < 0.1 THEN DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND()*365) DAY) ELSE NULL END as discontinue_date
FROM information_schema.tables
LIMIT 500;

INSERT INTO dim_customers
SELECT 
    ROW_NUMBER() OVER () as customer_id,
    CONCAT('Customer ', ROW_NUMBER() OVER ()) as customer_name,
    ELT(FLOOR(1 + RAND()*4), 'Premium', 'Standard', 'Basic', 'VIP') as customer_segment,
    CONCAT('City ', FLOOR(1 + RAND()*50)) as city,
    ELT(FLOOR(1 + RAND()*10), 'CA','NY','TX','FL','IL','PA','OH','GA','NC','MI') as state,
    'USA' as country,
    ELT(FLOOR(1 + RAND()*5), '18-25', '26-35', '36-45', '46-55', '55+') as age_group,
    ELT(FLOOR(1 + RAND()*4), 'Low', 'Medium', 'High', 'Premium') as income_bracket,
    ELT(FLOOR(1 + RAND()*4), 'Bronze', 'Silver', 'Gold', 'Platinum') as loyalty_tier
FROM information_schema.tables t1
CROSS JOIN information_schema.tables t2
LIMIT 10000;

INSERT INTO dim_stores
SELECT 
    ROW_NUMBER() OVER () as store_id,
    CONCAT('Store ', ROW_NUMBER() OVER ()) as store_name,
    ELT(FLOOR(1 + RAND()*4), 'Flagship', 'Regular', 'Outlet', 'Online') as store_type,
    CONCAT('City ', FLOOR(1 + RAND()*30)) as city,
    ELT(FLOOR(1 + RAND()*8), 'CA','NY','TX','FL','IL','PA','OH','GA') as state,
    ELT(FLOOR(1 + RAND()*4), 'West', 'East', 'Central', 'South') as region,
    ELT(FLOOR(1 + RAND()*3), 'Small', 'Medium', 'Large') as store_size,
    DATE_ADD('2015-01-01', INTERVAL FLOOR(RAND()*2920) DAY) as opening_date
FROM information_schema.tables
LIMIT 200;

-- Generate fact table with 100K records
INSERT INTO fact_sales
SELECT 
    ROW_NUMBER() OVER () as sale_id,
    FLOOR(1 + RAND()*500) as product_id,
    FLOOR(1 + RAND()*10000) as customer_id,
    FLOOR(1 + RAND()*365) as date_id,
    FLOOR(1 + RAND()*200) as store_id,
    FLOOR(1 + RAND()*10) as quantity,
    ROUND(10 + RAND()*490, 2) as unit_price,
    0 as total_amount, -- Will be calculated
    ROUND(RAND()*50, 2) as discount_amount,
    0 as tax_amount, -- Will be calculated
    ROUND(0.1 + RAND()*0.4, 2) as profit_margin
FROM information_schema.tables t1
CROSS JOIN information_schema.tables t2
CROSS JOIN information_schema.tables t3
LIMIT 100000;

-- Update calculated fields
UPDATE fact_sales 
SET total_amount = (quantity * unit_price) - discount_amount,
    tax_amount = ((quantity * unit_price) - discount_amount) * 0.08;

-- 3. Advanced Analytics Queries

-- Multi-dimensional sales analysis with ROLLUP and CUBE
SELECT 
    COALESCE(p.category, 'ALL CATEGORIES') as category,
    COALESCE(c.customer_segment, 'ALL SEGMENTS') as segment,
    COALESCE(d.season, 'ALL SEASONS') as season,
    COUNT(f.sale_id) as total_transactions,
    SUM(f.total_amount) as total_revenue,
    AVG(f.total_amount) as avg_transaction_value,
    SUM(f.quantity) as total_units_sold
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
JOIN dim_customers c ON f.customer_id = c.customer_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year = 2023
GROUP BY p.category, c.customer_segment, d.season WITH ROLLUP
ORDER BY total_revenue DESC;

-- Advanced window functions for ranking and percentiles
CREATE VIEW sales_performance_ranking AS
SELECT 
    p.product_name,
    p.category,
    s.region,
    SUM(f.total_amount) as total_revenue,
    COUNT(f.sale_id) as total_transactions,
    AVG(f.total_amount) as avg_transaction,
    -- Rankings
    RANK() OVER (ORDER BY SUM(f.total_amount) DESC) as global_revenue_rank,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.total_amount) DESC) as category_rank,
    RANK() OVER (PARTITION BY s.region ORDER BY SUM(f.total_amount) DESC) as regional_rank,
    -- Percentiles
    PERCENT_RANK() OVER (ORDER BY SUM(f.total_amount)) as revenue_percentile,
    CUME_DIST() OVER (ORDER BY SUM(f.total_amount)) as revenue_cumulative_dist,
    -- NTile for quartiles
    NTILE(4) OVER (ORDER BY SUM(f.total_amount)) as revenue_quartile,
    -- Running totals
    SUM(SUM(f.total_amount)) OVER (ORDER BY SUM(f.total_amount) DESC ROWS UNBOUNDED PRECEDING) as running_total,
    -- Lag/Lead for comparisons
    LAG(SUM(f.total_amount), 1) OVER (PARTITION BY p.category ORDER BY SUM(f.total_amount) DESC) as next_lower_revenue
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
JOIN dim_stores s ON f.store_id = s.store_id
GROUP BY p.product_name, p.category, s.region;

-- Complex temporal analysis with multiple time windows
CREATE VIEW temporal_sales_analysis AS
WITH daily_sales AS (
    SELECT 
        d.full_date,
        d.year,
        d.month,
        d.quarter,
        d.day_name,
        d.is_weekend,
        SUM(f.total_amount) as daily_revenue,
        COUNT(f.sale_id) as daily_transactions,
        COUNT(DISTINCT f.customer_id) as unique_customers
    FROM fact_sales f
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY d.full_date, d.year, d.month, d.quarter, d.day_name, d.is_weekend
),
moving_averages AS (
    SELECT 
        full_date,
        year,
        month,
        quarter,
        day_name,
        is_weekend,
        daily_revenue,
        daily_transactions,
        unique_customers,
        -- Various moving averages
        AVG(daily_revenue) OVER (ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as ma_7_day,
        AVG(daily_revenue) OVER (ORDER BY full_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as ma_30_day,
        AVG(daily_revenue) OVER (ORDER BY full_date ROWS BETWEEN 89 PRECEDING AND CURRENT ROW) as ma_90_day,
        -- Year-over-year comparison
        LAG(daily_revenue, 365) OVER (ORDER BY full_date) as yoy_revenue,
        -- Month-over-month
        LAG(daily_revenue, 30) OVER (ORDER BY full_date) as mom_revenue,
        -- Quarterly moving sums
        SUM(daily_revenue) OVER (PARTITION BY year, quarter ORDER BY full_date ROWS UNBOUNDED PRECEDING) as qtd_revenue,
        -- Year-to-date
        SUM(daily_revenue) OVER (PARTITION BY year ORDER BY full_date ROWS UNBOUNDED PRECEDING) as ytd_revenue
    FROM daily_sales
)
SELECT 
    full_date,
    day_name,
    is_weekend,
    daily_revenue,
    daily_transactions,
    unique_customers,
    ROUND(ma_7_day, 2) as seven_day_avg,
    ROUND(ma_30_day, 2) as thirty_day_avg,
    ROUND(ma_90_day, 2) as ninety_day_avg,
    CASE 
        WHEN yoy_revenue IS NOT NULL THEN 
            ROUND(((daily_revenue - yoy_revenue) / yoy_revenue) * 100, 2)
        ELSE NULL
    END as yoy_growth_pct,
    CASE 
        WHEN mom_revenue IS NOT NULL THEN 
            ROUND(((daily_revenue - mom_revenue) / mom_revenue) * 100, 2)
        ELSE NULL
    END as mom_growth_pct,
    qtd_revenue,
    ytd_revenue
FROM moving_averages
ORDER BY full_date;

-- Advanced customer analytics with cohort analysis
CREATE VIEW customer_cohort_analysis AS
WITH customer_first_purchase AS (
    SELECT 
        c.customer_id,
        c.customer_segment,
        MIN(d.full_date) as first_purchase_date,
        DATE_FORMAT(MIN(d.full_date), '%Y-%m') as cohort_month
    FROM fact_sales f
    JOIN dim_customers c ON f.customer_id = c.customer_id
    JOIN dim_date d ON f.date_id = d.date_id
    GROUP BY c.customer_id, c.customer_segment
),
customer_purchase_activity AS (
    SELECT 
        cfp.customer_id,
        cfp.customer_segment,
        cfp.cohort_month,
        cfp.first_purchase_date,
        d.full_date as purchase_date,
        f.total_amount,
        TIMESTAMPDIFF(MONTH, cfp.first_purchase_date, d.full_date) as months_since_first_purchase
    FROM customer_first_purchase cfp
    JOIN fact_sales f ON cfp.customer_id = f.customer_id
    JOIN dim_date d ON f.date_id = d.date_id
),
cohort_retention AS (
    SELECT 
        cohort_month,
        customer_segment,
        months_since_first_purchase,
        COUNT(DISTINCT customer_id) as active_customers,
        SUM(total_amount) as cohort_revenue,
        AVG(total_amount) as avg_transaction_value
    FROM customer_purchase_activity
    GROUP BY cohort_month, customer_segment, months_since_first_purchase
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        customer_segment,
        COUNT(DISTINCT customer_id) as cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month, customer_segment
)
SELECT 
    cr.cohort_month,
    cr.customer_segment,
    cr.months_since_first_purchase,
    cs.cohort_size,
    cr.active_customers,
    ROUND((cr.active_customers * 100.0 / cs.cohort_size), 2) as retention_rate_pct,
    ROUND(cr.cohort_revenue, 2) as cohort_revenue,
    ROUND(cr.avg_transaction_value, 2) as avg_transaction_value,
    ROUND((cr.cohort_revenue / cs.cohort_size), 2) as revenue_per_original_customer
FROM cohort_retention cr
JOIN cohort_sizes cs ON cr.cohort_month = cs.cohort_month AND cr.customer_segment = cs.customer_segment
ORDER BY cr.cohort_month, cr.customer_segment, cr.months_since_first_purchase;

-- Predictive analytics using SQL
CREATE VIEW sales_forecasting_base AS
WITH historical_trends AS (
    SELECT 
        d.year,
        d.month,
        d.quarter,
        p.category,
        SUM(f.total_amount) as monthly_revenue,
        COUNT(f.sale_id) as monthly_transactions,
        COUNT(DISTINCT f.customer_id) as monthly_active_customers,
        AVG(f.total_amount) as avg_transaction_value
    FROM fact_sales f
    JOIN dim_date d ON f.date_id = d.date_id
    JOIN dim_products p ON f.product_id = p.product_id
    GROUP BY d.year, d.month, d.quarter, p.category
),
trend_analysis AS (
    SELECT 
        year,
        month,
        quarter,
        category,
        monthly_revenue,
        monthly_transactions,
        monthly_active_customers,
        avg_transaction_value,
        LAG(monthly_revenue, 1) OVER (PARTITION BY category ORDER BY year, month) as prev_month_revenue,
        LAG(monthly_revenue, 12) OVER (PARTITION BY category ORDER BY year, month) as prev_year_revenue,
        AVG(monthly_revenue) OVER (PARTITION BY category ORDER BY year, month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as trailing_12_month_avg,
        STDDEV(monthly_revenue) OVER (PARTITION BY category ORDER BY year, month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as trailing_12_month_stddev
    FROM historical_trends
),
seasonality_factors AS (
    SELECT 
        category,
        month,
        AVG(monthly_revenue) as avg_monthly_revenue,
        AVG(AVG(monthly_revenue)) OVER (PARTITION BY category) as category_avg_revenue,
        AVG(monthly_revenue) / AVG(AVG(monthly_revenue)) OVER (PARTITION BY category) as seasonality_factor
    FROM historical_trends
    GROUP BY category, month
)
SELECT 
    ta.year,
    ta.month,
    ta.quarter,
    ta.category,
    ta.monthly_revenue,
    ta.trailing_12_month_avg,
    ta.trailing_12_month_stddev,
    sf.seasonality_factor,
    CASE 
        WHEN ta.prev_month_revenue IS NOT NULL THEN 
            ROUND(((ta.monthly_revenue - ta.prev_month_revenue) / ta.prev_month_revenue) * 100, 2)
        ELSE NULL
    END as mom_growth_pct,
    CASE 
        WHEN ta.prev_year_revenue IS NOT NULL THEN 
            ROUND(((ta.monthly_revenue - ta.prev_year_revenue) / ta.prev_year_revenue) * 100, 2)
        ELSE NULL
    END as yoy_growth_pct,
    -- Simple forecast for next month (trend + seasonality)
    ROUND(ta.trailing_12_month_avg * sf.seasonality_factor, 2) as forecasted_revenue,
    ROUND(ABS(ta.monthly_revenue - (ta.trailing_12_month_avg * sf.seasonality_factor)), 2) as forecast_error
FROM trend_analysis ta
JOIN seasonality_factors sf ON ta.category = sf.category AND ta.month = sf.month
WHERE ta.trailing_12_month_avg IS NOT NULL
ORDER BY ta.category, ta.year, ta.month;

-- Performance monitoring and optimization
CREATE VIEW query_performance_summary AS
SELECT 
    'Table Sizes' as metric_category,
    'fact_sales' as metric_name,
    COUNT(*) as metric_value,
    'records' as unit
FROM fact_sales
UNION ALL
SELECT 'Table Sizes', 'dim_products', COUNT(*), 'records' FROM dim_products
UNION ALL
SELECT 'Table Sizes', 'dim_customers', COUNT(*), 'records' FROM dim_customers
UNION ALL
SELECT 'Table Sizes', 'dim_stores', COUNT(*), 'records' FROM dim_stores
UNION ALL
SELECT 'Table Sizes', 'dim_date', COUNT(*), 'records' FROM dim_date;

-- Create comprehensive indexes for performance
CREATE INDEX idx_fact_sales_product ON fact_sales(product_id);
CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_id);
CREATE INDEX idx_fact_sales_date ON fact_sales(date_id);
CREATE INDEX idx_fact_sales_store ON fact_sales(store_id);
CREATE INDEX idx_fact_sales_amount ON fact_sales(total_amount);
CREATE INDEX idx_dim_date_full_date ON dim_date(full_date);
CREATE INDEX idx_dim_products_category ON dim_products(category);
CREATE INDEX idx_dim_customers_segment ON dim_customers(customer_segment);

-- Summary analytics dashboard
SELECT 
    'Advanced Analytics Summary' as dashboard_section,
    COUNT(DISTINCT f.product_id) as unique_products_sold,
    COUNT(DISTINCT f.customer_id) as total_customers,
    COUNT(f.sale_id) as total_transactions,
    ROUND(SUM(f.total_amount), 2) as total_revenue,
    ROUND(AVG(f.total_amount), 2) as avg_transaction_value,
    COUNT(DISTINCT CONCAT(d.year, '-', d.month)) as months_of_data
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id;