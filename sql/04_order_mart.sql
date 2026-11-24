-- Витрина всех заказов. Статус выбираем в запросе к витрине.
SET search_path TO olist;
CREATE OR REPLACE VIEW olist.order_mart AS
WITH items AS (
    SELECT order_id, SUM(price) AS revenue, SUM(freight_value) AS freight_value,
           COUNT(*) AS item_count
    FROM olist.order_items
    GROUP BY order_id
), payments AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM olist.order_payments
    GROUP BY order_id
), reviews AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM olist.order_reviews
    ORDER BY order_id, review_answer_timestamp DESC NULLS LAST, review_creation_date DESC NULLS LAST,
             review_id DESC, review_row_id DESC
)
SELECT o.*, c.customer_unique_id, c.customer_state, c.customer_city,
       i.revenue, i.freight_value, COALESCE(i.item_count, 0) AS item_count,
       p.payment_value, r.review_score,
       o.order_delivered_customer_date::date - o.order_purchase_timestamp::date AS delivery_days,
       o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay_days,
       o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date AS is_late,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month
FROM olist.orders o
JOIN olist.customers c USING (customer_id)
LEFT JOIN items i USING (order_id)
LEFT JOIN payments p USING (order_id)
LEFT JOIN reviews r USING (order_id);
