CREATE DATABASE fraud_sql;
USE fraud_sql;

-- 1. Users
CREATE TABLE users (
  user_id INT PRIMARY KEY,
  region VARCHAR(20)
);

-- 2. Transactions
CREATE TABLE transactions (
  txn_id INT PRIMARY KEY,
  user_id INT,
  amount INT,
  txn_time DATETIME
);

-- 3. Generate users
INSERT INTO users
SELECT
  ROW_NUMBER() OVER (),
  ELT(FLOOR(1 + RAND()*4),'Asia','Europe','US','Africa')
FROM information_schema.tables
LIMIT 3000;

-- 4. Generate 80,000 transactions
INSERT INTO transactions
SELECT
  ROW_NUMBER() OVER (),
  FLOOR(1 + RAND()*3000),
  IF(RAND() < 0.05,
     FLOOR(100000 + RAND()*400000),
     FLOOR(100 + RAND()*9000)),
  DATE_ADD('2023-06-01', INTERVAL FLOOR(RAND()*86400) SECOND)
FROM information_schema.tables t1
CROSS JOIN information_schema.tables t2
LIMIT 80000;

-- 5. Advanced Fraud Detection Analysis

-- Basic fraud detection query
SELECT
  user_id,
  COUNT(*) AS high_value_txns,
  SUM(amount) AS total_suspicious_amount
FROM transactions
WHERE amount > 100000
GROUP BY user_id
HAVING COUNT(*) >= 3;

-- 6. Multi-dimensional Fraud Detection System
CREATE VIEW fraud_detection_comprehensive AS
WITH transaction_patterns AS (
    SELECT 
        t.user_id,
        u.region,
        COUNT(*) as total_transactions,
        SUM(t.amount) as total_amount,
        AVG(t.amount) as avg_transaction,
        STDDEV(t.amount) as amount_volatility,
        MIN(t.amount) as min_amount,
        MAX(t.amount) as max_amount,
        COUNT(DISTINCT DATE(t.txn_time)) as active_days,
        MIN(t.txn_time) as first_transaction,
        MAX(t.txn_time) as last_transaction,
        TIMESTAMPDIFF(HOUR, MIN(t.txn_time), MAX(t.txn_time)) as activity_span_hours
    FROM transactions t
    JOIN users u ON t.user_id = u.user_id
    GROUP BY t.user_id, u.region
),
velocity_analysis AS (
    SELECT 
        user_id,
        region,
        total_transactions,
        total_amount,
        avg_transaction,
        amount_volatility,
        max_amount,
        active_days,
        activity_span_hours,
        CASE 
            WHEN activity_span_hours > 0 THEN total_transactions / (activity_span_hours / 24.0)
            ELSE total_transactions
        END as transactions_per_day,
        CASE 
            WHEN activity_span_hours > 0 THEN total_amount / (activity_span_hours / 24.0)
            ELSE total_amount
        END as amount_per_day,
        CASE 
            WHEN max_amount > avg_transaction * 10 THEN 'High'
            WHEN max_amount > avg_transaction * 5 THEN 'Medium' 
            ELSE 'Low'
        END as amount_spike_level
    FROM transaction_patterns
),
fraud_scoring AS (
    SELECT 
        user_id,
        region,
        total_transactions,
        total_amount,
        avg_transaction,
        transactions_per_day,
        amount_per_day,
        amount_spike_level,
        -- Fraud risk scoring algorithm
        CASE 
            WHEN transactions_per_day > 50 THEN 25
            WHEN transactions_per_day > 20 THEN 15
            WHEN transactions_per_day > 10 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN amount_per_day > 1000000 THEN 30
            WHEN amount_per_day > 500000 THEN 20
            WHEN amount_per_day > 100000 THEN 10
            ELSE 0
        END +
        CASE 
            WHEN amount_spike_level = 'High' THEN 25
            WHEN amount_spike_level = 'Medium' THEN 15
            ELSE 0
        END +
        CASE 
            WHEN avg_transaction > 50000 THEN 20
            WHEN avg_transaction > 20000 THEN 10
            ELSE 0
        END as fraud_risk_score
    FROM velocity_analysis
)
SELECT 
    user_id,
    region,
    total_transactions,
    ROUND(total_amount, 2) as total_amount,
    ROUND(avg_transaction, 2) as avg_transaction,
    ROUND(transactions_per_day, 2) as transactions_per_day,
    ROUND(amount_per_day, 2) as amount_per_day,
    amount_spike_level,
    fraud_risk_score,
    CASE 
        WHEN fraud_risk_score >= 80 THEN 'Critical Risk - Immediate Review'
        WHEN fraud_risk_score >= 60 THEN 'High Risk - Priority Investigation'
        WHEN fraud_risk_score >= 40 THEN 'Medium Risk - Enhanced Monitoring'
        WHEN fraud_risk_score >= 20 THEN 'Low Risk - Regular Monitoring'
        ELSE 'Minimal Risk'
    END as risk_classification
FROM fraud_scoring
ORDER BY fraud_risk_score DESC;

-- 7. Time-based Anomaly Detection
CREATE VIEW temporal_fraud_detection AS
WITH hourly_patterns AS (
    SELECT 
        user_id,
        HOUR(txn_time) as transaction_hour,
        COUNT(*) as hourly_transaction_count,
        SUM(amount) as hourly_amount,
        AVG(amount) as hourly_avg_amount
    FROM transactions
    GROUP BY user_id, HOUR(txn_time)
),
user_normal_patterns AS (
    SELECT 
        user_id,
        AVG(hourly_transaction_count) as avg_hourly_transactions,
        STDDEV(hourly_transaction_count) as stddev_hourly_transactions,
        AVG(hourly_amount) as avg_hourly_amount,
        STDDEV(hourly_amount) as stddev_hourly_amount
    FROM hourly_patterns
    GROUP BY user_id
),
anomaly_detection AS (
    SELECT 
        hp.user_id,
        hp.transaction_hour,
        hp.hourly_transaction_count,
        hp.hourly_amount,
        unp.avg_hourly_transactions,
        unp.stddev_hourly_transactions,
        unp.avg_hourly_amount,
        unp.stddev_hourly_amount,
        CASE 
            WHEN unp.stddev_hourly_transactions > 0 AND 
                 ABS(hp.hourly_transaction_count - unp.avg_hourly_transactions) > (2 * unp.stddev_hourly_transactions) 
            THEN 'Transaction Count Anomaly'
            ELSE 'Normal'
        END as transaction_anomaly,
        CASE 
            WHEN unp.stddev_hourly_amount > 0 AND 
                 ABS(hp.hourly_amount - unp.avg_hourly_amount) > (2 * unp.stddev_hourly_amount) 
            THEN 'Amount Anomaly'
            ELSE 'Normal'
        END as amount_anomaly
    FROM hourly_patterns hp
    JOIN user_normal_patterns unp ON hp.user_id = unp.user_id
)
SELECT 
    user_id,
    transaction_hour,
    hourly_transaction_count,
    ROUND(hourly_amount, 2) as hourly_amount,
    transaction_anomaly,
    amount_anomaly,
    CASE 
        WHEN transaction_anomaly != 'Normal' OR amount_anomaly != 'Normal' THEN 'Requires Investigation'
        ELSE 'Normal Pattern'
    END as overall_assessment
FROM anomaly_detection
WHERE transaction_anomaly != 'Normal' OR amount_anomaly != 'Normal'
ORDER BY user_id, transaction_hour;

-- 8. Geographic Fraud Analysis
WITH regional_stats AS (
    SELECT 
        u.region,
        COUNT(DISTINCT u.user_id) as total_users,
        COUNT(t.txn_id) as total_transactions,
        SUM(t.amount) as total_amount,
        AVG(t.amount) as avg_transaction_amount,
        STDDEV(t.amount) as amount_stddev,
        COUNT(CASE WHEN t.amount > 100000 THEN 1 END) as high_value_transactions
    FROM users u
    LEFT JOIN transactions t ON u.user_id = t.user_id
    GROUP BY u.region
),
regional_risk_assessment AS (
    SELECT 
        region,
        total_users,
        total_transactions,
        ROUND(total_amount, 2) as total_amount,
        ROUND(avg_transaction_amount, 2) as avg_transaction_amount,
        high_value_transactions,
        ROUND((high_value_transactions * 100.0 / total_transactions), 2) as high_value_pct,
        ROUND((total_transactions * 1.0 / total_users), 2) as avg_transactions_per_user,
        CASE 
            WHEN (high_value_transactions * 100.0 / total_transactions) > 10 THEN 'High Risk'
            WHEN (high_value_transactions * 100.0 / total_transactions) > 5 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END as regional_risk_level
    FROM regional_stats
    WHERE total_transactions > 0
)
SELECT 
    region,
    total_users,
    total_transactions,
    total_amount,
    avg_transaction_amount,
    high_value_transactions,
    high_value_pct,
    avg_transactions_per_user,
    regional_risk_level,
    RANK() OVER (ORDER BY high_value_pct DESC) as risk_rank
FROM regional_risk_assessment
ORDER BY high_value_pct DESC;

-- 9. Sequential Transaction Pattern Analysis
CREATE VIEW suspicious_patterns AS
WITH sequential_transactions AS (
    SELECT 
        user_id,
        txn_id,
        amount,
        txn_time,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) as prev_txn_time,
        LAG(amount) OVER (PARTITION BY user_id ORDER BY txn_time) as prev_amount,
        LEAD(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) as next_txn_time,
        LEAD(amount) OVER (PARTITION BY user_id ORDER BY txn_time) as next_amount
    FROM transactions
),
pattern_analysis AS (
    SELECT 
        user_id,
        txn_id,
        amount,
        txn_time,
        prev_amount,
        next_amount,
        CASE 
            WHEN prev_txn_time IS NOT NULL THEN 
                TIMESTAMPDIFF(MINUTE, prev_txn_time, txn_time)
            ELSE NULL
        END as minutes_since_prev,
        CASE 
            WHEN next_txn_time IS NOT NULL THEN 
                TIMESTAMPDIFF(MINUTE, txn_time, next_txn_time)
            ELSE NULL
        END as minutes_to_next,
        CASE 
            WHEN amount = prev_amount AND amount = next_amount THEN 'Identical Amount Pattern'
            WHEN amount > 100000 AND prev_amount > 100000 THEN 'Consecutive High Value'
            WHEN TIMESTAMPDIFF(MINUTE, prev_txn_time, txn_time) < 1 THEN 'Rapid Fire Transaction'
            ELSE 'Normal'
        END as pattern_type
    FROM sequential_transactions
)
SELECT 
    user_id,
    COUNT(*) as suspicious_transactions,
    GROUP_CONCAT(DISTINCT pattern_type SEPARATOR ', ') as detected_patterns,
    MIN(txn_time) as first_suspicious_time,
    MAX(txn_time) as last_suspicious_time,
    SUM(amount) as total_suspicious_amount,
    AVG(amount) as avg_suspicious_amount
FROM pattern_analysis
WHERE pattern_type != 'Normal'
GROUP BY user_id
HAVING COUNT(*) >= 2
ORDER BY suspicious_transactions DESC, total_suspicious_amount DESC;

-- 10. Real-time Fraud Alert System
CREATE VIEW fraud_alerts AS
WITH real_time_metrics AS (
    SELECT 
        t.user_id,
        t.txn_id,
        t.amount,
        t.txn_time,
        u.region,
        (SELECT COUNT(*) FROM transactions t2 WHERE t2.user_id = t.user_id AND t2.txn_time BETWEEN DATE_SUB(t.txn_time, INTERVAL 1 HOUR) AND t.txn_time) as transactions_last_hour,
        (SELECT COALESCE(SUM(amount), 0) FROM transactions t2 WHERE t2.user_id = t.user_id AND t2.txn_time BETWEEN DATE_SUB(t.txn_time, INTERVAL 1 HOUR) AND t.txn_time) as amount_last_hour,
        (SELECT COUNT(*) FROM transactions t2 WHERE t2.user_id = t.user_id AND t2.txn_time BETWEEN DATE_SUB(t.txn_time, INTERVAL 1 DAY) AND t.txn_time) as transactions_last_day,
        (SELECT COALESCE(SUM(amount), 0) FROM transactions t2 WHERE t2.user_id = t.user_id AND t2.txn_time BETWEEN DATE_SUB(t.txn_time, INTERVAL 1 DAY) AND t.txn_time) as amount_last_day,
        AVG(t.amount) OVER (
            PARTITION BY t.user_id 
            ORDER BY t.txn_time 
            ROWS BETWEEN 9 PRECEDING AND 1 PRECEDING
        ) as avg_amount_last_10_txns
    FROM transactions t
    JOIN users u ON t.user_id = u.user_id
),
alert_generation AS (
    SELECT 
        user_id,
        txn_id,
        amount,
        txn_time,
        region,
        transactions_last_hour,
        amount_last_hour,
        transactions_last_day,
        amount_last_day,
        avg_amount_last_10_txns,
        CASE 
            WHEN transactions_last_hour > 10 THEN 'HIGH_FREQUENCY_ALERT'
            WHEN amount_last_hour > 500000 THEN 'HIGH_VOLUME_ALERT'
            WHEN amount > COALESCE(avg_amount_last_10_txns * 5, 50000) THEN 'AMOUNT_SPIKE_ALERT'
            WHEN amount > 200000 THEN 'HIGH_VALUE_ALERT'
            ELSE 'NO_ALERT'
        END as alert_type,
        CASE 
            WHEN transactions_last_hour > 15 OR amount_last_hour > 1000000 THEN 'CRITICAL'
            WHEN transactions_last_hour > 10 OR amount_last_hour > 500000 OR amount > 200000 THEN 'HIGH'
            WHEN transactions_last_hour > 5 OR amount > 100000 THEN 'MEDIUM'
            ELSE 'LOW'
        END as alert_priority
    FROM real_time_metrics
)
SELECT 
    user_id,
    txn_id,
    ROUND(amount, 2) as amount,
    txn_time,
    region,
    alert_type,
    alert_priority,
    transactions_last_hour,
    ROUND(amount_last_hour, 2) as amount_last_hour,
    ROUND(COALESCE(avg_amount_last_10_txns, 0), 2) as avg_amount_last_10_txns,
    CASE 
        WHEN alert_priority = 'CRITICAL' THEN 'Immediate action required - Block account temporarily'
        WHEN alert_priority = 'HIGH' THEN 'Review within 15 minutes'
        WHEN alert_priority = 'MEDIUM' THEN 'Review within 1 hour'
        ELSE 'Standard monitoring'
    END as recommended_action
FROM alert_generation
WHERE alert_type != 'NO_ALERT'
ORDER BY 
    CASE alert_priority 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END,
    txn_time DESC;

-- 11. Fraud Investigation Dashboard
SELECT 
    'Fraud Detection Summary' as report_section,
    COUNT(DISTINCT user_id) as total_flagged_users,
    SUM(CASE WHEN risk_classification LIKE '%Critical%' THEN 1 ELSE 0 END) as critical_risk_users,
    SUM(CASE WHEN risk_classification LIKE '%High%' THEN 1 ELSE 0 END) as high_risk_users,
    COUNT(DISTINCT CASE WHEN risk_classification LIKE '%Critical%' OR risk_classification LIKE '%High%' 
          THEN user_id END) as users_requiring_immediate_action
FROM fraud_detection_comprehensive
UNION ALL
SELECT 
    'Financial Impact',
    COUNT(*) as total_suspicious_transactions,
    0,0,
    ROUND(SUM(total_amount), 2) as total_suspicious_amount
FROM fraud_detection_comprehensive 
WHERE fraud_risk_score >= 40;

-- 12. Performance Indexes for Fraud Detection
CREATE INDEX idx_transactions_user_time ON transactions(user_id, txn_time);
CREATE INDEX idx_transactions_amount ON transactions(amount);
CREATE INDEX idx_transactions_time ON transactions(txn_time);
CREATE INDEX idx_users_region ON users(region);
