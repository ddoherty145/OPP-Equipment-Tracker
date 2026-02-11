from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, date
import psycopg2
from psycopg2.extras import RealDictCursor
import os

app = FastAPI(title="Equipment Tracker API")

# Enable CORS for moblie app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Connection
def get_db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        database=os.getenv("DB_NAME", "equipment_db"),
        user=os.getenv("DB_USER", "admin"),
        password=os.getenv("DB_PASSWORD", "password"),
        cursor_factory=RealDictCursor
    )

# Models
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

# API Endpoints
@app.get("/")
def root():
    return {"message": "Welcome to the Equipment Tracker API!", "status": "running"}

@app.get("/equipment", response_model=List[Equipment])
def get_all_equipment():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
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

    equipment = cursor.fetchall()
    cursor.close()
    conn.close()

    return equipment

@app.get("/equipment/{equipment_id}")
def get_equipment_details(equipment_id: int):
    """Get detailed equipment info with all usage logs"""
    conn = get_db()
    cursor = conn.cursor()

    # Get equipment details
    cursor.execute("SELECT * FROM equipment WHERE id = %s", (equipment_id,))
    equipment = cursor.fetchone()

    if not equipment:
        raise HTTPException(status_code=404, detail="Equipment not found")
    
    # Get usage logs for the equipment
    cursor.execute("""
        SELECT * FROM usage_logs
        WHERE equipment_id = %s
        ORDER BY date DESC
    """, (equipment_id,))
    logs = cursor.fetchall()

    cursor.close()
    conn.close()

    return {
            "equipment": equipment,
            "usage_logs": logs
    }

@app.get("/analytics/summary")
def get_analytics_summary():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("""
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

    summary = cursor.fetchone()
    cursor.close()
    conn.close()

    return summary 

@app.post("/usage_logs", response_model=UsageLog)
def create_usage_log(log: UsageLog):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("SELECT 1 FROM equipment WHERE id = %s", (log.equipment_id,))
    if not cursor.fetchone():
        raise HTTPException(404, "Equipment not found")

    profit = log.revenue - log.cost

    cursor.execute("""
        INSERT INTO usage_logs 
            (equipment_id, date, hours, cost, revenue, profit)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id, equipment_id, date, hours, cost, revenue, profit
    """, (log.equipment_id, log.date, log.hours, log.cost, log.revenue, profit))

    new_log = cursor.fetchone()
    conn.commit()
    cursor.close()
    conn.close()

    return new_log

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)