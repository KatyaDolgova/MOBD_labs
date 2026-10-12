DROP VIEW IF EXISTS seller_revenue;
DROP VIEW IF EXISTS category_stats;

--  1. seller_revenue - выручка каждого продавца.
CREATE VIEW seller_revenue AS
SELECT
    s.id,
    s.store_name AS name,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p     ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name;

--  2. category_stats - количество товаров и средняя цена по
-- каждой категории, включая категории без единого товара (LEFT JOIN)
CREATE VIEW category_stats AS
SELECT
    c.id,
    c.name,
    COUNT(p.id)                  AS products_count,
    AVG(p.price)::numeric(12,2)  AS avg_price
FROM categories AS c
LEFT JOIN products AS p ON p.category_id = c.id
GROUP BY c.id, c.name;

-- Демонстрация обращения к представлениям
SELECT * FROM seller_revenue ORDER BY revenue DESC LIMIT 10;
SELECT * FROM category_stats ORDER BY products_count DESC;
