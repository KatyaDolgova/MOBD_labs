-- пункт 4. B-tree индексы на основе анализа планов "до"
-- Составной индекс (category_id, price): Запрос 1
CREATE INDEX IF NOT EXISTS idx_products_cat_price ON products(category_id, price);

-- Простой индекс по price: Запрос 3
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);

-- Запрос 2 (выручка продавцов, HAVING).
CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- Повторный план Запроса 2
EXPLAIN ANALYZE
SELECT s.id, s.store_name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM sellers AS s
JOIN products AS p ON p.seller_id = s.id
JOIN order_items AS oi ON oi.product_id = p.id
GROUP BY s.id, s.store_name
HAVING SUM(oi.quantity * oi.unit_price) > 7000000;
