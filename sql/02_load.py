"""Из корня проекта: python sql/02_load.py. Обновляет девять таблиц схемы olist."""
import csv
from pathlib import Path

import psycopg2
from psycopg2 import sql

from connection import database_url

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
TABLES = [
    "category_translation", "customers", "sellers", "products", "geolocation",
    "orders", "order_items", "order_payments", "order_reviews",
]


def load():
    counts = []
    connection = psycopg2.connect(database_url())
    try:
        connection.set_client_encoding("UTF8")
        # Любая ошибка отменяет всю транзакцию, в том числе TRUNCATE.
        with connection, connection.cursor() as cursor:
            cursor.execute((SQL_DIR / "01_schema.sql").read_text(encoding="utf-8"))
            tables = sql.SQL(", ").join(sql.Identifier(table) for table in TABLES)
            cursor.execute(sql.SQL("TRUNCATE {} RESTART IDENTITY").format(tables))
            for table in TABLES:
                filename = ("product_category_name_translation.csv" if table == "category_translation"
                            else f"olist_{table}_dataset.csv")
                with (ROOT / "data" / filename).open(encoding="utf-8-sig", newline="") as source:
                    rows = csv.reader(source)
                    header = next(rows)
                    expected = sum(1 for _ in rows)
                    source.seek(0)
                    columns = sql.SQL(", ").join(map(sql.Identifier, header))
                    command = sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER)").format(
                        sql.Identifier(table), columns
                    )
                    cursor.copy_expert(command, source)
                cursor.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(table)))
                actual = cursor.fetchone()[0]
                if actual != expected:
                    raise ValueError(f"{table}: CSV {expected}, PostgreSQL {actual}")
                counts.append((table, expected, actual))
                cursor.execute(sql.SQL("ANALYZE {}").format(sql.Identifier(table)))
            # В ранних этапах проекта аналитические представления ещё не добавлены.
            for filename in ["04_order_mart.sql", "12_rfm.sql"]:
                view_file = SQL_DIR / filename
                if view_file.exists():
                    cursor.execute(view_file.read_text(encoding="utf-8"))
    finally:
        connection.close()
    print(f"{'Таблица':<24} {'CSV':>10} {'PostgreSQL':>12}")
    for name, expected, actual in counts:
        print(f"{name:<24} {expected:>10} {actual:>12}")


if __name__ == "__main__":
    load()
