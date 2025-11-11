-- Revenue by month (last 6 months), based on payments
SELECT date_trunc('month', paid_at) AS month,
       SUM(amount) AS revenue
FROM payments
WHERE paid_at >= now() - interval '6 months'
GROUP BY 1
ORDER BY 1;

-- Top products by sales (qty) in a date range
SELECT p.name, SUM(oi.quantity) AS qty_sold
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_date BETWEEN date_trunc('month', now()) - interval '1 month'
                       AND date_trunc('month', now()) + interval '1 month' - interval '1 day'
GROUP BY p.name
ORDER BY qty_sold DESC;

-- Open order backlog (value not yet fully paid)
WITH order_totals AS (
  SELECT o.order_id,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status IN ('PENDING','IN_PRODUCTION')
  GROUP BY o.order_id
),
paid AS (
  SELECT order_id, COALESCE(SUM(amount),0) AS paid_total
  FROM payments
  GROUP BY order_id
)
SELECT o.order_id, c.name, ot.order_total, p.paid_total,
       (ot.order_total - p.paid_total) AS balance_due
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_totals ot ON ot.order_id = o.order_id
LEFT JOIN paid p ON p.order_id = o.order_id
WHERE (ot.order_total - COALESCE(p.paid_total,0)) > 0
ORDER BY balance_due DESC;
