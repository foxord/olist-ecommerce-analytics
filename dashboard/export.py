"""Обновить локальную модель дашборда из PostgreSQL."""

import base64
import gzip
import json
from pathlib import Path
import sys

from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sql"))
from connection import database_url


QUERY = """
WITH category_sales AS (
    SELECT i.order_id,
           COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           ROUND(SUM(i.price) * 100)::integer AS cents
    FROM olist.order_items i
    JOIN olist.products p USING (product_id)
    LEFT JOIN olist.category_translation t USING (product_category_name)
    GROUP BY i.order_id, COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
), baskets AS (
    SELECT order_id, jsonb_object_agg(category, cents) AS categories
    FROM category_sales
    GROUP BY order_id
)
SELECT to_char(m.purchase_month, 'YYYY-MM') AS month,
       m.customer_state AS state,
       dense_rank() OVER (ORDER BY m.customer_unique_id) AS buyer,
       ROUND(m.revenue * 100)::integer AS cents,
       m.delivery_days::float AS days,
       m.is_late AS late,
       m.review_score AS score,
       r.segment,
       COALESCE(b.categories, '{}'::jsonb) AS categories
FROM olist.order_mart m
JOIN olist.customer_rfm r USING (customer_unique_id)
LEFT JOIN baskets b USING (order_id)
WHERE m.order_status = 'delivered'
ORDER BY m.order_purchase_timestamp, m.order_id
"""


def main():
    engine = create_engine(database_url().replace("postgresql://", "postgresql+psycopg2://", 1))
    with engine.connect() as connection:
        rows = [dict(row) for row in connection.execute(text(QUERY)).mappings()]
    if not rows:
        raise ValueError("В витрине нет доставленных заказов. Проверьте загрузку базы.")
    for order in rows:
        if sum(order["categories"].values()) != (order["cents"] or 0):
            raise ValueError("Сумма по категориям расходится с суммой заказа.")

    content = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    encoded = base64.b64encode(gzip.compress(content, mtime=0)).decode("ascii")
    target = ROOT / "dashboard" / "extract.js"
    target.write_text(f'window.olistExtract = "{encoded}";\n', encoding="ascii")
    print(f"{target.name}: {len(rows):,} заказов, {target.stat().st_size:,} байт")


if __name__ == "__main__":
    main()
