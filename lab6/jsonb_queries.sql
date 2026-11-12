-- пункт 2. Запросы к JSONB-столбцу attributes

-- 2.1 Оператор ->>
SELECT title, attributes ->> 'color' AS color
FROM products
WHERE attributes ? 'color'
ORDER BY id
LIMIT 10;

-- 2.2 Оператор ->
SELECT title, attributes -> 'pages' AS pages_as_jsonb
FROM products
WHERE attributes ? 'pages'
ORDER BY id
LIMIT 5;

-- 2.3 Операторы #> и #>>
SELECT
    title,
    attributes #> '{specs}'                AS specs_as_jsonb,
    attributes #>> '{specs,screen_inches}' AS screen_inches_as_text
FROM products
WHERE attributes ? 'specs'
ORDER BY id
LIMIT 5;

-- 2.4 Оператор @>
SELECT title, attributes ->> 'color' AS color
FROM products
WHERE attributes @> '{"color": "black"}'
ORDER BY id
LIMIT 10;

-- 2.5 Оператор ?
SELECT count(*) AS books_with_pages
FROM products
WHERE attributes ? 'pages';

-- 2.6 Комбинация: @>
SELECT title, attributes
FROM products
WHERE attributes @> '{"color": "black", "size": "L"}'
ORDER BY id
LIMIT 10;
