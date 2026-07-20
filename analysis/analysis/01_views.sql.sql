USE ecommerce_analysis;

DROP VIEW IF EXISTS v_executive_dashboard;
DROP VIEW IF EXISTS v_clv_by_cohort;
DROP VIEW IF EXISTS v_repeat_rate_by_category;
DROP VIEW IF EXISTS v_churned_customers;
DROP VIEW IF EXISTS v_product_abc_classification;
DROP VIEW IF EXISTS v_high_risk_products;
DROP VIEW IF EXISTS v_inventory_risk;
DROP VIEW IF EXISTS v_basket_affinity;
DROP VIEW IF EXISTS v_seasonal_revenue;
DROP VIEW IF EXISTS v_acquisition_trend;
DROP VIEW IF EXISTS v_financial_impact_bad_orders;
DROP VIEW IF EXISTS v_avg_time_to_second_purchase;
DROP VIEW IF EXISTS v_return_cancel_trend;

CREATE VIEW v_executive_dashboard AS
WITH realised_orders AS (
    SELECT * FROM orders WHERE Status NOT IN ('Cancelled','Returned')
)
SELECT
    (SELECT COUNT(*) FROM customers) AS total_customers,
    (SELECT COUNT(DISTINCT Customer_ID) FROM realised_orders) AS active_customers,
    (SELECT COUNT(*) FROM realised_orders) AS completed_orders,
    ROUND((SELECT COUNT(*) FROM realised_orders) / (SELECT COUNT(*) FROM orders) * 100, 1) AS completion_rate_pct,
    (SELECT SUM(Quantity * Price) FROM realised_orders JOIN products USING(Product_ID)) AS realised_revenue,
    ROUND((SELECT SUM(Quantity * Price) FROM realised_orders JOIN products USING(Product_ID)) / 
          NULLIF((SELECT COUNT(*) FROM realised_orders), 0), 2) AS avg_order_value,
    (SELECT COUNT(DISTINCT Product_ID) FROM realised_orders) AS products_sold,
    (SELECT COUNT(*) FROM products WHERE Stock < 10) AS critical_low_stock_products
FROM dual;

CREATE VIEW v_clv_by_cohort AS
WITH customer_first_order AS (
    SELECT 
        Customer_ID,
        MIN(Order_Date) AS first_order_date
    FROM orders
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Customer_ID
),
cohort_revenue AS (
    SELECT
        DATE_FORMAT(cfo.first_order_date, '%Y-%m') AS cohort_month,
        DATE_FORMAT(o.Order_Date, '%Y-%m') AS order_month,
        TIMESTAMPDIFF(MONTH, cfo.first_order_date, o.Order_Date) AS month_index,
        COUNT(DISTINCT cfo.Customer_ID) AS cohort_size,
        SUM(o.Quantity * p.Price) AS revenue
    FROM customer_first_order cfo
    JOIN orders o ON cfo.Customer_ID = o.Customer_ID
    JOIN products p ON o.Product_ID = p.Product_ID
    WHERE o.Status NOT IN ('Cancelled','Returned')
    GROUP BY cohort_month, order_month, month_index
)
SELECT 
    cohort_month,
    month_index,
    revenue,
    ROUND(revenue / cohort_size, 2) AS revenue_per_customer
FROM cohort_revenue;

CREATE VIEW v_repeat_rate_by_category AS
WITH customer_category_orders AS (
    SELECT 
        Customer_ID,
        Category_ID,
        COUNT(DISTINCT Order_ID) AS order_count
    FROM orders 
    JOIN products USING(Product_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Customer_ID, Category_ID
)
SELECT 
    c.Category_Name,
    COUNT(DISTINCT Customer_ID) AS total_buyers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
    ROUND(100 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / 
          NULLIF(COUNT(DISTINCT Customer_ID), 0), 2) AS repeat_rate_pct
FROM customer_category_orders cco
JOIN categories c USING(Category_ID)
GROUP BY c.Category_Name;

CREATE VIEW v_churned_customers AS
SELECT 
    Customer_ID,
    Customer_Name,
    City,
    MAX(Order_Date) AS last_order_date,
    DATEDIFF(CURDATE(), MAX(Order_Date)) AS days_inactive,
    SUM(Quantity * Price) AS historical_total_spend
FROM customers 
JOIN orders USING(Customer_ID)
JOIN products USING(Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY Customer_ID, Customer_Name, City
HAVING days_inactive > 90;

CREATE VIEW v_product_abc_classification AS
WITH product_revenue AS (
    SELECT 
        Product_ID,
        Product_Name,
        Category_Name,
        SUM(Quantity * Price) AS revenue,
        SUM(Quantity) AS units_sold
    FROM products
    JOIN orders USING(Product_ID)
    JOIN categories USING(Category_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Product_ID, Product_Name, Category_Name
),
total_revenue AS (
    SELECT SUM(revenue) AS grand_total FROM product_revenue
)
SELECT 
    pr.*,
    ROUND(100 * SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / grand_total, 2) AS cumulative_pct,
    CASE 
        WHEN SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / grand_total <= 0.8 THEN 'A (Top 80%)'
        WHEN SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / grand_total <= 0.95 THEN 'B (80-95%)'
        ELSE 'C (Bottom 5%)'
    END AS abc_class
FROM product_revenue pr
CROSS JOIN total_revenue;

CREATE VIEW v_high_risk_products AS
SELECT 
    Product_ID,
    Product_Name,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END) AS bad_orders,
    ROUND(100 * SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END) / COUNT(*), 2) AS bad_rate_pct,
    ROUND(AVG(Price), 2) AS avg_price
FROM orders
JOIN products USING(Product_ID)
GROUP BY Product_ID, Product_Name
HAVING total_orders >= 10
ORDER BY bad_rate_pct DESC;

CREATE VIEW v_inventory_risk AS
WITH daily_demand AS (
    SELECT 
        Product_ID,
        DATEDIFF(MAX(Order_Date), MIN(Order_Date)) + 1 AS days_active,
        SUM(Quantity) AS total_demand
    FROM orders
    JOIN products USING(Product_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Product_ID
)
SELECT 
    p.Product_ID,
    p.Product_Name,
    p.Stock AS current_stock,
    ROUND(dd.total_demand / NULLIF(dd.days_active, 0), 2) AS avg_daily_demand,
    ROUND(dd.total_demand / NULLIF(dd.days_active, 0) * 14, 0) AS suggested_reorder_point,
    CASE 
        WHEN p.Stock < ROUND(dd.total_demand / NULLIF(dd.days_active, 0) * 7, 0) THEN 'CRITICAL – Order now!'
        WHEN p.Stock < ROUND(dd.total_demand / NULLIF(dd.days_active, 0) * 14, 0) THEN 'Warning – Reorder soon'
        ELSE 'OK'
    END AS stock_status
FROM products p
JOIN daily_demand dd ON p.Product_ID = dd.Product_ID
WHERE dd.days_active > 30;

CREATE VIEW v_basket_affinity AS
WITH order_pairs AS (
    SELECT 
        o1.Order_ID,
        o1.Product_ID AS product_a,
        o2.Product_ID AS product_b,
        p1.Product_Name AS name_a,
        p2.Product_Name AS name_b
    FROM orders o1
    JOIN orders o2 ON o1.Order_ID = o2.Order_ID AND o1.Product_ID < o2.Product_ID
    JOIN products p1 ON o1.Product_ID = p1.Product_ID
    JOIN products p2 ON o2.Product_ID = p2.Product_ID
    WHERE o1.Status NOT IN ('Cancelled','Returned')
      AND o2.Status NOT IN ('Cancelled','Returned')
)
SELECT 
    name_a,
    name_b,
    COUNT(*) AS co_occurrence_count
FROM order_pairs
GROUP BY name_a, name_b
ORDER BY co_occurrence_count DESC;

CREATE VIEW v_seasonal_revenue AS
SELECT 
    MONTHNAME(Order_Date) AS month_name,
    MONTH(Order_Date) AS month_number,
    COUNT(*) AS orders,
    SUM(Quantity * Price) AS revenue,
    ROUND(AVG(Quantity * Price), 2) AS aov
FROM orders
JOIN products USING(Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY month_name, month_number
ORDER BY month_number;

CREATE VIEW v_acquisition_trend AS
SELECT 
    DATE_FORMAT(Join_Date, '%Y-%m') AS signup_month,
    COUNT(*) AS new_customers,
    LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(Join_Date, '%Y-%m')) AS prev_month,
    ROUND(100 * (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(Join_Date, '%Y-%m'))) / 
          NULLIF(LAG(COUNT(*)) OVER (ORDER BY DATE_FORMAT(Join_Date, '%Y-%m')), 0), 2) AS growth_pct
FROM customers
GROUP BY signup_month;

CREATE VIEW v_financial_impact_bad_orders AS
SELECT 
    'Total Realised Revenue' AS metric,
    ROUND(SUM(Quantity * Price), 2) AS value
FROM orders JOIN products USING(Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
UNION ALL
SELECT 
    'Revenue Lost to Returns/Cancellations',
    ROUND(SUM(Quantity * Price), 2)
FROM orders JOIN products USING(Product_ID)
WHERE Status IN ('Cancelled','Returned')
UNION ALL
SELECT 
    'Percentage Lost',
    ROUND(100 * SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN Quantity * Price ELSE 0 END) / 
          NULLIF(SUM(Quantity * Price), 0), 2)
FROM orders JOIN products USING(Product_ID);

CREATE VIEW v_avg_time_to_second_purchase AS
WITH customer_order_ranks AS (
    SELECT 
        Customer_ID,
        Order_Date,
        ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Order_Date) AS order_sequence
    FROM orders
    WHERE Status NOT IN ('Cancelled','Returned')
)
SELECT 
    ROUND(AVG(DATEDIFF(o2.Order_Date, o1.Order_Date)), 0) AS avg_days_to_second_purchase
FROM customer_order_ranks o1
JOIN customer_order_ranks o2 
    ON o1.Customer_ID = o2.Customer_ID 
    AND o1.order_sequence = 1 
    AND o2.order_sequence = 2;

CREATE VIEW v_return_cancel_trend AS
SELECT 
    DATE_FORMAT(Order_Date, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END) AS bad_orders,
    ROUND(100 * SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END) / COUNT(*), 2) AS bad_rate_pct
FROM orders
GROUP BY month
ORDER BY month;

SHOW FULL TABLES IN ecommerce_analysis WHERE Table_Type = 'VIEW';
