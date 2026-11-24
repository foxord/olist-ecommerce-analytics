SET search_path TO olist;
-- Q1. Лишние строки относительно каждого предложенного ключа. Для суррогатного ключа
-- отдельно проверяем содержимое исходной таблицы: сгенерированный ID всегда уникален.
SELECT 'customers.customer_id' AS candidate, COUNT(*)-COUNT(DISTINCT customer_id) AS extra FROM customers
UNION ALL SELECT 'sellers.seller_id', COUNT(*)-COUNT(DISTINCT seller_id) FROM sellers
UNION ALL SELECT 'orders.order_id', COUNT(*)-COUNT(DISTINCT order_id) FROM orders
UNION ALL SELECT 'products.product_id', COUNT(*)-COUNT(DISTINCT product_id) FROM products
UNION ALL SELECT 'category_translation.category', COUNT(*)-COUNT(DISTINCT product_category_name) FROM category_translation
UNION ALL SELECT 'order_items.(order_id,item)', COUNT(*)-COUNT(DISTINCT (order_id,order_item_id)) FROM order_items
UNION ALL SELECT 'order_items.order_id', COUNT(*)-COUNT(DISTINCT order_id) FROM order_items
UNION ALL SELECT 'order_payments.(order_id,seq)', COUNT(*)-COUNT(DISTINCT (order_id,payment_sequential)) FROM order_payments
UNION ALL SELECT 'order_payments.order_id', COUNT(*)-COUNT(DISTINCT order_id) FROM order_payments
UNION ALL SELECT 'order_reviews.review_id', COUNT(*)-COUNT(DISTINCT review_id) FROM order_reviews
UNION ALL SELECT 'order_reviews.(order_id,review_id)', COUNT(*)-COUNT(DISTINCT (order_id,review_id)) FROM order_reviews
UNION ALL SELECT 'order_reviews.order_id', COUNT(*)-COUNT(DISTINCT order_id) FROM order_reviews
UNION ALL SELECT 'geolocation.zip', COUNT(*)-COUNT(DISTINCT geolocation_zip_code_prefix) FROM geolocation;

SELECT COUNT(*) - COUNT(DISTINCT (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
                                  geolocation_city, geolocation_state)) AS repeated_geo_rows
FROM geolocation;

SELECT COUNT(*) AS orders_with_multiple_reviews FROM (
    SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1
) AS multiple;

-- Q2. Доля NULL по всем nullable-столбцам схемы. COUNT(поле) пропускает NULL.
WITH missing AS (
    SELECT 'orders' AS source, COUNT(*) AS n,
           COUNT(*) - COUNT(order_approved_at) AS approved,
           COUNT(*) - COUNT(order_delivered_carrier_date) AS carrier,
           COUNT(*) - COUNT(order_delivered_customer_date) AS delivered
    FROM orders
)
SELECT source, field, missing_rows, ROUND(100.0 * missing_rows / n, 3) AS pct
FROM missing CROSS JOIN LATERAL (VALUES
    ('order_approved_at', approved), ('order_delivered_carrier_date', carrier),
    ('order_delivered_customer_date', delivered)) AS cols(field, missing_rows)
UNION ALL
SELECT 'order_reviews', field, COUNT(*) - COUNT(value), ROUND(100.0 * (COUNT(*) - COUNT(value)) / COUNT(*), 3)
FROM order_reviews CROSS JOIN LATERAL (VALUES
    ('review_comment_title', review_comment_title), ('review_comment_message', review_comment_message)
) AS cols(field, value) GROUP BY field
UNION ALL
SELECT 'products', field, COUNT(*) - COUNT(value), ROUND(100.0 * (COUNT(*) - COUNT(value)) / COUNT(*), 3)
FROM products CROSS JOIN LATERAL (VALUES
    ('product_category_name', product_category_name), ('product_name_lenght', product_name_lenght::text),
    ('product_description_lenght', product_description_lenght::text), ('product_photos_qty', product_photos_qty::text),
    ('product_weight_g', product_weight_g::text), ('product_length_cm', product_length_cm::text),
    ('product_height_cm', product_height_cm::text), ('product_width_cm', product_width_cm::text)
) AS cols(field, value) GROUP BY field;

SELECT order_status, COUNT(*) AS orders, COUNT(*)-COUNT(order_approved_at) AS missing_approval,
       COUNT(*)-COUNT(order_delivered_carrier_date) AS missing_carrier,
       COUNT(*)-COUNT(order_delivered_customer_date) AS missing_delivery
FROM orders GROUP BY order_status ORDER BY orders DESC;

-- Q3. Разные денежные величины и ошибочный JOIN двух дочерних таблиц. Все статусы.
SELECT SUM(price) AS items_only, SUM(freight_value) AS freight FROM order_items;
SELECT SUM(payment_value) AS payments_only FROM order_payments;
SELECT COUNT(*) AS joined_rows, SUM(price) AS inflated_price, SUM(payment_value) AS inflated_paid
FROM orders JOIN order_items USING (order_id) JOIN order_payments USING (order_id);

-- Q4. Для порядка событий сравниваем timestamps, включая время суток.
SELECT COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_approved_at) AS carrier_before_approval,
       COUNT(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date) AS delivery_before_carrier,
       COUNT(*) FILTER (WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL) AS missing_delivery
FROM orders;

-- Q5. Покрытие ссылок и необязательных справочников.
SELECT 'products without category' AS issue, COUNT(*) AS rows FROM products WHERE product_category_name IS NULL
UNION ALL SELECT 'orders without items', COUNT(*) FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id=o.order_id)
UNION ALL SELECT 'delivered orders without items', COUNT(*) FROM orders o WHERE o.order_status='delivered' AND NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id=o.order_id)
UNION ALL SELECT 'items without order', COUNT(*) FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id=i.order_id)
UNION ALL SELECT 'customers without order', COUNT(*) FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id=c.customer_id)
UNION ALL SELECT 'orders without payment', COUNT(*) FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_payments p WHERE p.order_id=o.order_id);
SELECT p.product_category_name, COUNT(*) AS products_without_translation
FROM products p LEFT JOIN category_translation t USING (product_category_name)
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL GROUP BY p.product_category_name;

-- Q6. Нули, отрицательные значения и пределы измерений. Крупное значение само по себе не ошибка.
SELECT MIN(price) AS min_price, COUNT(*) FILTER (WHERE price = 0) AS zero_price,
       COUNT(*) FILTER (WHERE price < 0) AS negative_price,
       COUNT(*) FILTER (WHERE freight_value = 0) AS zero_freight,
       COUNT(*) FILTER (WHERE freight_value < 0) AS negative_freight FROM order_items;
SELECT COUNT(*) FILTER (WHERE payment_value = 0) AS zero_value,
       COUNT(*) FILTER (WHERE payment_value < 0) AS negative_value,
       COUNT(*) FILTER (WHERE payment_installments = 0) AS zero_installments FROM order_payments;
SELECT MIN(product_weight_g) AS min_weight, MAX(product_weight_g) AS max_weight,
       COUNT(*) FILTER (WHERE product_weight_g <= 0) AS nonpositive_weight,
       COUNT(*) FILTER (WHERE product_length_cm <= 0 OR product_width_cm <= 0 OR product_height_cm <= 0) AS nonpositive_dimensions,
       MAX(product_length_cm) AS longest, MAX(product_width_cm) AS widest, MAX(product_height_cm) AS tallest
FROM products;
