-- SEED DATA
-- Customers
INSERT INTO customers (name, email, phone) VALUES
('Avery Johnson', 'avery@example.com', '555-1111'),
('Maya Lee',      'maya@example.com',  '555-2222'),
('Chris Patel',   'chris@example.com', '555-3333');

-- Products
INSERT INTO products (name, base_price, material, is_customizable) VALUES
('Nursery Name Sign 18in',        65.00, 'birch plywood',  true),
('Wedding Welcome Sign 24x18',    95.00, 'clear acrylic',  true),
('Engraved Tumbler 20oz',         25.00, 'stainless',      true),
('Logo Keychain',                  6.00, 'acrylic',        true);

-- Order 1: Avery - create order, add two items, add payment
WITH new_order AS (
  INSERT INTO orders (customer_id, status, notes)
  SELECT customer_id, 'PENDING', 'Need by baby shower'
  FROM customers
  WHERE email = 'avery@example.com'
  RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
SELECT no.order_id, p.product_id, 1, p.base_price, 'Oliver', 'Montserrat', 'natural',
       jsonb_build_object('event_type','baby_shower','width_in',18,'finish','clearcoat')
FROM products p
JOIN new_order no ON true
WHERE p.name = 'Nursery Name Sign 18in';

WITH new_order AS (
  SELECT o.order_id
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  WHERE c.email = 'avery@example.com'
  ORDER BY o.order_date DESC
  LIMIT 1
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
SELECT no.order_id, p.product_id, 2, p.base_price, 'Baby Shower 2025', 'Lobster', 'white',
       jsonb_build_object('event_type','baby_shower')
FROM products p
JOIN new_order no ON true
WHERE p.name = 'Logo Keychain';

INSERT INTO payments (order_id, amount, method)
SELECT o.order_id, 77.00, 'card'
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.email = 'avery@example.com'
ORDER BY o.order_date DESC
LIMIT 1;

-- Order 2: Maya - create order 40 days ago, add item, add payment
WITH new_order AS (
  INSERT INTO orders (customer_id, order_date, status)
  SELECT customer_id, now() - interval '40 days', 'SHIPPED'
  FROM customers
  WHERE email = 'maya@example.com'
  RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color)
SELECT no.order_id, p.product_id, 1, p.base_price, 'The Lees', 'Playfair', 'gold'
FROM products p
JOIN new_order no ON true
WHERE p.name = 'Wedding Welcome Sign 24x18';

INSERT INTO payments (order_id, amount, method, paid_at)
SELECT o.order_id, 95.00, 'venmo', now() - interval '39 days'
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.email = 'maya@example.com'
ORDER BY o.order_date DESC
LIMIT 1;

-- Order 3: Chris - 3 tumblers, partial payment
WITH new_order AS (
  INSERT INTO orders (customer_id, status)
  SELECT customer_id, 'IN_PRODUCTION'
  FROM customers
  WHERE email = 'chris@example.com'
  RETURNING order_id
)
INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
SELECT no.order_id, p.product_id, 3, p.base_price, 'C&E', 'Montserrat', 'black',
       jsonb_build_object('source','seed')
FROM products p
JOIN new_order no ON true
WHERE p.name = 'Engraved Tumbler 20oz';

INSERT INTO payments (order_id, amount, method)
SELECT o.order_id, 30.00, 'cash'
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.email = 'chris@example.com'
ORDER BY o.order_date DESC
LIMIT 1;
