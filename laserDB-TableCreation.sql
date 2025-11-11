CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Customers placing orders
CREATE TABLE customers (
  customer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT        NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  phone       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Products you sell (stock + customizable)
CREATE TABLE products (
  product_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT        NOT NULL,
  base_price  NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
  material    TEXT        NOT NULL, -- e.g., "birch plywood", "acrylic", "stainless"
  is_customizable BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Orders (one per customer + date/status)
CREATE TABLE orders (
  order_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
  order_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
  status      TEXT NOT NULL DEFAULT 'PENDING', -- PENDING | IN_PRODUCTION | SHIPPED | CANCELLED
  notes       TEXT
);

-- Items in each order (custom text/specs per item live here)
CREATE TABLE order_items (
  order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
  quantity    INT  NOT NULL CHECK (quantity > 0),
  unit_price  NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0), -- snapshot of price at sale
  custom_text TEXT,                  -- e.g., baby name, couple’s last name
  font        TEXT,                  -- e.g., "Montserrat", "Lobster"
  color       TEXT,                  -- e.g., "natural", "white", "black", "gold"
  specs       JSONB DEFAULT '{}'     -- freeform (dimensions, finish, event_type, etc.)
);

-- Payments (allow split payments)
CREATE TABLE payments (
  payment_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
  amount      NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  method      TEXT NOT NULL, -- "card", "cash", "venmo", etc.
  paid_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Helpful indexes
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);


-- SEED DATA 
-- Customers
INSERT INTO customers (name, email, phone) VALUES
('Avery Johnson', 'avery@example.com', '555-1111'),
('Maya Lee',      'maya@example.com',  '555-2222'),
('Chris Patel',   'chris@example.com', '555-3333');

-- Products
INSERT INTO products (name, base_price, material, is_customizable) VALUES
('Nursery Name Sign 18in', 65.00, 'birch plywood', true),
('Wedding Welcome Sign 24x18', 95.00, 'clear acrylic', true),
('Engraved Tumbler 20oz', 25.00, 'stainless', true),
('Logo Keychain', 6.00, 'acrylic', true);

-- One order with 2 items for Avery
WITH c AS (SELECT customer_id FROM customers WHERE email='avery@example.com')
INSERT INTO orders (customer_id, status, notes)
SELECT customer_id, 'PENDING', 'Need by baby shower' FROM c
RETURNING order_id \gset

INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
SELECT :'order_id',
       product_id, 1, base_price, 'Oliver', 'Montserrat', 'natural',
       jsonb_build_object('event_type','baby_shower','width_in',18,'finish','clearcoat')
FROM products WHERE name='Nursery Name Sign 18in';

INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
SELECT :'order_id',
       product_id, 2, base_price, 'Baby Shower 2025', 'Lobster', 'white',
       jsonb_build_object('event_type','baby_shower')
FROM products WHERE name='Logo Keychain';

INSERT INTO payments (order_id, amount, method) VALUES (:'order_id', 77.00, 'card');

-- A second order (Maya) in a different month to show date filters
WITH c AS (SELECT customer_id FROM customers WHERE email='maya@example.com')
INSERT INTO orders (customer_id, order_date, status)
SELECT customer_id, now() - interval '40 days', 'SHIPPED' FROM c
RETURNING order_id \gset

INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color)
SELECT :'order_id', product_id, 1, base_price, 'The Lees', 'Playfair', 'gold'
FROM products WHERE name='Wedding Welcome Sign 24x18';

INSERT INTO payments (order_id, amount, method, paid_at)
VALUES (:'order_id', 95.00, 'venmo', now() - interval '39 days');

