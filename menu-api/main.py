import json
import os

import psycopg
import redis
from fastapi import FastAPI

app = FastAPI(title="Dhaba Menu API")
GIT_SHA = os.getenv("GIT_SHA", "dev")

DEFAULT_MENU = [
    {"id": 1, "name": "Chicken Karahi", "price": 1200},
    {"id": 2, "name": "Mutton Shinwari", "price": 2200},
    {"id": 3, "name": "Garlic Naan", "price": 80},
]

def get_redis():
    addr = os.getenv("REDIS_ADDR", "")
    if not addr:
        return None
    host, _, port = addr.partition(":")
    return redis.Redis(host=host, port=int(port or 6379), decode_responses=True)

@app.get("/health")
def health():
    return {"status": "ok", "version": GIT_SHA}

@app.get("/api/menu")
def read_menu():
    rdb = get_redis()
    if rdb:
        try:
            cached = rdb.get("menu:all")
            if cached:
                return {"source": "cache", "items": json.loads(cached)}
        except redis.RedisError:
            pass

    dsn = os.getenv("DATABASE_URL", "")
    items = DEFAULT_MENU
    if dsn:
        try:
            with psycopg.connect(dsn) as conn, conn.cursor() as cur:
                cur.execute("SELECT id, name, price FROM menu_items ORDER BY id")
                rows = cur.fetchall()
                if rows:
                    items = [{"id": r[0], "name": r[1], "price": r[2]} for r in rows]
        except psycopg.Error:
            pass

    if rdb:
        try:
            rdb.setex("menu:all", 60, json.dumps(items))
        except redis.RedisError:
            pass

    return {"source": "db", "items": items}
