-- Отсутствующий календарный месяц заполняем нулём, чтобы LAG не перепрыгнул через него.
SET search_path TO olist;
WITH sales AS (
    SELECT purchase_month, COUNT(*) AS orders, SUM(revenue) AS revenue,
           COUNT(DISTINCT customer_unique_id) AS customers
    FROM order_mart WHERE order_status = 'delivered'
    GROUP BY purchase_month
), calendar AS (
    SELECT GENERATE_SERIES(MIN(purchase_month), MAX(purchase_month), INTERVAL '1 month')::date AS month
    FROM sales
), monthly AS (
    SELECT month, COALESCE(orders, 0) AS orders, COALESCE(revenue, 0) AS revenue,
           COALESCE(customers, 0) AS customers
    FROM calendar LEFT JOIN sales ON sales.purchase_month = calendar.month
), kpi AS (
    SELECT *, revenue / NULLIF(orders, 0) AS aov FROM monthly
)
SELECT *, ROUND(100 * (revenue / NULLIF(LAG(revenue) OVER w, 0) - 1), 2) AS revenue_growth_pct,
       ROUND(100.0 * (orders - LAG(orders) OVER w) / NULLIF(LAG(orders) OVER w, 0), 2) AS orders_growth_pct,
       ROUND(100.0 * (customers - LAG(customers) OVER w) / NULLIF(LAG(customers) OVER w, 0), 2) AS customers_growth_pct,
       ROUND(100 * (aov / NULLIF(LAG(aov) OVER w, 0) - 1), 2) AS aov_growth_pct
FROM kpi WINDOW w AS (ORDER BY month)
ORDER BY month;
