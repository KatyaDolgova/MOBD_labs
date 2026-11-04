-- Дополнения к схеме, нужные для серверной
-- логики: поле денормализованного рейтинга товара (пункт 5) и таблица
-- журнала изменения цены (пункт 4)

-- Денормализованное поле: средняя оценка товара по его отзывам.
-- Хранится прямо в products, чтобы не пересчитывать AVG(score) по
-- reviews при каждом выводе каталога - значение поддерживает триггер
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2);

-- Журнал изменений цены товара - сюда триггер записывает старое и
-- новое значение при каждом UPDATE, меняющем price.
CREATE TABLE IF NOT EXISTS price_audit (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    old_price   NUMERIC(12,2) NOT NULL,
    new_price   NUMERIC(12,2) NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_price_audit_product_id ON price_audit(product_id);
