SET search_path TO olist;
-- Доля платёжных строк и денег. AOV по заказам, где встречается способ хотя бы раз.
-- Смешанный заказ входит в AOV каждого использованного способа, один раз на способ.
WITH by_order_method AS (
    SELECT p.order_id, p.payment_type, COUNT(*) AS transactions, SUM(p.payment_value) AS paid
    FROM order_payments p JOIN orders o USING (order_id)
    WHERE o.order_status = 'delivered' GROUP BY p.order_id, p.payment_type
)
SELECT payment_type, SUM(transactions) AS transactions, COUNT(*) AS orders,
       ROUND(100 * SUM(transactions) / SUM(SUM(transactions)) OVER (), 2) AS transaction_share_pct,
       SUM(paid) AS paid, ROUND(100 * SUM(paid) / SUM(SUM(paid)) OVER (), 2) AS paid_share_pct,
       ROUND(AVG(m.revenue), 2) AS order_aov
FROM by_order_method JOIN order_mart m USING (order_id)
GROUP BY payment_type ORDER BY paid DESC;

SELECT payment_installments, COUNT(*) AS card_transactions
FROM order_payments JOIN orders USING (order_id)
WHERE order_status = 'delivered' AND payment_type = 'credit_card'
GROUP BY payment_installments ORDER BY payment_installments;
