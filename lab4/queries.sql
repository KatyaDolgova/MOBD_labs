-- ПУНКТ 1. Рейтинг товаров по цене внутри категории
SELECT
    c.name AS category,
    p.title,
    p.price,
    round(p.price, -3)       AS price_rounded,
    ROW_NUMBER() OVER w      AS rn,
    RANK()       OVER w      AS rnk,
    DENSE_RANK() OVER w      AS dense_rnk
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.category_id = 6
WINDOW w AS (PARTITION BY p.category_id ORDER BY round(p.price, -3) DESC)
ORDER BY rn
LIMIT 15;

-- ПУНКТ 2. Топ-3 самых дорогих товара в каждой категории
WITH ranked AS (
    SELECT
        c.name  AS category,
        p.title,
        p.price,
        ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS rn
    FROM products AS p
    JOIN categories AS c ON c.id = p.category_id
)
SELECT category, title, price, rn
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;


-- ПУНКТ 3. Нарастающий итог выручки по дням.
SELECT
    o.created_at::date AS day,
    SUM(oi.quantity * oi.unit_price) AS day_revenue,
    SUM(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY o.created_at::date) AS running_total
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.id
GROUP BY o.created_at::date
ORDER BY day
LIMIT 15;


-- ПУНКТ 4. Доля выручки каждого продавца в выручке ЕГО категории.
WITH seller_cat_rev AS (
    SELECT
        p.seller_id,
        p.category_id,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM products AS p
    JOIN order_items AS oi ON oi.product_id = p.id
    GROUP BY p.seller_id, p.category_id
)
SELECT
    s.store_name,
    c.name AS category,
    r.revenue,
    round(
        r.revenue / SUM(r.revenue) OVER (PARTITION BY r.category_id) * 100,
        2
    ) AS share_in_category_percent
FROM seller_cat_rev AS r
JOIN sellers    AS s ON s.id = r.seller_id
JOIN categories AS c ON c.id = r.category_id
ORDER BY r.category_id, r.revenue DESC
LIMIT 20;


-- ПУНКТ 5. LAG/LEAD: сравнение выручки текущего дня с предыдущим.
WITH daily AS (
    SELECT
        o.created_at::date AS day,
        SUM(oi.quantity * oi.unit_price) AS day_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.id
    GROUP BY o.created_at::date
)
SELECT
    day,
    day_revenue,
    LAG(day_revenue)  OVER (ORDER BY day) AS prev_day_revenue,
    day_revenue - LAG(day_revenue) OVER (ORDER BY day) AS growth,
    LEAD(day_revenue) OVER (ORDER BY day) AS next_day_revenue
FROM daily
ORDER BY day
LIMIT 15;


-- ПУНКТ 6. Одна и та же задача двумя способами: средняя цена товара
-- по категории - оконной функцией и обычной группировкой.

-- 6.1 Оконная функция.
SELECT
    c.name AS category,
    p.title,
    p.price,
    round(AVG(p.price) OVER (PARTITION BY p.category_id), 2) AS avg_price_in_category
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
ORDER BY p.category_id, p.price DESC
LIMIT 15;

-- 6.2 Обычная группировка
SELECT
    c.name AS category,
    round(AVG(p.price), 2) AS avg_price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
GROUP BY c.name
ORDER BY category;
