-- пункт 6. Обратная сторона индексов

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

-- Четыре дополнительных индекса
CREATE INDEX idx_perf_category ON perf_with_index(category_id);
CREATE INDEX idx_perf_seller   ON perf_with_index(seller_id);
CREATE INDEX idx_perf_price    ON perf_with_index(price);
CREATE INDEX idx_perf_cat_price ON perf_with_index(category_id, price);
CREATE INDEX idx_perf_title    ON perf_with_index(title);

\timing on

-- Вставка без дополнительных индексов
INSERT INTO perf_no_index (category_id, seller_id, title, price)
SELECT
    (floor(random() * 20) + 1)::bigint,
    (floor(random() * 30) + 1)::bigint,
    'Товар №' || g,
    (random() * 49000 + 100)::numeric(12,2)
FROM generate_series(1, 50000) AS g;

-- Вставка с пятью индексами
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

-- Уборка после замера - эти таблицы не часть схемы маркетплейса.
DROP TABLE perf_no_index;
DROP TABLE perf_with_index;
