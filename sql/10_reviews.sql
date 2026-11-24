SET search_path TO olist;
WITH scored AS (
    SELECT is_late, review_score FROM order_mart
    WHERE order_status = 'delivered' AND is_late IS NOT NULL AND review_score IS NOT NULL
)
SELECT is_late, COUNT(*) AS orders, ROUND(AVG(review_score), 3) AS avg_score,
       COUNT(*) FILTER (WHERE review_score = 1) AS one_star,
       COUNT(*) FILTER (WHERE review_score = 2) AS two_stars,
       COUNT(*) FILTER (WHERE review_score = 3) AS three_stars,
       COUNT(*) FILTER (WHERE review_score = 4) AS four_stars,
       COUNT(*) FILTER (WHERE review_score = 5) AS five_stars
FROM scored GROUP BY is_late ORDER BY is_late;
