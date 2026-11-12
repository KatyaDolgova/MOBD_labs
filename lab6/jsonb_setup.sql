-- пункт 1. Столбец JSONB
ALTER TABLE products ADD COLUMN IF NOT EXISTS attributes JSONB;

UPDATE products AS p
SET attributes = CASE c.parent_id
    WHEN 1 THEN jsonb_build_object(
        'specs', jsonb_build_object(
            'screen_inches', round((random() * 5 + 4)::numeric, 1),
            'memory_gb', (ARRAY[32, 64, 128, 256, 512])[floor(random() * 5)::int + 1]
        ),
        'color', (ARRAY['black', 'white', 'silver', 'blue'])[floor(random() * 4)::int + 1]
    )
    WHEN 2 THEN jsonb_build_object(
        'size', (ARRAY['S', 'M', 'L', 'XL'])[floor(random() * 4)::int + 1],
        'color', (ARRAY['black', 'white', 'red', 'green', 'blue'])[floor(random() * 5)::int + 1],
        'material', (ARRAY['cotton', 'polyester', 'wool'])[floor(random() * 3)::int + 1]
    )
    WHEN 3 THEN jsonb_build_object(
        'pages', (floor(random() * 500) + 50)::int,
        'cover', (ARRAY['мягкая', 'твёрдая'])[floor(random() * 2)::int + 1]
    )
    WHEN 4 THEN jsonb_build_object(
        'material', (ARRAY['дерево', 'металл', 'пластик'])[floor(random() * 3)::int + 1],
        'weight_kg', round((random() * 20 + 0.5)::numeric, 1)
    )
    WHEN 5 THEN jsonb_build_object(
        'weight_kg', round((random() * 10 + 0.2)::numeric, 1),
        'color', (ARRAY['black', 'white', 'red', 'blue'])[floor(random() * 4)::int + 1]
    )
END
FROM categories AS c
WHERE c.id = p.category_id;

-- Проверка: по одному примеру на каждую корневую категорию.
SELECT c.parent_id, p.title, p.attributes
FROM products AS p
JOIN categories AS c ON c.id = p.category_id
WHERE p.id IN (
    SELECT min(p2.id) FROM products AS p2
    JOIN categories AS c2 ON c2.id = p2.category_id
    GROUP BY c2.parent_id
)
ORDER BY c.parent_id;
