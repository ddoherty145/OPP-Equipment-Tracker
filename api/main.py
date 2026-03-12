from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Literal, Optional
from datetime import date, datetime
import os

# ─── psycopg 3 imports ───────────────────────────────────────────────────────
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from import_parsers import parse_equipment_excel_bytes, parse_equipment_pdf_bytes
from reporting import (
    ProfitMode,
    ReportFormat,
    ReportName,
    ensure_reporting_schema,
    fetch_report_rows,
    render_report,
)

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
    acquisition_date: Optional[date] = None

class ImportResult(BaseModel):
    equipment_processed: int
    logs_inserted: int
    logs_skipped: int
    source: str

# ─── Helpers ─────────────────────────────────────────────────────────────────

def get_connection():
    """Context manager for getting a connection from the pool"""
    return pool.connection()


with get_connection() as _conn:
    ensure_reporting_schema(_conn)


def _format_date(date_str: str) -> Optional[str]:
    try:
        dt = datetime.fromisoformat(date_str).date() if "-" in date_str else datetime.strptime(date_str, "%m/%d/%Y").date()
        return dt.isoformat()
    except Exception:
        # expected input from parser uses MM/DD/YYYY
        try:
            month, day_part, year = date_str.split("/")
            return f"{year}-{month.zfill(2)}-{day_part.zfill(2)}"
        except Exception:
            return None


def _insert_imported_data(equipment_data) -> dict:
    equipment_processed = 0
    logs_inserted = 0
    logs_skipped = 0

    with get_connection() as conn:
        with conn.cursor() as cur:
            for equipment in equipment_data:
                equipment_code = equipment.get("equipment_id")
                name = equipment.get("name") or equipment_code
                acquisition_date = equipment.get("acquisition_date")
                if not equipment_code:
                    continue

                cur.execute(
                    """
                    INSERT INTO equipment (equipment_id, name, acquisition_date)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (equipment_id)
                    DO UPDATE SET
                      name = EXCLUDED.name,
                      acquisition_date = COALESCE(EXCLUDED.acquisition_date, equipment.acquisition_date),
                      updated_at = CURRENT_TIMESTAMP
                    RETURNING id
                    """,
                    (equipment_code, name, acquisition_date),
                )
                row = cur.fetchone()
                if not row:
                    continue

                equipment_db_id = row["id"]
                equipment_processed += 1

                for log in equipment.get("usage_logs", []):
                    formatted_date = _format_date(str(log.get("date", "")))
                    hours = log.get("hours")
                    cost = log.get("cost")
                    revenue = log.get("revenue")

                    if formatted_date is None or hours is None or cost is None or revenue is None:
                        logs_skipped += 1
                        continue

                    cur.execute(
                        """
                        INSERT INTO usage_logs (equipment_id, date, hours, cost, revenue)
                        SELECT %s, %s, %s, %s, %s
                        WHERE NOT EXISTS (
                          SELECT 1
                          FROM usage_logs
                          WHERE equipment_id = %s
                            AND date = %s
                            AND hours = %s
                            AND cost = %s
                            AND revenue = %s
                        )
                        RETURNING id
                        """,
                        (
                            equipment_db_id,
                            formatted_date,
                            float(hours),
                            float(cost),
                            float(revenue),
                            equipment_db_id,
                            formatted_date,
                            float(hours),
                            float(cost),
                            float(revenue),
                        ),
                    )
                    inserted = cur.fetchone()
                    if inserted:
                        logs_inserted += 1
                    else:
                        logs_skipped += 1

            conn.commit()

    return {
        "equipment_processed": equipment_processed,
        "logs_inserted": logs_inserted,
        "logs_skipped": logs_skipped,
    }

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
                    e.acquisition_date,
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


@app.post("/imports/pdf", response_model=ImportResult)
async def import_pdf(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Expected a .pdf file")

    raw_bytes = await file.read()
    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Uploaded PDF is empty")

    try:
        equipment_data = parse_equipment_pdf_bytes(raw_bytes)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to parse PDF: {exc}") from exc

    if not equipment_data:
        raise HTTPException(status_code=422, detail="No equipment usage data found in PDF")

    summary = _insert_imported_data(equipment_data)
    return ImportResult(**summary, source=file.filename)


@app.post("/imports/excel", response_model=ImportResult)
async def import_excel(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith((".xlsx", ".xlsm")):
        raise HTTPException(status_code=400, detail="Expected an .xlsx/.xlsm file")

    raw_bytes = await file.read()
    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Uploaded Excel file is empty")

    try:
        equipment_data = parse_equipment_excel_bytes(raw_bytes)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to parse Excel file: {exc}") from exc

    if not equipment_data:
        raise HTTPException(
            status_code=422,
            detail="No rows parsed. Ensure columns include equipment_id, date, hours, cost, revenue",
        )

    summary = _insert_imported_data(equipment_data)
    return ImportResult(**summary, source=file.filename)


@app.get("/reports/{report_name}")
def generate_report(
    report_name: ReportName,
    format: ReportFormat = Query(default="xlsx"),
    equipment_id: Optional[str] = Query(default=None),
    profit_mode: ProfitMode = Query(default="per_hour_delta"),
):
    with get_connection() as conn:
        rows = fetch_report_rows(
            conn=conn,
            report_name=report_name,
            equipment_code=equipment_id,
            profit_mode=profit_mode,
        )

    rendered = render_report(
        report_name=report_name,
        rows=rows,
        output_format=format,
        profit_mode=profit_mode,
        equipment_code=equipment_id,
    )

    return StreamingResponse(
        iter([rendered.content]),
        media_type=rendered.content_type,
        headers={"Content-Disposition": f'attachment; filename="{rendered.filename}"'},
    )