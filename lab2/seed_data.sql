
TRUNCATE TABLE
    deliveries, payments, reviews, addresses,
    order_items, cart_items, orders, carts,
    stock, products, categories, sellers, users
    RESTART IDENTITY CASCADE;

BEGIN;

-- 1. users - 200 пользователей, первые 30 станут владельцами магазинов
INSERT INTO users (full_name, email, phone, role)
SELECT
    'Пользователь ' || g,
    'user' || g || '@example.com',
    '+7900' || lpad(g::text, 7, '0'),
    CASE WHEN g <= 30 THEN 'seller_owner' ELSE 'customer' END
FROM generate_series(1, 200) AS g;

-- 2. sellers - по одному магазину на каждого seller_owner
INSERT INTO sellers (user_id, store_name, description)
SELECT id, 'Магазин №' || id, 'Описание магазина ' || id
FROM users
WHERE role = 'seller_owner';

-- 3. categories - 5 корневых категорий + по 3 подкатегории на каждую
INSERT INTO categories (parent_id, name) VALUES
    (NULL, 'Электроника'),
    (NULL, 'Одежда'),
    (NULL, 'Книги'),
    (NULL, 'Дом и сад'),
    (NULL, 'Спорт');

INSERT INTO categories (parent_id, name)
SELECT c.id, c.name || ' / Подкатегория ' || g
FROM categories c
CROSS JOIN generate_series(1, 3) AS g
WHERE c.parent_id IS NULL;

-- 4. products - 1200 товаров (требование: не менее 1000 строк)
WITH s AS (SELECT array_agg(id) AS ids, count(*) AS n FROM sellers),
     c AS (SELECT array_agg(id) AS ids, count(*) AS n FROM categories WHERE parent_id IS NOT NULL)
INSERT INTO products (seller_id, category_id, title, description, price, is_active)
SELECT
    s.ids[floor(random() * s.n)::int + 1],
    c.ids[floor(random() * c.n)::int + 1],
    'Товар №' || g,
    'Описание товара ' || g,
    (random() * 49000 + 100)::numeric(12,2),
    (random() > 0.1)
FROM generate_series(1, 1200) AS g, s, c;

-- 5. stock - остаток для каждого товара
INSERT INTO stock (product_id, quantity)
SELECT id, (random() * 200)::int FROM products;

-- 6. carts - корзина у 150 из 200 пользователей
INSERT INTO carts (user_id)
SELECT id FROM users ORDER BY random() LIMIT 150;

-- 7. cart_items - до 3 случайных товаров в каждой корзине
WITH p AS (SELECT array_agg(id) AS ids, count(*) AS n FROM products)
INSERT INTO cart_items (cart_id, product_id, quantity)
SELECT c.id, p.ids[floor(random() * p.n)::int + 1], (random() * 3 + 1)::int
FROM carts c
CROSS JOIN generate_series(1, 3) AS slot
CROSS JOIN p
ON CONFLICT (cart_id, product_id) DO NOTHING;

-- 8. orders - 1000 заказов
WITH u AS (SELECT array_agg(id) AS ids, count(*) AS n FROM users)
INSERT INTO orders (user_id, status, created_at)
SELECT
    u.ids[floor(random() * u.n)::int + 1],
    (ARRAY['created', 'paid', 'sent', 'delivered', 'cancelled'])[floor(random() * 5 + 1)],
    now() - (random() * interval '150 days')
FROM generate_series(1, 1000) AS g, u;

-- 9. order_items - до 3 случайных товаров в каждом заказе.
-- Индекс товара вычисляется один раз через LATERAL и переиспользуется для
-- product_id и unit_price. "+ (o.id - o.id) + (slot - slot)" - фиктивная
-- добавка (всегда 0), которая заставляет LATERAL коррелировать с проходящей
-- строкой; без неё PostgreSQL вычисляет подзапрос один раз на весь запрос.
WITH p AS (SELECT array_agg(id) AS ids, array_agg(price) AS prices, count(*) AS n FROM products)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.id, p.ids[pick.idx], (random() * 3 + 1)::int, p.prices[pick.idx]
FROM orders o
CROSS JOIN generate_series(1, 3) AS slot
CROSS JOIN p
CROSS JOIN LATERAL (
    SELECT floor(random() * p.n)::int + 1 + (o.id - o.id) + (slot - slot) AS idx
) AS pick
ON CONFLICT (order_id, product_id) DO NOTHING;

-- 10. пересчёт total_amount по фактическим позициям заказа
UPDATE orders o
SET total_amount = COALESCE(
    (SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi WHERE oi.order_id = o.id),
    0
);

-- 11. addresses - по одному адресу для каждого пользователя, у кого есть заказ
INSERT INTO addresses (user_id, city, street, house, apartment)
SELECT DISTINCT ON (o.user_id)
    o.user_id,
    (ARRAY['Москва', 'Санкт-Петербург', 'Казань', 'Новосибирск', 'Екатеринбург'])[floor(random() * 5 + 1)],
    'ул. Тестовая',
    (floor(random() * 100) + 1)::text,
    (floor(random() * 200) + 1)::text
FROM orders o
ORDER BY o.user_id;

-- 12. payments - платёж для заказов со статусом paid/sent/delivered
INSERT INTO payments (order_id, amount, status, paid_at)
SELECT o.id, o.total_amount, 'succeeded', o.created_at + interval '1 hour'
FROM orders o
WHERE o.status IN ('paid', 'sent', 'delivered') AND o.total_amount > 0;

-- 13. deliveries - доставка для заказов со статусом sent/delivered
INSERT INTO deliveries (order_id, address_id, delivery_status, delivery_date)
SELECT
    o.id,
    a.id,
    CASE WHEN o.status = 'delivered' THEN 'delivered' ELSE 'in_transit' END,
    o.created_at + interval '3 days'
FROM orders o
JOIN addresses a ON a.user_id = o.user_id
WHERE o.status IN ('sent', 'delivered');

-- 14. reviews - отзыв на купленный товар от пользователей с доставленными заказами
INSERT INTO reviews (user_id, product_id, score, comment, created_at)
SELECT DISTINCT ON (o.user_id, oi.product_id)
    o.user_id,
    oi.product_id,
    floor(random() * 5 + 1)::int,
    'Отзыв пользователя ' || o.user_id,
    o.created_at + interval '5 days'
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.status = 'delivered'
ORDER BY o.user_id, oi.product_id, random()
ON CONFLICT (user_id, product_id) DO NOTHING;

COMMIT;

SELECT 'users' AS table_name, count(*) FROM users
UNION ALL SELECT 'sellers', count(*) FROM sellers
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'stock', count(*) FROM stock
UNION ALL SELECT 'carts', count(*) FROM carts
UNION ALL SELECT 'cart_items', count(*) FROM cart_items
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'reviews', count(*) FROM reviews
UNION ALL SELECT 'addresses', count(*) FROM addresses
UNION ALL SELECT 'deliveries', count(*) FROM deliveries
ORDER BY table_name;
