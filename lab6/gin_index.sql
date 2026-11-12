-- пункт 5. GIN-индекс по столбцу JSONB

CREATE INDEX IF NOT EXISTS idx_products_attrs ON products USING GIN (attributes);

ANALYZE products;

-- Повторный снимок плана того же запроса
EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black"}';

-- Более избирательный вариант того же оператора @>
EXPLAIN ANALYZE
SELECT title FROM products WHERE attributes @> '{"color": "black", "size": "L"}';
