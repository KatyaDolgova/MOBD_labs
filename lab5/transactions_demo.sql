
-- Демонстрация транзакции:
-- 1 успешный сценарий 

-- до: сколько сейчас заказов и какой остаток товара 2 и 3.
SELECT 'до' AS срез, count(*) AS orders_count FROM orders;
SELECT product_id, quantity FROM stock WHERE product_id IN (2, 3) ORDER BY product_id;

-- успешная транзакция.
BEGIN;

INSERT INTO orders (user_id, status)
VALUES (1, 'created')
RETURNING id AS new_order_id \gset s1_

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:s1_new_order_id, 2, 1, 34214.08);

UPDATE stock SET quantity = quantity - 1 WHERE product_id = 2;

COMMIT;

-- Проверка: заказов стало на 1 больше, остаток товара 2 уменьшился на 1.
SELECT 'после сценария 1 (COMMIT)' AS срез, count(*) AS orders_count FROM orders;
SELECT product_id, quantity FROM stock WHERE product_id IN (2, 3) ORDER BY product_id;


-- 2: транзакция с намеренной ошибкой
BEGIN;

INSERT INTO orders (user_id, status)
VALUES (1, 'created')
RETURNING id AS new_order_id \gset s2_

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:s2_new_order_id, 3, 5, 25679.65);

UPDATE stock SET quantity = quantity - 999999 WHERE product_id = 3;


ROLLBACK;

-- Проверка: число заказов и остаток товара 3 НЕ изменились
SELECT 'после сценария 2 (ROLLBACK)' AS срез, count(*) AS orders_count FROM orders;
SELECT product_id, quantity FROM stock WHERE product_id IN (2, 3) ORDER BY product_id;
