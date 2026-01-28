CREATE DATABASE churn_sql;
USE churn_sql;

-- 1. Customers table
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  signup_date DATE,
  country VARCHAR(20)
);

-- 2. Subscriptions table
CREATE TABLE subscriptions (
  customer_id INT,
  month DATE,
  status VARCHAR(20)
);

-- 3. Generate 5,000 customers
INSERT INTO customers
SELECT
  ROW_NUMBER() OVER () AS customer_id,
  DATE_ADD('2022-01-01', INTERVAL FLOOR(RAND()*700) DAY),
  ELT(FLOOR(1 + RAND()*4),'India','USA','UK','Germany')
FROM information_schema.tables t1
CROSS JOIN information_schema.tables t2
LIMIT 5000;

-- 4. Generate monthly subscription status (~10k rows)
INSERT INTO subscriptions
SELECT
  customer_id,
  DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND()*180) DAY),
  IF(RAND() < 0.25, 'cancelled', 'active')
FROM customers
CROSS JOIN (SELECT 1 UNION SELECT 2) m;

-- 5. Advanced Churn Analysis with Multiple Techniques
-- Basic churn detection using window functions
WITH status_change AS (
  SELECT
    customer_id,
    month,
    status,
    LAG(status) OVER (PARTITION BY customer_id ORDER BY month) AS prev_status
  FROM subscriptions
)
SELECT COUNT(DISTINCT customer_id) AS churned_customers
FROM status_change
WHERE prev_status = 'active' AND status = 'cancelled';

-- 6. Cohort Analysis for Customer Retention
CREATE VIEW customer_cohorts AS
WITH customer_cohort AS (
    SELECT 
        customer_id,
        DATE_FORMAT(signup_date, '%Y-%m') as signup_cohort,
        signup_date
    FROM customers
),
subscription_activity AS (
    SELECT 
        s.customer_id,
        cc.signup_cohort,
        DATE_FORMAT(s.month, '%Y-%m') as activity_month,
        s.status,
        TIMESTAMPDIFF(MONTH, cc.signup_date, s.month) as months_since_signup
    FROM subscriptions s
    JOIN customer_cohort cc ON s.customer_id = cc.customer_id
),
cohort_retention AS (
    SELECT 
        signup_cohort,
        months_since_signup,
        COUNT(DISTINCT customer_id) as active_customers,
        COUNT(DISTINCT CASE WHEN status = 'active' THEN customer_id END) as retained_customers
    FROM subscription_activity
    GROUP BY signup_cohort, months_since_signup
),
cohort_sizes AS (
    SELECT 
        signup_cohort,
        COUNT(DISTINCT customer_id) as cohort_size
    FROM customer_cohort
    GROUP BY signup_cohort
)
SELECT 
    cr.signup_cohort,
    cr.months_since_signup,
    cr.active_customers,
    cr.retained_customers,
    cs.cohort_size,
    ROUND((cr.retained_customers / cs.cohort_size) * 100, 2) as retention_rate_pct
FROM cohort_retention cr
JOIN cohort_sizes cs ON cr.signup_cohort = cs.signup_cohort
ORDER BY cr.signup_cohort, cr.months_since_signup;

-- 7. Customer Lifetime Value Prediction
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.signup_date,
        c.country,
        COUNT(s.month) as total_months_active,
        SUM(CASE WHEN s.status = 'active' THEN 1 ELSE 0 END) as active_months,
        SUM(CASE WHEN s.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_months,
        MAX(s.month) as last_activity_date,
        MIN(CASE WHEN s.status = 'cancelled' THEN s.month END) as first_churn_date,
        DATEDIFF(CURDATE(), MAX(s.month)) as days_since_last_activity
    FROM customers c
    LEFT JOIN subscriptions s ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, c.signup_date, c.country
),
clv_calculation AS (
    SELECT 
        customer_id,
        country,
        total_months_active,
        active_months,
        cancelled_months,
        days_since_last_activity,
        CASE 
            WHEN active_months = 0 THEN 0
            ELSE ROUND((active_months / total_months_active) * 100, 2)
        END as retention_rate,
        CASE 
            WHEN total_months_active = 0 THEN 0
            ELSE active_months * 29.99 -- Assuming $29.99 monthly subscription
        END as estimated_clv,
        CASE 
            WHEN days_since_last_activity > 90 THEN 'High Risk'
            WHEN days_since_last_activity > 30 THEN 'Medium Risk'
            WHEN cancelled_months > active_months THEN 'High Risk'
            WHEN retention_rate < 50 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END as churn_risk_level
    FROM customer_metrics
)
SELECT 
    churn_risk_level,
    country,
    COUNT(*) as customer_count,
    AVG(estimated_clv) as avg_clv,
    AVG(retention_rate) as avg_retention_rate,
    SUM(estimated_clv) as total_clv
FROM clv_calculation
GROUP BY churn_risk_level, country
ORDER BY churn_risk_level, avg_clv DESC;

-- 8. Advanced Churn Prediction Model
CREATE VIEW churn_prediction AS
WITH customer_features AS (
    SELECT 
        c.customer_id,
        c.country,
        DATEDIFF(CURDATE(), c.signup_date) as days_since_signup,
        COUNT(s.month) as subscription_months,
        SUM(CASE WHEN s.status = 'active' THEN 1 ELSE 0 END) as active_periods,
        SUM(CASE WHEN s.status = 'cancelled' THEN 1 ELSE 0 END) as cancel_periods,
        AVG(CASE WHEN s.status = 'active' THEN 1 ELSE 0 END) as avg_activity_rate,
        STDDEV(CASE WHEN s.status = 'active' THEN 1 ELSE 0 END) as activity_volatility,
        MAX(s.month) as last_subscription_date,
        MIN(s.month) as first_subscription_date,
        COUNT(DISTINCT DATE_FORMAT(s.month, '%Y-%m')) as distinct_months_engaged
    FROM customers c
    LEFT JOIN subscriptions s ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, c.country, c.signup_date
),
churn_indicators AS (
    SELECT 
        customer_id,
        country,
        days_since_signup,
        subscription_months,
        active_periods,
        cancel_periods,
        avg_activity_rate,
        activity_volatility,
        distinct_months_engaged,
        DATEDIFF(CURDATE(), last_subscription_date) as days_since_last_activity,
        -- Risk scoring algorithm
        CASE 
            WHEN cancel_periods > active_periods THEN 40
            ELSE 0
        END +
        CASE 
            WHEN avg_activity_rate < 0.3 THEN 30
            WHEN avg_activity_rate < 0.5 THEN 20
            WHEN avg_activity_rate < 0.7 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN DATEDIFF(CURDATE(), last_subscription_date) > 90 THEN 30
            WHEN DATEDIFF(CURDATE(), last_subscription_date) > 60 THEN 20
            WHEN DATEDIFF(CURDATE(), last_subscription_date) > 30 THEN 10
            ELSE 0
        END as churn_risk_score
    FROM customer_features
)
SELECT 
    customer_id,
    country,
    churn_risk_score,
    CASE 
        WHEN churn_risk_score >= 80 THEN 'Very High Risk'
        WHEN churn_risk_score >= 60 THEN 'High Risk'
        WHEN churn_risk_score >= 40 THEN 'Medium Risk'
        WHEN churn_risk_score >= 20 THEN 'Low Risk'
        ELSE 'Very Low Risk'
    END as risk_category,
    days_since_last_activity,
    avg_activity_rate,
    active_periods,
    cancel_periods
FROM churn_indicators
ORDER BY churn_risk_score DESC;

-- 9. Geographic Churn Analysis
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_id) as total_customers,
    COUNT(DISTINCT CASE WHEN cp.risk_category IN ('Very High Risk', 'High Risk') 
          THEN c.customer_id END) as high_risk_customers,
    ROUND(
        COUNT(DISTINCT CASE WHEN cp.risk_category IN ('Very High Risk', 'High Risk') 
              THEN c.customer_id END) * 100.0 / COUNT(DISTINCT c.customer_id), 2
    ) as churn_risk_rate,
    AVG(cp.churn_risk_score) as avg_risk_score
FROM customers c
JOIN churn_prediction cp ON c.customer_id = cp.customer_id
GROUP BY c.country
ORDER BY churn_risk_rate DESC;

-- 10. Time-based Churn Pattern Analysis
WITH monthly_churn AS (
    SELECT 
        DATE_FORMAT(s.month, '%Y-%m') as month,
        COUNT(DISTINCT s.customer_id) as total_active,
        COUNT(DISTINCT CASE WHEN s.status = 'cancelled' THEN s.customer_id END) as churned,
        ROUND(
            COUNT(DISTINCT CASE WHEN s.status = 'cancelled' THEN s.customer_id END) * 100.0 / 
            COUNT(DISTINCT s.customer_id), 2
        ) as monthly_churn_rate
    FROM subscriptions s
    GROUP BY DATE_FORMAT(s.month, '%Y-%m')
    ORDER BY month
)
SELECT 
    month,
    total_active,
    churned,
    monthly_churn_rate,
    LAG(monthly_churn_rate) OVER (ORDER BY month) as prev_month_churn_rate,
    ROUND(
        monthly_churn_rate - LAG(monthly_churn_rate) OVER (ORDER BY month), 2
    ) as churn_rate_change
FROM monthly_churn
WHERE month IS NOT NULL
ORDER BY month;

-- 11. Customer Segmentation for Retention Strategies
CREATE TEMPORARY TABLE IF NOT EXISTS retention_segments AS
WITH customer_segments AS (
    SELECT 
        c.customer_id,
        c.country,
        cp.risk_category,
        cp.churn_risk_score,
        CASE 
            WHEN cp.risk_category = 'Very High Risk' THEN 'Immediate Intervention Required'
            WHEN cp.risk_category = 'High Risk' AND c.country IN ('USA', 'UK') THEN 'Premium Retention Program'
            WHEN cp.risk_category = 'High Risk' THEN 'Standard Retention Program'
            WHEN cp.risk_category = 'Medium Risk' THEN 'Engagement Campaign'
            ELSE 'Monitor Only'
        END as retention_strategy,
        CASE 
            WHEN cp.churn_risk_score >= 80 THEN 'Offer 50% discount + personal call'
            WHEN cp.churn_risk_score >= 60 THEN 'Offer 30% discount + email campaign'
            WHEN cp.churn_risk_score >= 40 THEN 'Send engagement survey'
            WHEN cp.churn_risk_score >= 20 THEN 'Include in loyalty program'
            ELSE 'Regular communication'
        END as recommended_action
    FROM customers c
    JOIN churn_prediction cp ON c.customer_id = cp.customer_id
)
SELECT 
    retention_strategy,
    recommended_action,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_segments), 2) as percentage,
    AVG(churn_risk_score) as avg_risk_score
FROM customer_segments
GROUP BY retention_strategy, recommended_action
ORDER BY avg_risk_score DESC;
