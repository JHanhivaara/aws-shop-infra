import json
import os
from importlib.resources import files

import boto3
import psycopg
from mangum import Mangum

from shop.app import app

api = Mangum(app, lifespan="off")


def handler(event, context):
    # One-off setup, invoked by hand: aws lambda invoke --payload '{"action":"migrate"}'
    if event.get("action") == "migrate":
        return migrate()
    return api(event, context)


def migrate():
    """Create tables, seed data and the IAM-auth user, connecting as the RDS master user."""
    secret = boto3.client("secretsmanager").get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    master = json.loads(secret["SecretString"])
    sql = files("shop") / "sql"

    with psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname="shop",
        user=master["username"],
        password=master["password"],
        sslmode="require",
        autocommit=True,
    ) as conn:
        if conn.execute("select to_regclass('products')").fetchone()[0] is not None:
            return {"status": "already migrated"}
        for name in ("schema.sql", "seed.sql", "grants.sql"):
            conn.execute((sql / name).read_text())
        conn.execute("grant rds_iam to shop_api")
    return {"status": "migrated"}
