-- CREATE: add new product
INSERT INTO products (name, base_price, material, is_customizable)
VALUES ('Glass Champagne Flute (Engraved)', 18.00, 'glass', true)
RETURNING *;

-- READ: find open orders with customer & line totals (JOIN)
SELECT o.order_id, o.status, c.name AS customer,
       SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status IN ('PENDING','IN_PRODUCTION')
GROUP BY o.order_id, o.status, c.name
ORDER BY o.order_id;

-- UPDATE: change order status
UPDATE orders SET status='IN_PRODUCTION'
WHERE order_id = (SELECT order_id FROM orders ORDER BY order_date DESC LIMIT 1)
RETURNING *;

-- DELETE: remove a product (only if not referenced)
-- DELETE FROM products
-- WHERE name='Logo Keychain' AND product_id NOT IN (SELECT product_id FROM order_items)
-- RETURNING *;

-- DELETE: Remove a customer to show Delete in CRUD works 
DELETE FROM customers
WHERE customer_id = 'e735e817-3943-4028-9513-6011be0f69d4';
