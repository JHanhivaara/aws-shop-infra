import os

import psycopg
from fastapi import FastAPI, HTTPException
from psycopg.rows import dict_row

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

