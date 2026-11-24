SET search_path TO olist;
-- Полная сетка наблюдаемых месяцев: отсутствие возвратов даёт 0, будущее отсутствует.
WITH active AS (
    SELECT DISTINCT customer_unique_id, purchase_month
    FROM order_mart WHERE order_status = 'delivered'
), labelled AS (
    SELECT *, MIN(purchase_month) OVER (PARTITION BY customer_unique_id) AS cohort
    FROM active
), activity AS (
    SELECT cohort, purchase_month, COUNT(*) AS buyers
    FROM labelled GROUP BY cohort, purchase_month
), sizes AS (
    SELECT cohort, buyers AS cohort_size FROM activity WHERE cohort = purchase_month
), calendar AS (
    SELECT s.cohort, s.cohort_size,
           GENERATE_SERIES(s.cohort, (SELECT MAX(purchase_month) FROM active),
                           INTERVAL '1 month')::date AS purchase_month
    FROM sizes s
)
SELECT c.cohort, c.cohort_size,
       (EXTRACT(YEAR FROM c.purchase_month)::int - EXTRACT(YEAR FROM c.cohort)::int) * 12
       + EXTRACT(MONTH FROM c.purchase_month)::int - EXTRACT(MONTH FROM c.cohort)::int AS month_number,
       COALESCE(a.buyers, 0) AS returning_customers,
       ROUND(100.0 * COALESCE(a.buyers, 0) / c.cohort_size, 3) AS retention_pct
FROM calendar c LEFT JOIN activity a USING (cohort, purchase_month)
ORDER BY c.cohort, month_number;

-- Общий M1, взвешенный по размеру когорты: каждая из доступных для наблюдения персон имеет один голос.
WITH active AS (
    SELECT DISTINCT customer_unique_id, purchase_month
    FROM order_mart WHERE order_status = 'delivered'
), first_month AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort FROM active GROUP BY customer_unique_id
)
SELECT COUNT(*) AS eligible_buyers, COUNT(a.customer_unique_id) AS returned_m1,
       ROUND(100.0 * COUNT(a.customer_unique_id) / COUNT(*), 3) AS retention_m1_pct
FROM first_month f LEFT JOIN active a
  ON a.customer_unique_id = f.customer_unique_id AND a.purchase_month = f.cohort + INTERVAL '1 month'
WHERE f.cohort < (SELECT MAX(purchase_month) FROM active);
