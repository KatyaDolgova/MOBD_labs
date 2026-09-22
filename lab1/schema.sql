-- =====================================================================
-- Лабораторная работа №1. Проектирование и создание структуры БД
-- База данных маркетплейса (marketplace)
--
-- Перед выполнением скрипта создайте базу данных (одна команда, вне
-- транзакции, выполняется отдельно от остального скрипта):
--
--   CREATE DATABASE marketplace;
--
-- Далее подключитесь к ней (psql: \c marketplace) и выполните этот файл:
--
--   psql -U postgres -d marketplace -f schema.sql
--
-- Скрипт идемпотентен: повторный запуск полностью пересоздаёт схему.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Удаление существующих объектов (для воспроизводимого пересоздания)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ---------------------------------------------------------------------
-- 1. users — учётные записи площадки
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    phone       TEXT,
    role        TEXT NOT NULL DEFAULT 'customer'
                    CHECK (role IN ('customer', 'seller_owner', 'admin')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 2. sellers — магазины продавцов (1:1 с пользователем-владельцем)
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      BIGINT NOT NULL UNIQUE
                     REFERENCES users(id) ON DELETE CASCADE,
    store_name   TEXT NOT NULL,
    description  TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 3. categories — иерархический классификатор товаров (самоссылка)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id   BIGINT REFERENCES categories(id) ON DELETE RESTRICT,
    name        TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 4. products — карточки товаров
-- ---------------------------------------------------------------------
CREATE TABLE products (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id    BIGINT NOT NULL
                     REFERENCES sellers(id) ON DELETE RESTRICT,
    category_id  BIGINT NOT NULL
                     REFERENCES categories(id) ON DELETE RESTRICT,
    title        TEXT NOT NULL,
    description  TEXT,
    price        NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 5. stock — складские остатки (1:1 с товаром)
-- ---------------------------------------------------------------------
CREATE TABLE stock (
    product_id  BIGINT PRIMARY KEY
                    REFERENCES products(id) ON DELETE CASCADE,
    quantity    INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 6. carts — корзина пользователя (1:1 с пользователем)
-- ---------------------------------------------------------------------
CREATE TABLE carts (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL UNIQUE
                    REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 7. cart_items — позиции корзины (ассоциативная таблица carts <-> products)
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
    cart_id     BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);

-- ---------------------------------------------------------------------
-- 8. orders — оформленные заказы
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT NOT NULL
                      REFERENCES users(id) ON DELETE RESTRICT,
    status        TEXT NOT NULL DEFAULT 'created'
                      CHECK (status IN ('created', 'paid', 'shipped', 'delivered', 'cancelled')),
    total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 9. order_items — позиции заказа (ассоциативная таблица orders <-> products,
--    связь «многие-ко-многим»)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, product_id)
);

-- ---------------------------------------------------------------------
-- 10. payments — оплата заказа (1:0..1 с заказом)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT NOT NULL UNIQUE
                    REFERENCES orders(id) ON DELETE CASCADE,
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status      TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    paid_at     TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- 11. reviews — отзывы покупателей о товарах
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    score       INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, product_id)
);

-- ---------------------------------------------------------------------
-- 12. addresses — адреса доставки пользователя
-- ---------------------------------------------------------------------
CREATE TABLE addresses (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    city        TEXT NOT NULL,
    street      TEXT NOT NULL,
    house       TEXT NOT NULL,
    apartment   TEXT
);

-- ---------------------------------------------------------------------
-- 13. deliveries — доставка заказа (1:0..1 с заказом)
-- ---------------------------------------------------------------------
CREATE TABLE deliveries (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         BIGINT NOT NULL UNIQUE
                         REFERENCES orders(id) ON DELETE CASCADE,
    address_id       BIGINT NOT NULL
                         REFERENCES addresses(id) ON DELETE RESTRICT,
    delivery_status  TEXT NOT NULL DEFAULT 'pending'
                         CHECK (delivery_status IN ('pending', 'in_transit', 'delivered', 'returned')),
    delivery_date    TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- Вспомогательные индексы под внешние ключи (ускоряют JOIN и удаление
-- родительских строк; сами FK индекс автоматически не создают)
-- ---------------------------------------------------------------------
CREATE INDEX idx_sellers_user_id        ON sellers(user_id);
CREATE INDEX idx_categories_parent_id   ON categories(parent_id);
CREATE INDEX idx_products_seller_id     ON products(seller_id);
CREATE INDEX idx_products_category_id   ON products(category_id);
CREATE INDEX idx_carts_user_id          ON carts(user_id);
CREATE INDEX idx_orders_user_id         ON orders(user_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_reviews_product_id     ON reviews(product_id);
CREATE INDEX idx_addresses_user_id      ON addresses(user_id);
CREATE INDEX idx_deliveries_address_id  ON deliveries(address_id);
