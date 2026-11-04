-- 4. Триггер аудита цены: при изменении products.price старое и
-- новое значение автоматически заносятся в price_audit
CREATE OR REPLACE FUNCTION log_price_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO price_audit (product_id, old_price, new_price)
    VALUES (OLD.id, OLD.price, NEW.price);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_price_audit ON products;

CREATE TRIGGER trg_price_audit
AFTER UPDATE ON products
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION log_price_change();

-- 5. Триггер поддержки денормализованного поля products.rating:
-- при добавлении нового отзыва пересчитывает средний рейтинг товара.
CREATE OR REPLACE FUNCTION refresh_product_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET rating = (
        SELECT round(AVG(score), 2)
        FROM reviews
        WHERE product_id = NEW.product_id
    )
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_refresh_rating ON reviews;

CREATE TRIGGER trg_refresh_rating
AFTER INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_product_rating();
