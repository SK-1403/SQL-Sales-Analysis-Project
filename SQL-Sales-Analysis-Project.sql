-- Use the target database
USE DataWarehouseAnalytics;

-----------------------------------------------------------------------------------------------------------------
-- 1. CHANGE OVER TIME ANALYSIS
-- Analyze how sales performance evolves over time to identify trends and seasonality.
-----------------------------------------------------------------------------------------------------------------

SELECT
    DATETRUNC(month, order_date) AS sales_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY sales_month;


-----------------------------------------------------------------------------------------------------------------
-- 2. CUMULATIVE SALES ANALYSIS
-- Calculate running total sales per month to understand long-term growth patterns.
-----------------------------------------------------------------------------------------------------------------

SELECT
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total
FROM (
    SELECT 
        DATETRUNC(month, order_date) AS order_date,
        SUM(sales_amount) AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
) t
ORDER BY order_date;


-----------------------------------------------------------------------------------------------------------------
-- 3. PRODUCT PERFORMANCE ANALYSIS
-- Compare current product sales with average and previous year sales to measure performance.
-----------------------------------------------------------------------------------------------------------------

WITH Yearly_Product_Sales AS (
    SELECT 
        YEAR(f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT 
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_from_avg,
    CASE 
        WHEN current_sales > AVG(current_sales) OVER (PARTITION BY product_name) THEN 'Above Avg'
        WHEN current_sales < AVG(current_sales) OVER (PARTITION BY product_name) THEN 'Below Avg'
        ELSE 'On Avg'
    END AS avg_comparison,
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_from_prev,
    CASE 
        WHEN current_sales > LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Increase'
        WHEN current_sales < LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Decrease'
        ELSE 'No Change'
    END AS year_over_year_change
FROM Yearly_Product_Sales
ORDER BY product_name, order_year;


-----------------------------------------------------------------------------------------------------------------
-- 4. TOP CUSTOMERS BY REVENUE
-- Identify the top 10 customers contributing the most to revenue.
-----------------------------------------------------------------------------------------------------------------

SELECT 
    c.customer_key,
    SUM(f.sales_amount) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM gold.fact_sales f
JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key
ORDER BY total_revenue DESC
LIMIT 10 ;


-----------------------------------------------------------------------------------------------------------------
-- 5. NEW VS RETURNING CUSTOMERS
-- Classify customers as New or Returning based on their order history.
-----------------------------------------------------------------------------------------------------------------

SELECT 
    customer_key,
    MIN(order_date) AS first_order_date,
    COUNT(order_id) AS total_orders,
    CASE 
        WHEN COUNT(order_id) = 1 THEN 'New Customer'
        ELSE 'Returning Customer'
    END AS customer_type
FROM gold.fact_sales
GROUP BY customer_key
ORDER BY total_orders DESC;


-----------------------------------------------------------------------------------------------------------------
-- 6. REGIONAL SALES ANALYSIS
-- Compare sales across different regions to identify high-performing areas.
-----------------------------------------------------------------------------------------------------------------

SELECT 
    r.region_name,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.order_id) AS total_orders,
    AVG(f.sales_amount) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_region r
    ON f.region_key = r.region_key
GROUP BY r.region_name
ORDER BY total_sales DESC;


-----------------------------------------------------------------------------------------------------------------
-- 7. PRODUCT CATEGORY ANALYSIS
-- Find the best and worst performing product categories by revenue.
-----------------------------------------------------------------------------------------------------------------

SELECT 
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    SUM(f.quantity) AS total_units_sold,
    ROUND(AVG(f.sales_amount), 2) AS avg_sale_value
FROM gold.fact_sales f
JOIN gold.dim_products p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;


-----------------------------------------------------------------------------------------------------------------
-- 8. AVERAGE ORDER VALUE & PROFITABILITY
-- Calculate AOV and profit margins for performance tracking (assuming profit column exists).
-----------------------------------------------------------------------------------------------------------------

SELECT 
    DATETRUNC(month, order_date) AS sales_month,
    SUM(sales_amount) / COUNT(DISTINCT order_id) AS avg_order_value,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales_amount) * 100, 2) AS profit_margin_percentage
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY sales_month;
