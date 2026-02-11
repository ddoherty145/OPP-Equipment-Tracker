from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import date
import os

# ─── psycopg 3 imports ───────────────────────────────────────────────────────
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

app = FastAPI(title="Equipment Tracker API")

# Enable CORS for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Connection Pool (created once at startup) ───────────────────────────────
pool: ConnectionPool = None

def init_db_pool():
    global pool
    pool = ConnectionPool(
        conninfo=(
            f"host={os.getenv('DB_HOST', 'postgres')} "
            f"port={os.getenv('DB_PORT', '5432')} "
            f"dbname={os.getenv('DB_NAME', 'equipment_db')} "
            f"user={os.getenv('DB_USER', 'admin')} "
            f"password={os.getenv('DB_PASSWORD', 'admin')}"
        ),
        min_size=2,
        max_size=12,
        timeout=45,
        # Forward row_factory to every connection created by the pool
        kwargs={"row_factory": dict_row},
    )

# Initialize pool when module is loaded
init_db_pool()

# Models (unchanged)
class UsageLog(BaseModel):
    id: Optional[int] = None
    equipment_id: int
    date: date
    hours: float
    cost: float
    revenue: float
    profit: Optional[float] = None

class Equipment(BaseModel):
    id: Optional[int] = None
    equipment_id: str
    name: str
    total_hours: Optional[float] = 0
    total_revenue: Optional[float] = 0
    total_profit: Optional[float] = 0

# ─── Helpers ─────────────────────────────────────────────────────────────────

def get_connection():
    """Context manager for getting a connection from the pool"""
    return pool.connection()

# ─── API Endpoints ───────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "Welcome to the Equipment Tracker API!", "status": "running"}

@app.get("/equipment", response_model=List[Equipment])
def get_all_equipment():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    e.id,
                    e.equipment_id,
                    e.name,
                    COALESCE(SUM(ul.hours), 0) as total_hours,
                    COALESCE(SUM(ul.revenue), 0) as total_revenue,
                    COALESCE(SUM(ul.profit), 0) as total_profit
                FROM equipment e
                LEFT JOIN usage_logs ul ON e.id = ul.equipment_id
                GROUP BY e.id
                ORDER BY e.equipment_id
            """)
            return cur.fetchall()

@app.get("/equipment/{equipment_id}")
def get_equipment_details(equipment_id: int):
    """Get detailed equipment info with all usage logs"""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM equipment WHERE id = %s", (equipment_id,))
            equipment = cur.fetchone()

            if not equipment:
                raise HTTPException(status_code=404, detail="Equipment not found")

            cur.execute("""
                SELECT * FROM usage_logs
                WHERE equipment_id = %s
                ORDER BY date DESC
            """, (equipment_id,))
            logs = cur.fetchall()

            return {
                "equipment": equipment,
                "usage_logs": logs
            }

@app.get("/analytics/summary")
def get_analytics_summary():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    COUNT(DISTINCT e.id) as total_equipment,
                    COUNT(ul.id) as total_logs,
                    COALESCE(SUM(ul.hours), 0) as total_hours,
                    COALESCE(SUM(ul.cost), 0) as total_cost,
                    COALESCE(SUM(ul.revenue), 0) as total_revenue,
                    COALESCE(SUM(ul.profit), 0) as total_profit,
                    CASE WHEN COUNT(ul.id) > 0 
                         THEN AVG(ul.hours) 
                         ELSE 0 
                    END as avg_hours_per_log
                FROM equipment e
                LEFT JOIN usage_logs ul ON e.id = ul.equipment_id
            """)
            return cur.fetchone()

@app.post("/usage_logs", response_model=UsageLog)
def create_usage_log(log: UsageLog):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM equipment WHERE id = %s", (log.equipment_id,))
            if not cur.fetchone():
                raise HTTPException(404, "Equipment not found")

            profit = log.revenue - log.cost

            cur.execute("""
                INSERT INTO usage_logs 
                    (equipment_id, date, hours, cost, revenue, profit)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, equipment_id, date, hours, cost, revenue, profit
            """, (
                log.equipment_id,
                log.date,
                log.hours,
                log.cost,
                log.revenue,
                profit
            ))

            new_log = cur.fetchone()
            conn.commit()
            return new_log