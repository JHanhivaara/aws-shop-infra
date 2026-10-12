import os

import psycopg
from fastapi import FastAPI, HTTPException
from psycopg.rows import dict_row
from pydantic import BaseModel, Field

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://app:app@localhost:5432/shop")

app = FastAPI(title="Shop API")


def connect():
    # dict_row: each row comes back as {"id": 1, "name": "Mug", ...}, which FastAPI turns into JSON.
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


@app.get("/products")
def list_products():
    with connect() as conn:
        return conn.execute("select id, name, price_cents, stock from products order by id").fetchall()


@app.get("/products/{product_id}")
def get_product(product_id: int):
    with connect() as conn:
        product = conn.execute(
            "select id, name, price_cents, stock from products where id = %s",
            (product_id,),
        ).fetchone()
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


class OrderItem(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class OrderRequest(BaseModel):
    items: list[OrderItem] = Field(min_length=1)


@app.post("/orders", status_code=201)
def create_order(order: OrderRequest):
    with connect() as conn, conn.transaction():
        for item in order.items:
            updated = conn.execute(
                """
                update products
                   set stock = stock - %s
                 where id = %s and stock >= %s
                returning id
                """,
                (item.quantity, item.product_id, item.quantity),
            ).fetchone()
            if updated is None:
                raise HTTPException(status_code=409, detail=f"Not enough stock for product {item.product_id}")

        order_id = conn.execute("insert into orders default values returning id").fetchone()["id"]
        for item in order.items:
            conn.execute(
                "insert into order_items (order_id, product_id, quantity) values (%s, %s, %s)",
                (order_id, item.product_id, item.quantity),
            )
    return {"order_id": order_id}
