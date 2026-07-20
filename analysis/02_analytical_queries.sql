SELECT
    (SELECT COUNT(*) FROM customers)  AS total_customers,
    (SELECT COUNT(*) FROM products)   AS total_products,
    (SELECT COUNT(*) FROM categories) AS total_categories,
    (SELECT COUNT(*) FROM orders)     AS total_orders;



SELECT
    COUNT(*)                                                   AS total_orders,
    SUM(Quantity *Price)                                  AS gross_order_value,
    SUM(CASE WHEN Status NOT IN ('Cancelled','Returned')
             THEN Quantity * Price ELSE 0 END)             AS realised_revenue,
    ROUND(100 * SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                       AS pct_cancelled_or_returned
FROM orders 
JOIN products using(Product_ID);



SELECT
    Status,
    COUNT(*)                                   AS order_count,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) AS pct_of_orders
FROM orders
GROUP BY Status
ORDER BY order_count DESC;



SELECT
    DATE_FORMAT(Order_Date, '%Y-%m')                          AS order_month,
    COUNT(*)                                                    AS orders_placed,
    SUM(Quantity * Price)                                   AS realised_revenue
FROM orders 
JOIN products using (Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY order_month
ORDER BY order_month;



WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(Order_Date, '%Y-%m') AS order_month,
        SUM(Quantity * Price)          AS revenue
    FROM orders 
    JOIN products using (Product_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month)               AS prev_month_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
          / LAG(revenue) OVER (ORDER BY order_month), 2)    AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


SELECT
    order_month,
    revenue,
    SUM(revenue) OVER (ORDER BY order_month) AS cumulative_revenue
FROM (
    SELECT
        DATE_FORMAT(Order_Date, '%Y-%m') AS order_month,
        SUM(Quantity * Price)          AS revenue
    FROM orders 
    JOIN products using(Product_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY order_month
) monthly
ORDER BY order_month;


SELECT
    Customer_ID,
    Customer_Name,
    City,
    COUNT(Order_ID)              AS total_orders,
    SUM(Quantity * p.Price)      AS lifetime_value
FROM customers 
JOIN orders using (Customer_ID)
JOIN products using (Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY Customer_ID, Customer_Name,City
ORDER BY lifetime_value DESC
LIMIT 10;


WITH customer_orders AS (
    SELECT Customer_ID, COUNT(*) AS order_count
    FROM orders
    GROUP BY Customer_ID
)
SELECT
    CASE WHEN order_count = 1 THEN 'One-time customer'
         ELSE 'Repeat customer' END AS customer_type,
    COUNT(*)                                                AS num_customers,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM customer_orders), 2) AS pct_of_customers
FROM customer_orders
GROUP BY customer_type;


WITH rfm_base AS (
    SELECT
        Customer_ID,
        Customer_Name,
        DATEDIFF((SELECT MAX(Order_Date) FROM orders), MAX(Order_Date)) AS recency_days,
        COUNT(Order_ID)                                                 AS frequency,
        SUM(Quantity * Price)                                         AS monetary
    FROM customers
    JOIN orders using (Customer_ID)
    JOIN products using (Product_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Customer_ID, Customer_Name
),
rfm_scored AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,   
        NTILE(4) OVER (ORDER BY frequency ASC)      AS f_score,  
        NTILE(4) OVER (ORDER BY monetary ASC)       AS m_score   
    FROM rfm_base
)
SELECT
    Customer_ID,
    Customer_Name,
    recency_days,
    frequency,
    monetary,
    (r_score + f_score + m_score)                        AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Champion'
        WHEN (r_score + f_score + m_score) >= 7  THEN 'Loyal'
        WHEN (r_score + f_score + m_score) >= 4  THEN 'At Risk'
        ELSE 'Lost'
    END                                                   AS segment
FROM rfm_scored
ORDER BY rfm_total DESC
LIMIT 20;



SELECT
    Customer_ID,
    Customer_Name,
    City,
    MAX(Order_Date)                                                       AS last_order_date,
    DATEDIFF((SELECT MAX(Order_Date) FROM orders), MAX(o.Order_Date))       AS days_since_last_order
FROM customers 
JOIN orders using (Customer_ID)
GROUP BY Customer_ID, Customer_Name, City
HAVING days_since_last_order > 90
ORDER BY days_since_last_order DESC
LIMIT 20;


SELECT
    City,
    COUNT(DISTINCT Customer_ID)          AS customers,
    COUNT(Order_ID)                      AS orders,
    SUM(Quantity * Price)              AS realised_revenue,
    ROUND(SUM(Quantity * Price) / COUNT(DISTINCT Customer_ID), 2) AS revenue_per_customer
FROM customers 
JOIN orders using (Customer_ID)
JOIN products using (Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY City
ORDER BY realised_revenue DESC;


SELECT
    DATE_FORMAT(Join_Date, '%Y-%m') AS signup_month,
    COUNT(*)                        AS new_customers
FROM customers
GROUP BY signup_month
ORDER BY signup_month;



SELECT
Product_ID,
    Product_Name,
    Category_Name,
    SUM(Quantity)                AS units_sold,
    SUM(Quantity *Price)      AS realised_revenue
FROM products 
JOIN orders using (Product_ID)  
JOIN categories using(Category_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY Product_ID, Product_Name, Category_Name
ORDER BY realised_revenue DESC
LIMIT 10;


SELECT
    Category_Name,
    COUNT(DISTINCT Product_ID)   AS products_in_category,
    SUM(Quantity)                AS units_sold,
    SUM(Quantity * Price)      AS realised_revenue
FROM categories
JOIN products using (Category_ID)
JOIN orders using(Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY Category_Name
ORDER BY realised_revenue DESC;


WITH product_revenue AS (
    SELECT
        Category_Name,
        Product_ID,
        Product_Name,
        SUM(Quantity * Price) AS revenue
    FROM products 
    JOIN orders using(Product_ID)
    JOIN categories using(Category_ID)
    WHERE Status NOT IN ('Cancelled','Returned')
    GROUP BY Category_Name, Product_ID, Product_Name
)
SELECT *
FROM (
    SELECT
        Category_Name,
        Product_ID,
        Product_Name,
        revenue,
        RANK() OVER (PARTITION BY Category_Name ORDER BY revenue DESC) AS rank_in_category
    FROM product_revenue
) ranked
WHERE rank_in_category <= 3
ORDER BY Category_Name, rank_in_category;


SELECT
    Product_ID,
    Product_Name,
    Category_Name,
    Price,
    Stock
FROM products 
JOIN categories using(Category_ID)
LEFT JOIN orders using(Product_ID)
WHERE Order_ID IS NULL
ORDER BY Stock DESC;



SELECT
Product_ID,
Product_Name,
Stock                          AS current_stock,
    SUM(Quantity)                  AS units_sold_all_time,
    ROUND(SUM(Quantity) / NULLIF(Stock, 0), 2) AS demand_to_stock_ratio
FROM products 
JOIN orders using(Product_ID)
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY Product_ID, Product_Name, Stock
HAVING Stock < 50
ORDER BY demand_to_stock_ratio DESC
LIMIT 15;


SELECT
    Product_ID,
    Product_Name,
    COUNT(*)                                                          AS total_orders,
    SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END) AS cancelled_or_returned,
    ROUND(100 * SUM(CASE WHEN Status IN ('Cancelled','Returned') THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                             AS pct_cancelled_or_returned
FROM products 
JOIN orders using(Product_ID)
GROUP BY Product_ID, Product_Name
HAVING total_orders >= 5
ORDER BY pct_cancelled_or_returned DESC
LIMIT 15;



SELECT
    DATE_FORMAT(Order_Date, '%Y-%m')       AS order_month,
    ROUND(AVG(Quantity * Price), 2)      AS avg_order_value
FROM orders 
JOIN products using(Product_ID )
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY order_month
ORDER BY order_month;


SELECT
    YEAR(Order_Date)             AS order_year,
    SUM(Quantity * Price)      AS realised_revenue,
    COUNT(*)                       AS total_orders
FROM orders 
JOIN products using(Product_ID )
WHERE Status NOT IN ('Cancelled','Returned')
GROUP BY order_year
ORDER BY order_year;


SELECT
    CASE
        WHEN Quantity BETWEEN 1 AND 5   THEN '1-5 units'
        WHEN Quantity BETWEEN 6 AND 10  THEN '6-10 units'
        WHEN Quantity BETWEEN 11 AND 15 THEN '11-15 units'
        ELSE '16-19 units'
    END                     AS order_size_bucket,
    COUNT(*)                AS num_orders
FROM orders
GROUP BY order_size_bucket
ORDER BY MIN(Quantity);
