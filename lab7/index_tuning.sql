-- Обоснование индексов: самодостаточная демонстрация "до/после" (из лабы 6). schema.sql уже создаёт
-- итоговый, оптимизированный набор индексов - поэтому здесь сначала
-- временно удаляются три целевых индекса, снимаются планы, индексы восстанавливаются, и
-- планы снимаются снова. Базовые индексы под внешние ключи
-- (seller_id, category_id, order_items.product_id) не трогаются.

-- 1. Временно убираем целевые индексы - воспроизводим состояние "до"
DROP INDEX IF EXISTS idx_products_cat_price;
DROP INDEX IF EXISTS idx_products_price;
DROP INDEX IF EXISTS idx_products_attrs;

-- 2. Планы до

-- Запрос 1: фильтр по category_id и price
EXPLAIN ANALYZE
SELECT title, price FROM products WHERE category_id = 6 AND price < 20000;

-- Запрос 2: выручка продавцов выше порога
EXPLAIN ANALYZE
SELECT s.id, s.store_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000;

-- Запрос 3: точечный поиск по цене
EXPLAIN ANALYZE
SELECT id, title FROM products WHERE price = 113.71;

-- Запрос 4, вариант А: JSONB @> с одной парой ключ/значение
EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black"}';

-- Запрос 4, вариант Б: JSONB @> с двумя парами
EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black", "size": "L"}';

-- 3. Восстанавливаем индексы
CREATE INDEX idx_products_cat_price ON products(category_id, price);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_attrs ON products USING GIN (attributes);
ANALYZE products;

-- 4. Те же планы после
EXPLAIN ANALYZE
SELECT title, price FROM products WHERE category_id = 6 AND price < 20000;

EXPLAIN ANALYZE
SELECT s.id, s.store_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000;

EXPLAIN ANALYZE
SELECT id, title FROM products WHERE price = 113.71;

EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black"}';

EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black", "size": "L"}';

-- 5. Цена индексов на вставке
-- две временные таблицы одинаковой структуры: без доп. индексов и с пятью
DROP TABLE IF EXISTS perf_no_index;
DROP TABLE IF EXISTS perf_with_index;

CREATE TABLE perf_no_index (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL,
    seller_id   BIGINT NOT NULL,
    title       TEXT NOT NULL,
    price       NUMERIC(12,2) NOT NULL
);

CREATE TABLE perf_with_index (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL,
    seller_id   BIGINT NOT NULL,
    title       TEXT NOT NULL,
    price       NUMERIC(12,2) NOT NULL
);

CREATE INDEX idx_perf_category   ON perf_with_index(category_id);
CREATE INDEX idx_perf_seller     ON perf_with_index(seller_id);
CREATE INDEX idx_perf_price      ON perf_with_index(price);
CREATE INDEX idx_perf_cat_price  ON perf_with_index(category_id, price);
CREATE INDEX idx_perf_title      ON perf_with_index(title);

\timing on

INSERT INTO perf_no_index (category_id, seller_id, title, price)
SELECT
    (floor(random() * 20) + 1)::bigint,
    (floor(random() * 30) + 1)::bigint,
    'Товар №' || g,
    (random() * 49000 + 100)::numeric(12,2)
FROM generate_series(1, 50000) AS g;

INSERT INTO perf_with_index (category_id, seller_id, title, price)
SELECT
    (floor(random() * 20) + 1)::bigint,
    (floor(random() * 30) + 1)::bigint,
    'Товар №' || g,
    (random() * 49000 + 100)::numeric(12,2)
FROM generate_series(1, 50000) AS g;

\timing off

SELECT 'perf_no_index'   AS table_name, count(*) FROM perf_no_index
UNION ALL
SELECT 'perf_with_index', count(*) FROM perf_with_index;

DROP TABLE perf_no_index;
DROP TABLE perf_with_index;
