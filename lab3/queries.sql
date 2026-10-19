--  1. INNER JOIN не менее трёх таблиц: товар - категория - продавец
SELECT
    p.id,
    p.title,
    c.name       AS category,
    s.store_name AS seller
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers   AS s ON s.id = p.seller_id
ORDER BY p.id
LIMIT 10;

--  2. LEFT JOIN: строки без соответствия в связанной таблице
SELECT
    p.id,
    p.title
FROM products AS p
LEFT JOIN reviews AS r ON r.product_id = p.id
WHERE r.id IS NULL
ORDER BY p.id
LIMIT 10;

--  3. Группировка и агрегация: по каждой категории - количество
SELECT
    c.name                    AS category,
    COUNT(*)                  AS products_count,
    AVG(p.price)::numeric(12,2) AS avg_price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
GROUP BY c.name
ORDER BY products_count DESC;

--  4. HAVING: фильтрация уже сгруппированных данных
SELECT
    s.id,
    s.store_name,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000
ORDER BY revenue DESC;

--  5. Подзапросы: скалярный, с IN, с EXISTS (коррелированный)-

-- 5.1 Скалярный подзапрос - возвращает ровно одно значение (среднюю
-- цену по всей базе), которое используется в условии сравнения.
SELECT id, title, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price
LIMIT 10;

-- 5.2 Подзапрос с IN - продавцы, у которых есть хотя бы один активный
-- товар.
SELECT id, store_name
FROM sellers
WHERE id IN (SELECT seller_id FROM products WHERE is_active = TRUE)
ORDER BY id
LIMIT 10;

-- 5.3 Подзапрос с EXISTS (коррелированный) - продавцы, у которых есть
-- хотя бы один товар.
SELECT s.id, s.store_name
FROM sellers AS s
WHERE EXISTS (SELECT 1 FROM products AS p WHERE p.seller_id = s.id)
ORDER BY s.id
LIMIT 10;

--  6. CTE для разбиения сложного запроса на шаги
WITH seller_rev AS (
    SELECT p.seller_id, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.id
    GROUP BY p.seller_id
)
SELECT
    s.store_name,
    r.revenue,
    round(r.revenue / (SELECT SUM(revenue) FROM seller_rev) * 100, 2) AS share_percent
FROM seller_rev AS r
JOIN sellers AS s ON s.id = r.seller_id
ORDER BY r.revenue DESC
LIMIT 10;


-- Рекурсивный CTE (WITH RECURSIVE) - обход дерева категорий.
WITH RECURSIVE category_tree AS (
    SELECT id, parent_id, name, 1 AS level
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.id, c.parent_id, c.name, ct.level + 1
    FROM categories AS c
    JOIN category_tree AS ct ON c.parent_id = ct.id
)
SELECT level, id, parent_id, name
FROM category_tree
ORDER BY level, id;
