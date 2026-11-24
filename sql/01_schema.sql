-- Имена колонок соответствуют заголовкам исходных CSV.
CREATE SCHEMA IF NOT EXISTS olist;
SET search_path TO olist;

CREATE TABLE IF NOT EXISTS category_translation (
    product_category_name text PRIMARY KEY,
    product_category_name_english text NOT NULL
);
CREATE TABLE IF NOT EXISTS customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    customer_zip_code_prefix text NOT NULL,
    customer_city text NOT NULL,
    customer_state text NOT NULL
);
CREATE TABLE IF NOT EXISTS sellers (
    seller_id text PRIMARY KEY,
    seller_zip_code_prefix text NOT NULL,
    seller_city text NOT NULL,
    seller_state text NOT NULL
);
CREATE TABLE IF NOT EXISTS products (
    product_id text PRIMARY KEY,
    product_category_name text,
    product_name_lenght integer,
    product_description_lenght integer,
    product_photos_qty integer,
    product_weight_g integer,
    product_length_cm integer,
    product_height_cm integer,
    product_width_cm integer
);
CREATE TABLE IF NOT EXISTS geolocation (
    geo_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    geolocation_zip_code_prefix text NOT NULL,
    geolocation_lat double precision NOT NULL,
    geolocation_lng double precision NOT NULL,
    geolocation_city text NOT NULL,
    geolocation_state text NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES customers(customer_id),
    order_status text NOT NULL,
    order_purchase_timestamp timestamp NOT NULL,
    order_approved_at timestamp,
    order_delivered_carrier_date timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp NOT NULL
);
CREATE TABLE IF NOT EXISTS order_items (
    order_id text NOT NULL REFERENCES orders(order_id),
    order_item_id integer NOT NULL CHECK (order_item_id > 0),
    product_id text NOT NULL REFERENCES products(product_id),
    seller_id text NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date timestamp NOT NULL,
    price numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);
CREATE TABLE IF NOT EXISTS order_payments (
    order_id text NOT NULL REFERENCES orders(order_id),
    payment_sequential integer NOT NULL CHECK (payment_sequential > 0),
    payment_type text NOT NULL,
    payment_installments integer NOT NULL,
    payment_value numeric(12,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);
CREATE TABLE IF NOT EXISTS order_reviews (
    review_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    review_id text NOT NULL,
    order_id text NOT NULL REFERENCES orders(order_id),
    review_score smallint NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp NOT NULL,
    review_answer_timestamp timestamp NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_purchase ON orders(order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_customers_unique ON customers(customer_unique_id);
CREATE INDEX IF NOT EXISTS idx_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_items_seller ON order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_reviews_order ON order_reviews(order_id);
