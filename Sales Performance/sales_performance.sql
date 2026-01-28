CREATE DATABASE sales_sql;
USE sales_sql;

-- 1. Products
CREATE TABLE products (
  product_id INT PRIMARY KEY,
  category VARCHAR(20)
);

-- 2. Orders
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  product_id INT,
  order_date DATE,
  amount INT
);

-- 3. Generate products
INSERT INTO products
SELECT
  ROW_NUMBER() OVER (),
  ELT(FLOOR(1 + RAND()*4),'Electronics','Clothing','Home','Books')
FROM information_schema.tables
LIMIT 50;

-- 4. Generate 50,000 sales orders
INSERT INTO orders
SELECT
  ROW_NUMBER() OVER (),
  FLOOR(1 + RAND()*50),
  DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND()*365) DAY),
  FLOOR(500 + RAND()*15000)
FROM information_schema.tables t1
CROSS JOIN information_schema.tables t2
LIMIT 50000;

-- 5. Revenue ranking
SELECT
  product_id,
  SUM(amount) AS total_revenue,
  RANK() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank
FROM orders
GROUP BY product_id;

-- 6. Rolling 30-day revenue
SELECT
  order_date,
  SUM(amount) OVER (
    ORDER BY order_date
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ) AS rolling_30_day_revenue
FROM orders;

-- 7. Advanced Product Performance Analytics
CREATE VIEW product_performance AS
SELECT 
    p.product_id,
    p.category,
    COUNT(o.order_id) as total_orders,
    SUM(o.amount) as total_revenue,
    AVG(o.amount) as avg_order_value,
    MIN(o.amount) as min_order_value,
    MAX(o.amount) as max_order_value,
    STDDEV(o.amount) as revenue_volatility,
    RANK() OVER (ORDER BY SUM(o.amount) DESC) as revenue_rank,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(o.amount) DESC) as category_rank,
    ROUND((SUM(o.amount) / (SELECT SUM(amount) FROM orders)) * 100, 2) as revenue_share_pct
FROM products p
LEFT JOIN orders o ON p.product_id = o.product_id
GROUP BY o.product_id, p.category;

-- 8. Monthly Sales Trends with Growth Analysis
WITH monthly_sales AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') as month,
        COUNT(*) as orders_count,
        SUM(amount) as monthly_revenue,
        AVG(amount) as avg_monthly_order
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
    ORDER BY month
),
growth_analysis AS (
    SELECT 
        month,
        orders_count,
        monthly_revenue,
        avg_monthly_order,
        LAG(monthly_revenue) OVER (ORDER BY month) as prev_month_revenue,
        ROUND(
            ((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month)) / 
             LAG(monthly_revenue) OVER (ORDER BY month)) * 100, 2
        ) as revenue_growth_pct,
        SUM(monthly_revenue) OVER (ORDER BY month) as cumulative_revenue
    FROM monthly_sales
)
SELECT 
    month,
    orders_count,
    monthly_revenue,
    avg_monthly_order,
    revenue_growth_pct,
    cumulative_revenue,
    CASE 
        WHEN revenue_growth_pct > 10 THEN 'High Growth'
        WHEN revenue_growth_pct BETWEEN 0 AND 10 THEN 'Moderate Growth'
        WHEN revenue_growth_pct < 0 THEN 'Decline'
        ELSE 'Initial Month'
    END as growth_category
FROM growth_analysis;

-- 9. Customer Segmentation Analysis (RFM-like analysis)
WITH customer_metrics AS (
    SELECT 
        o.product_id as customer_proxy, -- Using product_id as customer proxy
        COUNT(o.order_id) as frequency,
        SUM(o.amount) as monetary_value,
        DATEDIFF(CURDATE(), MAX(o.order_date)) as recency_days,
        AVG(o.amount) as avg_order_value
    FROM orders o
    GROUP BY o.product_id
),
quartiles AS (
    SELECT 
        (SELECT frequency FROM (SELECT frequency, ROW_NUMBER() OVER (ORDER BY frequency) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.25)) as freq_q1,
        (SELECT frequency FROM (SELECT frequency, ROW_NUMBER() OVER (ORDER BY frequency) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.50)) as freq_q2,
        (SELECT frequency FROM (SELECT frequency, ROW_NUMBER() OVER (ORDER BY frequency) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.75)) as freq_q3,
        (SELECT monetary_value FROM (SELECT monetary_value, ROW_NUMBER() OVER (ORDER BY monetary_value) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.25)) as mon_q1,
        (SELECT monetary_value FROM (SELECT monetary_value, ROW_NUMBER() OVER (ORDER BY monetary_value) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.50)) as mon_q2,
        (SELECT monetary_value FROM (SELECT monetary_value, ROW_NUMBER() OVER (ORDER BY monetary_value) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.75)) as mon_q3,
        (SELECT recency_days FROM (SELECT recency_days, ROW_NUMBER() OVER (ORDER BY recency_days) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.25)) as rec_q1,
        (SELECT recency_days FROM (SELECT recency_days, ROW_NUMBER() OVER (ORDER BY recency_days) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.50)) as rec_q2,
        (SELECT recency_days FROM (SELECT recency_days, ROW_NUMBER() OVER (ORDER BY recency_days) as rn, COUNT(*) OVER() as cnt FROM customer_metrics) t WHERE rn = FLOOR(cnt * 0.75)) as rec_q3
)
SELECT 
    cm.customer_proxy,
    cm.frequency,
    cm.monetary_value,
    cm.recency_days,
    cm.avg_order_value,
    CASE 
        WHEN cm.frequency >= q.freq_q3 AND cm.monetary_value >= q.mon_q3 THEN 'VIP Customer'
        WHEN cm.frequency >= q.freq_q2 AND cm.monetary_value >= q.mon_q2 THEN 'Loyal Customer'
        WHEN cm.frequency >= q.freq_q2 OR cm.monetary_value >= q.mon_q2 THEN 'Regular Customer'
        WHEN cm.recency_days <= q.rec_q1 THEN 'Recent Customer'
        ELSE 'At-Risk Customer'
    END as customer_segment
FROM customer_metrics cm
CROSS JOIN quartiles q
ORDER BY cm.monetary_value DESC;

-- 10. Seasonal Analysis
SELECT 
    QUARTER(order_date) as quarter,
    MONTHNAME(order_date) as month_name,
    COUNT(*) as orders_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_order_value,
    RANK() OVER (ORDER BY SUM(amount) DESC) as revenue_rank_by_period
FROM orders
GROUP BY QUARTER(order_date), MONTH(order_date), MONTHNAME(order_date)
ORDER BY QUARTER(order_date), MONTH(order_date);

-- 11. Advanced Product Cross-Analysis
CREATE TEMPORARY TABLE IF NOT EXISTS product_pairs AS
SELECT 
    o1.product_id as product_a,
    o2.product_id as product_b,
    COUNT(*) as co_occurrence_count,
    AVG(o1.amount + o2.amount) as avg_combined_value
FROM orders o1
JOIN orders o2 ON o1.order_date = o2.order_date 
    AND o1.product_id < o2.product_id
    AND ABS(TIMESTAMPDIFF(HOUR, o1.order_date, o2.order_date)) <= 24
GROUP BY o1.product_id, o2.product_id
HAVING COUNT(*) > 5
ORDER BY co_occurrence_count DESC
LIMIT 20;

-- 12. Performance Optimization Indexes
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_product ON orders(product_id);
CREATE INDEX idx_orders_amount ON orders(amount);
CREATE INDEX idx_products_category ON products(category);

-- 13. Data Quality Report
SELECT 
    'Data Quality Report' as report_type,
    COUNT(*) as total_orders,
    COUNT(DISTINCT product_id) as unique_products,
    COUNT(DISTINCT order_date) as unique_dates,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) as null_amounts,
    SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END) as invalid_amounts,
    SUM(CASE WHEN product_id NOT IN (SELECT product_id FROM products) THEN 1 ELSE 0 END) as orphaned_orders,
    MIN(order_date) as earliest_date,
    MAX(order_date) as latest_date
FROM orders;
