
-- ШАГ 1
DROP TABLE IF EXISTS products_bad;

CREATE TABLE products_bad (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title         TEXT NOT NULL,
    price         NUMERIC(12,2) NOT NULL,
    seller_name   TEXT NOT NULL,
    seller_email  TEXT NOT NULL
);

INSERT INTO products_bad (title, price, seller_name, seller_email) VALUES
    ('Смартфон X1',   25000, 'Магазин Ромашка', 'romashka@mail.ru'),
    ('Чехол для X1',    500, 'Магазин Ромашка', 'romashka@mail.ru'),
    ('Наушники Y2',    3000, 'Магазин Ромашка', 'romashka@mail.ru');

SELECT * FROM products_bad;

-- ШАГ 2. Аномалия ОБНОВЛЕНИЯ

UPDATE products_bad
SET seller_email = 'novy-adres@mail.ru'
WHERE id IN (1, 2);

SELECT id, title, seller_name, seller_email FROM products_bad;

-- ШАГ 3. Аномалия УДАЛЕНИЯ
DELETE FROM products_bad WHERE id IN (1, 2, 3);

SELECT * FROM products_bad;

-- ШАГ 5. Как аномалии устранены в реальной схеме
SELECT s.id, s.store_name, COUNT(p.id) AS products_count
FROM sellers s
LEFT JOIN products p ON p.seller_id = s.id
GROUP BY s.id, s.store_name;

-- Уборка временной таблицы
DROP TABLE products_bad;
