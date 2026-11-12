-- пункт 3
-- фильтр по категории и диапазону цены
EXPLAIN ANALYZE
SELECT title, price FROM products WHERE category_id = 6 AND price < 20000;

-- точечный поиск по price без какого-либо индекса на этом столбце
EXPLAIN ANALYZE
SELECT id, title FROM products WHERE price = 23115.70;

-- выручка продавцов выше порога
EXPLAIN ANALYZE
SELECT s.id, s.store_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000;

-- фильтр по JSONB-вхождению (@>)
EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black"}';
