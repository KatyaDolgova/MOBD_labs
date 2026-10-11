-- DISTINCT с псевдонимами столбцов
SELECT DISTINCT
    category_id AS category,
    is_active   AS active_flag
FROM products
ORDER BY category, active_flag;

-- Фильтрация по нескольким условиям: AND и OR со скобками
SELECT id, title, price
FROM products
WHERE (price < 5000 OR price > 40000)
  AND is_active = TRUE
ORDER BY price;

-- BETWEEN - замкнутый диапазон (граничные значения включаются)
SELECT id, title, price
FROM products
WHERE price BETWEEN 10000 AND 20000
ORDER BY price
LIMIT 10;

-- IN - принадлежность списку значений
SELECT id, title, category_id
FROM products
WHERE category_id IN (6, 9, 11)
ORDER BY id
LIMIT 10;

-- LIKE - шаблон: % - любая последовательность, _ - ровно один символ
SELECT id, title
FROM products
WHERE title LIKE 'Товар №12%'
ORDER BY id;

-- ILIKE - то же без учёта регистра (для поиска по названиям на латинице)
SELECT id, email
FROM users
WHERE email ILIKE '%EXAMPLE.com'
ORDER BY id
LIMIT 5;

-- IS NULL - заказы, которые ещё не оплачены (нет строки в payments).
SELECT o.id AS order_id, o.status
FROM orders AS o
LEFT JOIN payments AS p ON p.order_id = o.id
WHERE p.id IS NULL
ORDER BY o.id
LIMIT 10;

-- Сортировка по двум столбцам в разных направлениях
SELECT
    p.category_id,
    c.name AS category_name,
    p.title,
    p.price
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
ORDER BY p.category_id ASC, p.price DESC
LIMIT 20;

-- Постраничный вывод: LIMIT и OFFSET

-- Страница 1 (записи 1-15)
SELECT id, title, price
FROM products
ORDER BY title ASC
LIMIT 15 OFFSET 0;

-- Страница 2 (записи 16-30)
SELECT id, title, price
FROM products
ORDER BY title ASC
LIMIT 15 OFFSET 15;

-- Страница 3 (записи 31-45)
SELECT id, title, price
FROM products
ORDER BY title ASC
LIMIT 15 OFFSET 30;