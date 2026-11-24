SET search_path TO olist;
-- 1. Продавцы с одинаковым оборотом делят место внутри своего штата.
WITH seller_sales AS (
    SELECT s.seller_state, i.seller_id, SUM(i.price) AS revenue
    FROM order_items i JOIN sellers s USING (seller_id) JOIN orders o USING (order_id)
    WHERE o.order_status = 'delivered' GROUP BY s.seller_state, i.seller_id
)
SELECT *, RANK() OVER (PARTITION BY seller_state ORDER BY revenue DESC) AS place
FROM seller_sales ORDER BY seller_state, place, seller_id;

-- 2 и 4. Сумма с начала наблюдения и среднее за три календарных месяца, включая текущий.
WITH sales AS (
    SELECT purchase_month AS month, SUM(revenue) AS revenue
    FROM order_mart WHERE order_status = 'delivered' GROUP BY purchase_month
), calendar AS (
    SELECT GENERATE_SERIES(MIN(month), MAX(month), INTERVAL '1 month')::date AS month FROM sales
), monthly AS (
    SELECT month, COALESCE(revenue, 0) AS revenue FROM calendar LEFT JOIN sales USING (month)
)
SELECT *, SUM(revenue) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING) AS running_revenue,
       ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg
FROM monthly ORDER BY month;

-- 3. Одна строка — конкретная покупка товара. Средняя взвешена по проданным единицам.
WITH prices AS (
    SELECT i.order_id, i.order_item_id, i.product_id, p.product_category_name, i.price,
           AVG(i.price) OVER (PARTITION BY p.product_category_name) AS category_avg_price
    FROM order_items i JOIN products p USING (product_id) JOIN orders o USING (order_id)
    WHERE o.order_status = 'delivered'
)
SELECT *, ROUND(price - category_avg_price, 2) AS difference_brl
FROM prices ORDER BY product_category_name, order_id, order_item_id;
