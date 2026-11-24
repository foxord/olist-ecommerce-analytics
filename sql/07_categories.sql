-- ABC считаем среди всех категорий и только затем берём топ-15.
SET search_path TO olist;
WITH sales AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(i.price) AS revenue
    FROM order_items i JOIN orders o USING (order_id)
    JOIN products p USING (product_id)
    LEFT JOIN category_translation t USING (product_category_name)
    WHERE o.order_status = 'delivered'
    GROUP BY 1
), ranked AS (
    SELECT *, SUM(revenue) OVER () AS total,
           SUM(revenue) OVER (ORDER BY revenue DESC, category ROWS UNBOUNDED PRECEDING) AS cumulative
    FROM sales
)
SELECT category, revenue, ROUND(100 * revenue / total, 2) AS share_pct,
       ROUND(100 * cumulative / total, 2) AS cumulative_pct,
       CASE WHEN cumulative - revenue < total * 0.80 THEN 'A'
            WHEN cumulative - revenue < total * 0.95 THEN 'B'
            ELSE 'C' END AS abc
FROM ranked ORDER BY revenue DESC, category LIMIT 15;
