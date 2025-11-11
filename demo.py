import os
import json
import psycopg2
import psycopg2.extras
from decimal import Decimal

DSN = os.getenv("PG_DSN", "dbname=laser_shop user=postgres password=postgres host=localhost port=5432")

def q(sql, params=None, fetch="all"):
    with psycopg2.connect(DSN) as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql, params or ())
        if fetch == "one":
            r = cur.fetchone()
        elif fetch == "all":
            r = cur.fetchall()
        else:
            r = None
        return r

def create_customer(name, email, phone=None):
    return q("""
        INSERT INTO customers (name, email, phone) VALUES (%s,%s,%s)
        RETURNING *;
    """, (name, email, phone), fetch="one")

def add_order_with_item(email, product_name, qty, custom_text=None, font=None, color=None):
    cust = q("SELECT customer_id FROM customers WHERE email=%s;", (email,), fetch="one")
    prod = q("SELECT product_id, base_price FROM products WHERE name=%s;", (product_name,), fetch="one")
    o = q("INSERT INTO orders (customer_id, status) VALUES (%s,'PENDING') RETURNING *;", (cust["customer_id"],), fetch="one")
    q("""
      INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
      VALUES (%s,%s,%s,%s,%s,%s,%s,%s);
    """, (o["order_id"], prod["product_id"], qty, prod["base_price"], custom_text, font, color, json.dumps({"source":"demo"})))
    return o

def order_summary():
    return q("""
      SELECT o.order_id, o.status, c.name,
             SUM(oi.quantity * oi.unit_price) AS order_total
      FROM orders o
      JOIN customers c ON c.customer_id = o.customer_id
      JOIN order_items oi ON oi.order_id = o.order_id
      GROUP BY o.order_id, o.status, c.name
      ORDER BY o.order_id DESC
      LIMIT 5;
    """)

def pay_order(order_id, amount, method="card"):
    return q("""
      INSERT INTO payments (order_id, amount, method) VALUES (%s,%s,%s)
      RETURNING *;
    """, (order_id, Decimal(amount), method), fetch="one")

if __name__ == "__main__":
    print("Creating demo customer...")
    c = create_customer("Demo Customer", "demo@example.com", "555-0000")
    print(c)

    print("Adding order + item...")
    o = add_order_with_item("demo@example.com", "Engraved Tumbler 20oz", 3,
                            custom_text="C&E", font="Montserrat", color="black")
    print(o)

    print("Paying partial balance...")
    p = pay_order(o["order_id"], "30.00", "cash")
    print(p)

    print("Latest order summaries:")
    for row in order_summary():
        print(dict(row))
