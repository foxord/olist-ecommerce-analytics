SET search_path TO olist;
-- Три независимых пути от исходных таблиц к GMV. Все столбцы difference должны быть 0.
WITH sales AS (
    SELECT * FROM order_mart WHERE order_status = 'delivered'
), months AS (
    SELECT purchase_month, SUM(revenue) AS revenue FROM sales GROUP BY purchase_month
), states AS (
    SELECT customer_state, SUM(revenue) AS revenue FROM sales GROUP BY customer_state
), categories AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(i.price) AS revenue
    FROM order_items i JOIN orders o USING (order_id)
    JOIN products p USING (product_id) LEFT JOIN category_translation t USING (product_category_name)
    WHERE o.order_status = 'delivered' GROUP BY 1
)
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders,
       SUM(revenue) AS delivered_gmv,
       SUM(revenue) - (SELECT SUM(revenue) FROM months) AS month_difference,
       SUM(revenue) - (SELECT SUM(revenue) FROM states) AS state_difference,
       SUM(revenue) - (SELECT SUM(revenue) FROM categories) AS category_difference,
       SUM(revenue) - (SELECT SUM(monetary) FROM customer_rfm) AS rfm_difference
FROM sales;

SELECT COUNT(*) AS all_orders, COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'delivered') / COUNT(*), 3) AS delivered_pct
FROM orders;

SELECT COUNT(*) AS delivered_orders, COUNT(DISTINCT customer_unique_id) AS customers,
       ROUND(SUM(revenue) / COUNT(*), 2) AS aov,
       COUNT(*) FILTER (WHERE is_late) AS late_orders, COUNT(is_late) AS known_delivery,
       ROUND(AVG(review_score), 3) AS avg_score
FROM order_mart WHERE order_status = 'delivered';
