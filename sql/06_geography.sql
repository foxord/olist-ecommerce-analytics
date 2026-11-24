-- Штат покупателя, не продавца. Город группируем вместе со штатом из-за одноимённых городов.
SET search_path TO olist;
SELECT customer_state, COUNT(*) AS orders, SUM(revenue) AS revenue,
       ROUND(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share_pct
FROM order_mart WHERE order_status = 'delivered'
GROUP BY customer_state ORDER BY revenue DESC, customer_state;

SELECT customer_state, customer_city, COUNT(*) AS orders, SUM(revenue) AS revenue
FROM order_mart WHERE order_status = 'delivered'
GROUP BY customer_state, customer_city ORDER BY revenue DESC, customer_state, customer_city LIMIT 10;
