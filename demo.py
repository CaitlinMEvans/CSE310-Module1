import os
import json
import psycopg2
import psycopg2.extras
from decimal import Decimal
from datetime import datetime, timedelta

# ---- Connection ----
DSN = os.getenv(
    "PG_DSN",
    "dbname=laser_shop user=postgres password=C8tspwpw host=localhost port=5432"
)

# ---- Minimal query runner ----
def q(sql, params=None, fetch=None):
    """Run a SQL statement with optional params.
    fetch=None -> no fetch
    fetch="one" -> fetchone dict
    fetch="val" -> first value of first row (or None)
    otherwise -> fetchall list of dicts
    """
    with psycopg2.connect(DSN) as conn, conn.cursor(
        cursor_factory=psycopg2.extras.RealDictCursor
    ) as cur:
        cur.execute(sql, params or ())
        if cur.description is None:
            return None
        if fetch == "one":
            return cur.fetchone()
        if fetch == "val":
            row = cur.fetchone()
            return None if row is None else list(row.values())[0]
        return cur.fetchall()

# ---- CRUD helpers ----
def create_customer(name, email, phone=None):
    """CREATE with UPSERT to keep repeated runs idempotent."""
    return q(
        """
        INSERT INTO customers (name, email, phone)
        VALUES (%s, %s, %s)
        ON CONFLICT (email)
        DO UPDATE SET
          name = EXCLUDED.name,
          phone = EXCLUDED.phone
        RETURNING *;
        """,
        (name, email, phone),
        fetch="one",
    )

def add_order_with_item(email, product_name, qty, custom_text=None, font=None, color=None):
    """CREATE: order + single order_item."""
    cust = q("SELECT customer_id FROM customers WHERE email=%s;", (email,), fetch="one")
    if not cust:
        raise ValueError(f"No customer with email {email}")
    prod = q(
        "SELECT product_id, base_price FROM products WHERE name=%s;",
        (product_name,),
        fetch="one",
    )
    if not prod:
        raise ValueError(f"No product named {product_name}")

    o = q(
        "INSERT INTO orders (customer_id, status) VALUES (%s,'PENDING') RETURNING *;",
        (cust["customer_id"],),
        fetch="one",
    )
    q(
        """
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, custom_text, font, color, specs)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s);
        """,
        (
            o["order_id"],
            prod["product_id"],
            qty,
            prod["base_price"],
            custom_text,
            font,
            color,
            json.dumps({"source": "demo"}),
        ),
    )
    return o

def update_order_status(order_id, new_status):
    """UPDATE: flip order status."""
    return q(
        "UPDATE orders SET status=%s WHERE order_id=%s RETURNING *;",
        (new_status, order_id),
        fetch="one",
    )

def pay_order(order_id, amount, method="card"):
    """CREATE payment (affects financials)."""
    return q(
        """
        INSERT INTO payments (order_id, amount, method)
        VALUES (%s,%s,%s)
        RETURNING *;
        """,
        (order_id, Decimal(amount), method),
        fetch="one",
    )

def delete_customer_by_id(customer_id):
    """DELETE: rely on ON DELETE CASCADE for orders/items/payments."""
    q("DELETE FROM customers WHERE customer_id=%s;", (customer_id,))
    return True

# ---- Reports / READ helpers ----
def order_summary(limit=5):
    """READ: recent orders with totals."""
    return q(
        """
        SELECT o.order_id, o.status, c.name,
               SUM(oi.quantity * oi.unit_price) AS order_total
        FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        JOIN order_items oi ON oi.order_id = o.order_id
        GROUP BY o.order_id, o.status, c.name
        ORDER BY o.order_id DESC
        LIMIT %s;
        """,
        (limit,),
    )

def revenue_by_month(months=6):
    """Aggregate by month from payments."""
    return q(
        """
        SELECT date_trunc('month', paid_at) AS month,
               SUM(amount) AS revenue
        FROM payments
        WHERE paid_at >= now() - (%s || ' months')::interval
        GROUP BY 1
        ORDER BY 1;
        """,
        (months,),
    )

def top_products_since(days=90):
    """Aggregate quantities by product over a time window."""
    return q(
        """
        SELECT p.name, SUM(oi.quantity) AS qty_sold
        FROM order_items oi
        JOIN orders o   ON o.order_id = oi.order_id
        JOIN products p ON p.product_id = oi.product_id
        WHERE o.order_date >= now() - (%s || ' days')::interval
        GROUP BY p.name
        ORDER BY qty_sold DESC, p.name;
        """,
        (days,),
    )

# ---- Pretty print helper for video ----
def print_rows(title, rows):
    print(f"\n== {title} ==")
    if not rows:
        print("(no rows)")
        return
    for r in rows:
        print(dict(r))

# ---- Demo flow ----
if __name__ == "__main__":
    try:
        # CREATE customer (UPSERT so reruns are safe)
        print("Creating demo customer...")
        customer = create_customer("Demo Customer", "demo@example.com", "555-0000")
        print(dict(customer))

        # CREATE order + item
        print("Adding order + item...")
        order = add_order_with_item(
            "demo@example.com",
            "Engraved Tumbler 20oz",
            3,
            custom_text="C&E",
            font="Montserrat",
            color="black",
        )
        print(dict(order))

        # UPDATE status -> IN_PRODUCTION
        print("Updating order status to IN_PRODUCTION...")
        updated = update_order_status(order["order_id"], "IN_PRODUCTION")
        print(dict(updated))

        # CREATE payment (partial)
        print("Paying partial balance...")
        payment = pay_order(order["order_id"], "30.00", "cash")
        print(dict(payment))

        # READ summaries
        print_rows("Latest order summaries", order_summary())
        print_rows("Revenue by month (last 6)", revenue_by_month(6))
        print_rows("Top products (last 90 days)", top_products_since(90))

        # OPTIONAL DELETE: uncomment for the video to show cascade cleanup
        # print("Deleting demo customer (cascade)...")
        # delete_customer_by_id(customer["customer_id"])
        # print_rows("Confirm customer gone", q(
        #     "SELECT * FROM customers WHERE customer_id=%s;", (customer["customer_id"],))
        # )

    except Exception as e:
        print("\n[ERROR]", repr(e))
