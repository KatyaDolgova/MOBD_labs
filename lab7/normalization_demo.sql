-- Обоснование схемы (3НФ) - демонстрация
-- аномалий ненормализованной структуры и того, как они устранены в
-- реальной схеме (из лабы 1)

-- 1. Ненормализованная таблица: email продавца дублируется в каждой
-- строке товара вместо хранения один раз в отдельной таблице sellers
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

-- 2. Аномалия обновления: email продавца пришлось исправлять в
-- нескольких строках одновременно - легко забыть одну и получить рассогласованные данные
UPDATE products_bad
SET seller_email = 'novy-adres@mail.ru'
WHERE id IN (1, 2);

SELECT id, title, seller_name, seller_email FROM products_bad;

-- 3. Аномалия удаления: удаление всех товаров продавца стирает и
-- сам факт существования продавца - его email нигде больше не хранится
DELETE FROM products_bad WHERE id IN (1, 2, 3);

SELECT * FROM products_bad;

-- 4. Как обе аномалии устранены в реальной схеме: email продавца хранится один раз в users/sellers
SELECT s.id, s.store_name, COUNT(p.id) AS products_count
FROM sellers s
LEFT JOIN products p ON p.seller_id = s.id
GROUP BY s.id, s.store_name;

DROP TABLE products_bad;
