-- Каталог представительных запросов разной сложности (многотабличные выборки, агрегация, подзапросы, CTE,
-- оконные функции, запросы к JSONB) - набор из лаб 2-6.

-- раздел 1. Многотабличные выборки (JOIN)

-- 1.1 INNER JOIN трёх таблиц: товар - категория - продавец
SELECT p.id, p.title, c.name AS category, s.store_name AS seller
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
JOIN sellers   AS s ON s.id = p.seller_id
ORDER BY p.id
LIMIT 10;

-- 1.2 LEFT JOIN: товары без единого отзыва
SELECT p.id, p.title
FROM products AS p
LEFT JOIN reviews AS r ON r.product_id = p.id
WHERE r.id IS NULL
ORDER BY p.id
LIMIT 10;

-- раздел 2. Группировка и агрегация

-- 2.1 Количество товаров и средняя цена по категории
SELECT c.name AS category, COUNT(*) AS products_count,
       AVG(p.price)::numeric(12,2) AS avg_price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
GROUP BY c.name
ORDER BY products_count DESC;

-- 2.2 HAVING: продавцы с выручкой выше порога
SELECT s.id, s.store_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000
ORDER BY revenue DESC;

-- раздел 3. Подзапросы (скалярный, IN, коррелированный EXISTS)

-- 3.1 Скалярный подзапрос: товары дороже средней цены по всей базе
SELECT id, title, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price
LIMIT 10;

-- 3.2 Подзапрос с IN: продавцы с хотя бы одним активным товаром
SELECT id, store_name
FROM sellers
WHERE id IN (SELECT seller_id FROM products WHERE is_active = TRUE)
ORDER BY id
LIMIT 10;

-- 3.3 Коррелированный подзапрос с EXISTS: продавцы, у которых есть товар
SELECT s.id, s.store_name
FROM sellers AS s
WHERE EXISTS (SELECT 1 FROM products AS p WHERE p.seller_id = s.id)
ORDER BY s.id
LIMIT 10;

-- раздел 4. CTE

-- 4.1 CTE: доля выручки каждого продавца от общей выручки площадки
WITH seller_rev AS (
    SELECT p.seller_id, SUM(oi.quantity * oi.unit_price) AS revenue
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.id
    GROUP BY p.seller_id
)
SELECT s.store_name, r.revenue,
       round(r.revenue / (SELECT SUM(revenue) FROM seller_rev) * 100, 2) AS share_percent
FROM seller_rev AS r
JOIN sellers AS s ON s.id = r.seller_id
ORDER BY r.revenue DESC
LIMIT 10;

-- 4.2 Рекурсивный CTE: обход дерева категорий
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

-- раздел 5. Оконные функции

-- 5.1 ROW_NUMBER/RANK/DENSE_RANK товаров по цене внутри категории
SELECT c.name AS category, p.title, p.price,
       ROW_NUMBER() OVER w AS rn,
       RANK()       OVER w AS rnk,
       DENSE_RANK() OVER w AS dense_rnk
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.category_id = 6
WINDOW w AS (PARTITION BY p.category_id ORDER BY p.price DESC)
ORDER BY rn
LIMIT 15;

-- 5.2 Топ-3 самых дорогих товара в каждой категории
WITH ranked AS (
    SELECT c.name AS category, p.title, p.price,
           ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rn
    FROM products AS p
    JOIN categories AS c ON c.id = p.category_id
)
SELECT category, title, price, rn FROM ranked WHERE rn <= 3 ORDER BY category, rn;

-- 5.3 Нарастающий итог выручки по дням
SELECT o.created_at::date AS day,
       SUM(oi.quantity * oi.unit_price) AS day_revenue,
       SUM(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY o.created_at::date) AS running_total
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.id
GROUP BY o.created_at::date
ORDER BY day
LIMIT 15;

-- 5.4 LAG/LEAD: сравнение выручки текущего дня с предыдущим и следующим
WITH daily AS (
    SELECT o.created_at::date AS day, SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT day, day_revenue,
       LAG(day_revenue)  OVER (ORDER BY day) AS prev_day_revenue,
       day_revenue - LAG(day_revenue) OVER (ORDER BY day) AS growth,
       LEAD(day_revenue) OVER (ORDER BY day) AS next_day_revenue
FROM daily
ORDER BY day
LIMIT 15;

-- раздел 6. Запросы к JSONB (products.attributes, лаба 6)

-- 6.1 -> и ->> : значение по ключу (как JSONB и как текст)
SELECT title, attributes ->> 'color' AS color
FROM products
WHERE attributes ? 'color'
ORDER BY id
LIMIT 10;

-- 6.2 #> и #>> : значение по пути (вложенные объекты)
SELECT title,
       attributes #> '{specs}'                AS specs_as_jsonb,
       attributes #>> '{specs,screen_inches}' AS screen_inches_as_text
FROM products
WHERE attributes ? 'specs'
ORDER BY id
LIMIT 5;

-- 6.3 @> : документ содержит фрагмент
SELECT title, attributes ->> 'color' AS color
FROM products
WHERE attributes @> '{"color": "black"}'
ORDER BY id
LIMIT 10;

-- 6.4 ? : наличие ключа (книги - единственная категория с полем pages)
SELECT count(*) AS books_with_pages FROM products WHERE attributes ? 'pages';

-- 6.5 @> с двумя условиями сразу
SELECT title, attributes FROM products
WHERE attributes @> '{"color": "black", "size": "L"}'
ORDER BY id
LIMIT 10;
