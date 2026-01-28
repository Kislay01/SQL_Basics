-- SQL Stored Procedures and Functions Library
-- Demonstrates advanced SQL programming concepts

USE advanced_analytics_sql;

DELIMITER //

-- 1. Stored Procedure for Customer Segmentation
CREATE PROCEDURE sp_CustomerSegmentation(
    IN p_analysis_date DATE,
    IN p_lookback_months INT DEFAULT 12
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_customer_id INT;
    DECLARE v_segment VARCHAR(50);
    
    -- Cursor for iterating through customers
    DECLARE customer_cursor CURSOR FOR
        SELECT DISTINCT customer_id FROM fact_sales 
        WHERE date_id IN (SELECT date_id FROM dim_date 
                         WHERE full_date >= DATE_SUB(p_analysis_date, INTERVAL p_lookback_months MONTH));
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create temporary table for results
    DROP TEMPORARY TABLE IF EXISTS temp_customer_segments;
    CREATE TEMPORARY TABLE temp_customer_segments (
        customer_id INT,
        total_revenue DECIMAL(12,2),
        total_transactions INT,
        avg_transaction_value DECIMAL(10,2),
        last_purchase_days_ago INT,
        segment VARCHAR(50),
        segment_score INT
    );
    
    -- Open cursor and iterate
    OPEN customer_cursor;
    
    read_loop: LOOP
        FETCH customer_cursor INTO v_customer_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Calculate customer metrics and segment
        INSERT INTO temp_customer_segments
        SELECT 
            f.customer_id,
            SUM(f.total_amount) as total_revenue,
            COUNT(f.sale_id) as total_transactions,
            AVG(f.total_amount) as avg_transaction_value,
            DATEDIFF(p_analysis_date, MAX(d.full_date)) as last_purchase_days_ago,
            CASE 
                WHEN SUM(f.total_amount) > 10000 AND COUNT(f.sale_id) > 20 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 30 THEN 'VIP Customer'
                WHEN SUM(f.total_amount) > 5000 AND COUNT(f.sale_id) > 10 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 60 THEN 'High Value Customer'
                WHEN SUM(f.total_amount) > 2000 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 90 THEN 'Regular Customer'
                WHEN DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 180 THEN 'Occasional Customer'
                ELSE 'At Risk Customer'
            END as segment,
            CASE 
                WHEN SUM(f.total_amount) > 10000 AND COUNT(f.sale_id) > 20 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 30 THEN 100
                WHEN SUM(f.total_amount) > 5000 AND COUNT(f.sale_id) > 10 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 60 THEN 80
                WHEN SUM(f.total_amount) > 2000 AND DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 90 THEN 60
                WHEN DATEDIFF(p_analysis_date, MAX(d.full_date)) <= 180 THEN 40
                ELSE 20
            END as segment_score
        FROM fact_sales f
        JOIN dim_date d ON f.date_id = d.date_id
        WHERE f.customer_id = v_customer_id
          AND d.full_date >= DATE_SUB(p_analysis_date, INTERVAL p_lookback_months MONTH)
        GROUP BY f.customer_id;
        
    END LOOP;
    
    CLOSE customer_cursor;
    
    -- Return results with summary statistics
    SELECT 
        segment,
        COUNT(*) as customer_count,
        ROUND(AVG(total_revenue), 2) as avg_revenue,
        ROUND(AVG(total_transactions), 1) as avg_transactions,
        ROUND(AVG(avg_transaction_value), 2) as avg_transaction_value,
        ROUND(AVG(last_purchase_days_ago), 1) as avg_days_since_last_purchase,
        ROUND(SUM(total_revenue), 2) as segment_total_revenue,
        ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM temp_customer_segments)), 2) as segment_percentage
    FROM temp_customer_segments
    GROUP BY segment
    ORDER BY segment_score DESC;
    
    DROP TEMPORARY TABLE temp_customer_segments;
END//

-- 2. Function for Revenue Forecasting
CREATE FUNCTION fn_RevenueForcast(
    p_product_id INT,
    p_forecast_months INT
) RETURNS DECIMAL(12,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_avg_monthly_revenue DECIMAL(12,2);
    DECLARE v_growth_rate DECIMAL(5,4);
    DECLARE v_seasonality_factor DECIMAL(5,4);
    DECLARE v_forecast DECIMAL(12,2);
    
    -- Calculate average monthly revenue for the product
    SELECT AVG(monthly_revenue) INTO v_avg_monthly_revenue
    FROM (
        SELECT SUM(f.total_amount) as monthly_revenue
        FROM fact_sales f
        JOIN dim_date d ON f.date_id = d.date_id
        WHERE f.product_id = p_product_id
        GROUP BY d.year, d.month
    ) monthly_data;
    
    -- Calculate growth rate (simplified linear trend)
    SELECT 
        COALESCE(
            (MAX(monthly_revenue) - MIN(monthly_revenue)) / 
            (COUNT(*) * MIN(monthly_revenue)), 0
        ) INTO v_growth_rate
    FROM (
        SELECT SUM(f.total_amount) as monthly_revenue
        FROM fact_sales f
        JOIN dim_date d ON f.date_id = d.date_id
        WHERE f.product_id = p_product_id
        GROUP BY d.year, d.month
        ORDER BY d.year, d.month
    ) trend_data;
    
    -- Apply simple compound growth
    SET v_forecast = v_avg_monthly_revenue * POWER((1 + v_growth_rate), p_forecast_months);
    
    RETURN COALESCE(v_forecast, 0);
END//

-- 3. Procedure for Dynamic Pivot Tables
CREATE PROCEDURE sp_DynamicSalesPivot(
    IN p_pivot_column VARCHAR(50),
    IN p_metric VARCHAR(50),
    IN p_year INT
)
BEGIN
    SET @sql = NULL;
    SET @pivot_sql = '';
    
    -- Build dynamic pivot columns
    CASE p_pivot_column
        WHEN 'category' THEN 
            SELECT GROUP_CONCAT(DISTINCT
                CONCAT('SUM(CASE WHEN p.category = ''', category, ''' THEN f.', p_metric, ' END) AS `', category, '`')
            ) INTO @pivot_sql
            FROM dim_products;
            
        WHEN 'customer_segment' THEN 
            SELECT GROUP_CONCAT(DISTINCT
                CONCAT('SUM(CASE WHEN c.customer_segment = ''', customer_segment, ''' THEN f.', p_metric, ' END) AS `', customer_segment, '`')
            ) INTO @pivot_sql
            FROM dim_customers;
            
        WHEN 'region' THEN 
            SELECT GROUP_CONCAT(DISTINCT
                CONCAT('SUM(CASE WHEN s.region = ''', region, ''' THEN f.', p_metric, ' END) AS `', region, '`')
            ) INTO @pivot_sql
            FROM dim_stores;
    END CASE;
    
    -- Construct the full query
    SET @sql = CONCAT(
        'SELECT d.month, d.month_name, ',
        @pivot_sql,
        ', SUM(f.', p_metric, ') as total ',
        'FROM fact_sales f ',
        'JOIN dim_date d ON f.date_id = d.date_id '
    );
    
    CASE p_pivot_column
        WHEN 'category' THEN 
            SET @sql = CONCAT(@sql, 'JOIN dim_products p ON f.product_id = p.product_id ');
        WHEN 'customer_segment' THEN 
            SET @sql = CONCAT(@sql, 'JOIN dim_customers c ON f.customer_id = c.customer_id ');
        WHEN 'region' THEN 
            SET @sql = CONCAT(@sql, 'JOIN dim_stores s ON f.store_id = s.store_id ');
    END CASE;
    
    SET @sql = CONCAT(@sql, 'WHERE d.year = ', p_year, ' GROUP BY d.month, d.month_name ORDER BY d.month');
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//

-- 4. Advanced Trigger for Audit Trail
CREATE TABLE sales_audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50),
    operation_type VARCHAR(10),
    record_id INT,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(50),
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_info JSON
);

CREATE TRIGGER tr_fact_sales_audit
AFTER UPDATE ON fact_sales
FOR EACH ROW
BEGIN
    INSERT INTO sales_audit_log (
        table_name, 
        operation_type, 
        record_id, 
        old_values, 
        new_values, 
        changed_by,
        session_info
    ) VALUES (
        'fact_sales',
        'UPDATE',
        NEW.sale_id,
        JSON_OBJECT(
            'product_id', OLD.product_id,
            'customer_id', OLD.customer_id,
            'total_amount', OLD.total_amount,
            'quantity', OLD.quantity
        ),
        JSON_OBJECT(
            'product_id', NEW.product_id,
            'customer_id', NEW.customer_id,
            'total_amount', NEW.total_amount,
            'quantity', NEW.quantity
        ),
        USER(),
        JSON_OBJECT(
            'connection_id', CONNECTION_ID(),
            'ip_address', 'N/A',
            'application', 'MySQL'
        )
    );
END//

-- 5. Recursive CTE for Hierarchical Data Analysis
-- First, let's create a simple hierarchy table
CREATE TABLE product_hierarchy (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    parent_id INT,
    level_type VARCHAR(20)
);

INSERT INTO product_hierarchy VALUES
(1, 'All Products', NULL, 'root'),
(2, 'Electronics', 1, 'category'),
(3, 'Clothing', 1, 'category'),
(4, 'Home & Garden', 1, 'category'),
(5, 'Smartphones', 2, 'subcategory'),
(6, 'Laptops', 2, 'subcategory'),
(7, 'Tablets', 2, 'subcategory'),
(8, 'Men Clothing', 3, 'subcategory'),
(9, 'Women Clothing', 3, 'subcategory'),
(10, 'Furniture', 4, 'subcategory'),
(11, 'Garden Tools', 4, 'subcategory');

-- Recursive procedure to calculate hierarchical sales
CREATE PROCEDURE sp_HierarchicalSalesAnalysis()
BEGIN
    -- Using a temporary table to simulate recursive CTE behavior
    DROP TEMPORARY TABLE IF EXISTS temp_hierarchy_sales;
    CREATE TEMPORARY TABLE temp_hierarchy_sales (
        hierarchy_id INT,
        hierarchy_name VARCHAR(100),
        hierarchy_level VARCHAR(20),
        path VARCHAR(500),
        level_depth INT,
        total_sales DECIMAL(12,2),
        direct_sales DECIMAL(12,2)
    );
    
    -- Insert leaf level data (actual product categories)
    INSERT INTO temp_hierarchy_sales
    SELECT 
        ph.id,
        ph.name,
        ph.level_type,
        ph.name as path,
        3 as level_depth,
        COALESCE(SUM(f.total_amount), 0) as total_sales,
        COALESCE(SUM(f.total_amount), 0) as direct_sales
    FROM product_hierarchy ph
    LEFT JOIN dim_products p ON ph.name = p.category
    LEFT JOIN fact_sales f ON p.product_id = f.product_id
    WHERE ph.level_type = 'subcategory'
    GROUP BY ph.id, ph.name, ph.level_type;
    
    -- Roll up to category level
    INSERT INTO temp_hierarchy_sales
    SELECT 
        ph.id,
        ph.name,
        ph.level_type,
        ph.name as path,
        2 as level_depth,
        COALESCE(SUM(ths.total_sales), 0) as total_sales,
        0 as direct_sales
    FROM product_hierarchy ph
    LEFT JOIN product_hierarchy child ON ph.id = child.parent_id
    LEFT JOIN temp_hierarchy_sales ths ON child.id = ths.hierarchy_id
    WHERE ph.level_type = 'category'
    GROUP BY ph.id, ph.name, ph.level_type;
    
    -- Roll up to root level
    INSERT INTO temp_hierarchy_sales
    SELECT 
        ph.id,
        ph.name,
        ph.level_type,
        ph.name as path,
        1 as level_depth,
        COALESCE(SUM(ths.total_sales), 0) as total_sales,
        0 as direct_sales
    FROM product_hierarchy ph
    LEFT JOIN product_hierarchy child ON ph.id = child.parent_id
    LEFT JOIN temp_hierarchy_sales ths ON child.hierarchy_id = ths.hierarchy_id AND ths.level_depth = 2
    WHERE ph.level_type = 'root'
    GROUP BY ph.id, ph.name, ph.level_type;
    
    -- Return hierarchical view
    SELECT 
        CONCAT(REPEAT('  ', 3 - level_depth), hierarchy_name) as hierarchy_display,
        hierarchy_level,
        level_depth,
        ROUND(total_sales, 2) as total_sales,
        ROUND(direct_sales, 2) as direct_sales,
        CASE 
            WHEN level_depth = 1 THEN 100.0
            ELSE ROUND((total_sales * 100.0 / (SELECT total_sales FROM temp_hierarchy_sales WHERE level_depth = 1)), 2)
        END as percentage_of_total
    FROM temp_hierarchy_sales
    ORDER BY level_depth, hierarchy_id;
    
    DROP TEMPORARY TABLE temp_hierarchy_sales;
END//

-- 6. Function for Customer Lifetime Value Calculation
CREATE FUNCTION fn_CalculateCustomerLTV(
    p_customer_id INT,
    p_prediction_months INT DEFAULT 12
) RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_avg_monthly_revenue DECIMAL(10,2);
    DECLARE v_purchase_frequency DECIMAL(5,2);
    DECLARE v_retention_rate DECIMAL(5,4);
    DECLARE v_ltv DECIMAL(10,2);
    
    -- Calculate average monthly revenue per customer
    SELECT 
        COALESCE(AVG(monthly_revenue), 0),
        COALESCE(AVG(monthly_transactions), 0)
    INTO v_avg_monthly_revenue, v_purchase_frequency
    FROM (
        SELECT 
            DATE_FORMAT(d.full_date, '%Y-%m') as month,
            SUM(f.total_amount) as monthly_revenue,
            COUNT(f.sale_id) as monthly_transactions
        FROM fact_sales f
        JOIN dim_date d ON f.date_id = d.date_id
        WHERE f.customer_id = p_customer_id
        GROUP BY DATE_FORMAT(d.full_date, '%Y-%m')
    ) monthly_data;
    
    -- Calculate retention rate (simplified)
    SELECT 
        COUNT(DISTINCT DATE_FORMAT(d.full_date, '%Y-%m')) / 12.0
    INTO v_retention_rate
    FROM fact_sales f
    JOIN dim_date d ON f.date_id = d.date_id
    WHERE f.customer_id = p_customer_id;
    
    -- Simple LTV calculation: monthly_value * retention_rate * prediction_months
    SET v_ltv = v_avg_monthly_revenue * v_retention_rate * p_prediction_months;
    
    RETURN COALESCE(v_ltv, 0);
END//

-- 7. Procedure for A/B Testing Analysis
CREATE TABLE ab_test_assignments (
    customer_id INT,
    test_name VARCHAR(50),
    test_group VARCHAR(20),
    assignment_date DATE,
    PRIMARY KEY (customer_id, test_name)
);

-- Sample A/B test data
INSERT INTO ab_test_assignments
SELECT 
    customer_id,
    'discount_campaign_2023' as test_name,
    CASE WHEN customer_id % 2 = 0 THEN 'control' ELSE 'treatment' END as test_group,
    '2023-06-01' as assignment_date
FROM dim_customers
WHERE customer_id <= 1000;

CREATE PROCEDURE sp_AnalyzeABTest(
    IN p_test_name VARCHAR(50),
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        ab.test_group,
        COUNT(DISTINCT ab.customer_id) as customers_in_group,
        COUNT(f.sale_id) as total_transactions,
        ROUND(SUM(f.total_amount), 2) as total_revenue,
        ROUND(AVG(f.total_amount), 2) as avg_transaction_value,
        ROUND(SUM(f.total_amount) / COUNT(DISTINCT ab.customer_id), 2) as revenue_per_customer,
        ROUND(COUNT(f.sale_id) * 1.0 / COUNT(DISTINCT ab.customer_id), 2) as transactions_per_customer,
        -- Statistical significance indicators
        COUNT(DISTINCT f.customer_id) as active_customers,
        ROUND((COUNT(DISTINCT f.customer_id) * 100.0 / COUNT(DISTINCT ab.customer_id)), 2) as participation_rate
    FROM ab_test_assignments ab
    LEFT JOIN fact_sales f ON ab.customer_id = f.customer_id
    LEFT JOIN dim_date d ON f.date_id = d.date_id
    WHERE ab.test_name = p_test_name
      AND (f.sale_id IS NULL OR d.full_date BETWEEN p_start_date AND p_end_date)
    GROUP BY ab.test_group
    ORDER BY ab.test_group;
    
    -- Additional statistical analysis
    SELECT 
        'Statistical Summary' as analysis_type,
        COUNT(DISTINCT CASE WHEN ab.test_group = 'control' THEN ab.customer_id END) as control_size,
        COUNT(DISTINCT CASE WHEN ab.test_group = 'treatment' THEN ab.customer_id END) as treatment_size,
        ROUND(AVG(CASE WHEN ab.test_group = 'control' THEN f.total_amount END), 2) as control_avg_transaction,
        ROUND(AVG(CASE WHEN ab.test_group = 'treatment' THEN f.total_amount END), 2) as treatment_avg_transaction,
        ROUND(
            (AVG(CASE WHEN ab.test_group = 'treatment' THEN f.total_amount END) - 
             AVG(CASE WHEN ab.test_group = 'control' THEN f.total_amount END)) * 100.0 / 
             AVG(CASE WHEN ab.test_group = 'control' THEN f.total_amount END), 2
        ) as lift_percentage
    FROM ab_test_assignments ab
    LEFT JOIN fact_sales f ON ab.customer_id = f.customer_id
    LEFT JOIN dim_date d ON f.date_id = d.date_id
    WHERE ab.test_name = p_test_name
      AND d.full_date BETWEEN p_start_date AND p_end_date;
END//

DELIMITER ;

-- Usage examples and test calls
-- CALL sp_CustomerSegmentation('2023-12-31', 12);
-- SELECT fn_RevenueForcast(1, 6) as six_month_forecast;
-- CALL sp_DynamicSalesPivot('category', 'total_amount', 2023);
-- CALL sp_HierarchicalSalesAnalysis();
-- SELECT fn_CalculateCustomerLTV(1, 12) as customer_ltv;
-- CALL sp_AnalyzeABTest('discount_campaign_2023', '2023-06-01', '2023-12-31');