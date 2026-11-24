-- Запускать целиком в одном соединении. Временная копия изолирует эксперимент.
BEGIN;
CREATE TEMPORARY TABLE orders_index_demo ON COMMIT DROP AS
SELECT order_id, order_purchase_timestamp FROM olist.orders;
ANALYZE orders_index_demo;
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id FROM orders_index_demo
WHERE order_purchase_timestamp >= DATE '2018-01-15' AND order_purchase_timestamp < DATE '2018-01-16';

CREATE INDEX idx_demo_purchase ON orders_index_demo(order_purchase_timestamp);
ANALYZE orders_index_demo;
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id FROM orders_index_demo
WHERE order_purchase_timestamp >= DATE '2018-01-15' AND order_purchase_timestamp < DATE '2018-01-16';
COMMIT;
