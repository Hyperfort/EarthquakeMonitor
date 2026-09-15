import os
import pymysql

from fastapi import FastAPI, Query

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


def db():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USERNAME"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        cursorclass=pymysql.cursors.DictCursor,
    )


@app.get("/quakes/latest")
def latest_quakes(
    limit: int = Query(10, ge=1, le=50),
):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, time, magnitude, place
                FROM earthquakes
                WHERE time >= NOW() - INTERVAL 7 DAY
                ORDER BY time DESC
                LIMIT %s;
            """, (limit,))
            rows = cur.fetchall()
    finally:
        conn.close()
    return rows


@app.get("/quakes/weekly-average")
def weekly_average():
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT AVG(daily_count) AS average_daily_count
                FROM (
                    SELECT DATE(time) AS day, COUNT(*) AS daily_count
                    FROM earthquakes
                    WHERE time >= NOW() - INTERVAL 7 DAY
                    GROUP BY DATE(time)
                ) AS daily_totals;
            """)
            row = cur.fetchone()
    finally:
        conn.close()
    return {"weekly_average": row["average_daily_count"]}


@app.get("/quakes/top")
def top_quakes(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(5, ge=1, le=100),
):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, time, magnitude, place
                FROM earthquakes
                WHERE time >= NOW() - INTERVAL %s DAY
                ORDER BY magnitude DESC
                LIMIT %s;
            """,
                (days, limit),
            )
            rows = cur.fetchall()
    finally:
        conn.close()
    return rows
