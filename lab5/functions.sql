-- 2. place_order - атомарно оформляет заказ
CREATE OR REPLACE FUNCTION place_order(p_user BIGINT, p_product BIGINT, p_qty INT)
RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_price    NUMERIC(12,2);
    v_stock    INT;
BEGIN
    SELECT price INTO v_price FROM products WHERE id = p_product;
    IF v_price IS NULL THEN
        RAISE EXCEPTION 'Товар с id=% не найден', p_product;
    END IF;

    SELECT quantity INTO v_stock FROM stock WHERE product_id = p_product;
    IF v_stock IS NULL OR v_stock < p_qty THEN
        RAISE EXCEPTION 'Недостаточно товара на складе (id=%, в наличии %, запрошено %)',
            p_product, COALESCE(v_stock, 0), p_qty;
    END IF;

    INSERT INTO orders (user_id, status)
    VALUES (p_user, 'created')
    RETURNING id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product, p_qty, v_price);

    UPDATE stock SET quantity = quantity - p_qty WHERE product_id = p_product;

    UPDATE orders SET total_amount = v_price * p_qty WHERE id = v_order_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;


-- 3. seller_revenue - сводный показатель: выручка продавца за период
CREATE OR REPLACE FUNCTION seller_revenue(p_seller_id BIGINT, p_from DATE, p_to DATE)
RETURNS NUMERIC(14,2) AS $$
DECLARE
    v_revenue NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(oi.quantity * oi.unit_price), 0)
      INTO v_revenue
    FROM order_items AS oi
    JOIN products AS p ON p.id = oi.product_id
    JOIN orders   AS o ON o.id = oi.order_id
    WHERE p.seller_id = p_seller_id
      AND o.created_at::date BETWEEN p_from AND p_to;

    RETURN v_revenue;
END;
$$ LANGUAGE plpgsql;
