-- Демонстрация устойчивости серверной логики
-- к ошибочным сценариям (из лабы 5): явные транзакции, функция
-- place_order и триггеры на успешных и намеренно ошибочных вызовах.
-- Содержит команду \gset - предназначен для запуска через psql.

-- 1. Явная транзакция: успешный сценарий (BEGIN ... COMMIT)
SELECT 'до' AS срез, count(*) AS orders_count FROM orders;

BEGIN;
INSERT INTO orders (user_id, status) VALUES (1, 'created')
RETURNING id AS new_order_id \gset s1_
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:s1_new_order_id, 2, 1, 34214.08);
UPDATE stock SET quantity = quantity - 1 WHERE product_id = 2;
COMMIT;

SELECT 'после COMMIT' AS срез, count(*) AS orders_count FROM orders;


-- 2. Явная транзакция: намеренная ошибка (BEGIN ... ROLLBACK)
BEGIN;
INSERT INTO orders (user_id, status) VALUES (1, 'created')
RETURNING id AS new_order_id \gset s2_
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:s2_new_order_id, 3, 5, 25679.65);
UPDATE stock SET quantity = quantity - 999999 WHERE product_id = 3;
-- ОШИБКА: нарушение CHECK (quantity >= 0), транзакция становится aborted
ROLLBACK;

SELECT 'после ROLLBACK (число заказов НЕ должно вырасти)' AS срез, count(*) AS orders_count FROM orders;


-- 3. Функция place_order: успешный вызов (атомарно создаёт заказ)

SELECT place_order(1, 4, 2) AS new_order_id;
SELECT id, total_amount FROM orders WHERE id = (SELECT max(id) FROM orders);


-- 4. Функция place_order: ошибочный сценарий - заказ больше остатка
SELECT quantity FROM stock WHERE product_id = 4;      -- остаток до
-- Следующий вызов должен завершиться ошибкой "Недостаточно товара на складе"
SELECT place_order(1, 4, 999999);
SELECT quantity FROM stock WHERE product_id = 4;       -- остаток после - не изменился


-- 5. Триггер аудита цены: срабатывает только при изменении price
UPDATE products SET price = price + 500 WHERE id = 10;
SELECT * FROM price_audit WHERE product_id = 10;

UPDATE products SET description = 'тест аудита' WHERE id = 10;
SELECT count(*) AS unchanged_audit_rows FROM price_audit WHERE product_id = 10;


-- 6. Триггер пересчёта рейтинга: срабатывает на каждой вставке отзыва
SELECT rating FROM products WHERE id = 2;
INSERT INTO reviews (user_id, product_id, score, comment)
VALUES (1, 2, 4, 'демонстрация пересчёта рейтинга');
SELECT rating FROM products WHERE id = 2;
