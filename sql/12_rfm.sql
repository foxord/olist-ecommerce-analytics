SET search_path TO olist;
CREATE OR REPLACE VIEW olist.customer_rfm AS
WITH customers AS (
    SELECT customer_unique_id, MAX(order_purchase_timestamp::date) AS last_purchase,
           COUNT(*) AS frequency, SUM(revenue) AS monetary
    FROM olist.order_mart WHERE order_status = 'delivered' GROUP BY customer_unique_id
), rfm AS (
    SELECT customer_unique_id, MAX(last_purchase) OVER () + 1 - last_purchase AS recency,
           frequency, monetary
    FROM customers
)
SELECT *, CASE WHEN frequency >= 2 AND recency <= 90 THEN 'Активные повторные'
               WHEN frequency >= 2 THEN 'Ушедшие повторные'
               WHEN recency <= 90 THEN 'Недавние разовые'
               ELSE 'Давние разовые' END AS segment
FROM rfm;

-- R и F задают сегмент для кампаний, M показывает его размер в деньгах.
SELECT segment, COUNT(*) AS customers, ROUND(AVG(recency), 1) AS mean_recency,
       ROUND(AVG(frequency), 2) AS mean_frequency, SUM(monetary) AS revenue,
       ROUND(AVG(monetary), 2) AS mean_monetary
FROM olist.customer_rfm GROUP BY segment ORDER BY customers DESC;
