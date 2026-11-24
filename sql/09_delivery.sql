SET search_path TO olist;
-- Количество известных исходов и доля доставок строго после обещанного календарного дня.
SELECT purchase_month, customer_state, COUNT(is_late) AS known_orders,
       ROUND(AVG(delivery_days), 2) AS avg_days,
       ROUND(AVG(GREATEST(delay_days, 0)) FILTER (WHERE is_late), 2) AS avg_days_when_late,
       ROUND(100 * AVG(is_late::int), 2) AS late_pct
FROM order_mart WHERE order_status = 'delivered'
GROUP BY purchase_month, customer_state ORDER BY purchase_month, customer_state;

SELECT customer_state, COUNT(is_late) AS known_orders, COUNT(*) FILTER (WHERE is_late) AS late_orders,
       ROUND(100 * AVG(is_late::int), 2) AS late_pct
FROM order_mart WHERE order_status = 'delivered'
GROUP BY customer_state HAVING COUNT(is_late) >= 100
ORDER BY AVG(is_late::int) DESC, customer_state LIMIT 10;
