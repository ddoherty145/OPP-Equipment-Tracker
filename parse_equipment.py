"""
Equipment Usage Report Parser
Parses PDF reports from ERP system and imports into PostgreSQL database
"""
import re
import sys
from datetime import datetime
from typing import List, Dict, Any, Optional

import pdfplumber
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
import os

# ============================================================================
# CONFIGURATION & GLOBAL POOL
# ============================================================================

DB_CONNINFO = (
    f"host={os.getenv('DB_HOST', 'localhost')} "
    f"port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('DB_NAME', 'equipment_db')} "
    f"user={os.getenv('DB_USER', 'admin')} "
    f"password={os.getenv('DB_PASSWORD', 'admin')}"
)

pool: Optional[ConnectionPool] = None


def init_pool():
    global pool
    pool = ConnectionPool(
        conninfo=DB_CONNINFO,
        min_size=1,
        max_size=5,
        timeout=30,
        kwargs={"row_factory": dict_row},
        open=False,  # we'll open connections explicitly when needed
    )
    print("Database connection pool initialized")


# ============================================================================
# PDF PARSING
# ============================================================================

def parse_equipment_pdf(pdf_path: str) -> List[Dict[str, Any]]:
    """
    Parse Equipment Usage Report PDF and extract structured data
    """
    extracted_data = []

    # Equipment header: "Equipment: 10125-DL - Int'l 2275 Dump Truck"
    eq_header_pattern = re.compile(r"Equipment:\s+([A-Z0-9\-]+)\s+-\s+(.+?)(?:\s*$|\s+[-–—])", re.IGNORECASE)

    # Data row patterns - more flexible to handle different spacing/formats
    data_row_pattern = re.compile(
        r"""
        (\d{1,2}/\d{1,2}/\d{4})            # Date: MM/DD/YYYY
        .*?
        (\d+\.\d{2})                       # Hours: X.XX
        .*?
        ([\d,]+\.\d{2})                    # Cost: X,XXX.XX or XXX.XX
        .*?
        ([\d,]+\.\d{2})                    # Revenue: X,XXX.XX or XXX.XX
        """,
        re.VERBOSE | re.IGNORECASE
    )

    current_equipment = None

    print(f"\n📄 Parsing PDF: {pdf_path}")
    print("═" * 80)

    try:
        with pdfplumber.open(pdf_path) as pdf:
            print(f"Total pages: {len(pdf.pages)}")

            for page_num, page in enumerate(pdf.pages, 1):
                text = page.extract_text()
                if not text:
                    continue

                print(f"  Page {page_num:2d}/{len(pdf.pages)}", end="")

                for line in text.splitlines():
                    line = line.strip()

                    # New equipment section
                    eq_match = eq_header_pattern.search(line)
                    if eq_match:
                        eq_id = eq_match.group(1).strip()
                        name = eq_match.group(2).strip()
                        current_equipment = {
                            "equipment_id": eq_id,
                            "name": name,
                            "usage_logs": []
                        }
                        extracted_data.append(current_equipment)
                        print(f"\n  → Found: {eq_id} - {name}")
                        continue

                    # Data row
                    if current_equipment:
                        row_match = data_row_pattern.search(line)
                        if row_match:
                            try:
                                date_str = row_match.group(1)
                                hours = float(row_match.group(2).replace(',', ''))
                                cost = float(row_match.group(3).replace(',', ''))
                                revenue = float(row_match.group(4).replace(',', ''))

                                current_equipment["usage_logs"].append({
                                    "date": date_str,
                                    "hours": hours,
                                    "cost": cost,
                                    "revenue": revenue
                                })
                            except (ValueError, TypeError) as e:
                                print(f"    Warning: Failed to parse row: {line[:60]}... ({e})")

                print("", end="\r")  # clear line

        print("\n" + "═" * 80)
        print(f"Found {len(extracted_data)} equipment records")
        total_logs = sum(len(eq["usage_logs"]) for eq in extracted_data)
        print(f"Total usage entries: {total_logs}")

        return extracted_data

    except FileNotFoundError:
        print(f"❌ File not found: {pdf_path}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error parsing PDF: {e}")
        sys.exit(1)


# ============================================================================
# DATE & DATA HELPERS
# ============================================================================

def parse_date(date_str: str) -> Optional[str]:
    """Convert MM/DD/YYYY → YYYY-MM-DD"""
    try:
        dt = datetime.strptime(date_str.strip(), "%m/%d/%Y")
        return dt.strftime("%Y-%m-%d")
    except ValueError:
        return None


# ============================================================================
# DATABASE OPERATIONS
# ============================================================================

def insert_into_database(equipment_data: List[Dict[str, Any]], dry_run: bool = False) -> None:
    if not equipment_data:
        print("No data to insert")
        return

    if dry_run:
        print("\nDRY RUN MODE - no changes will be made to the database\n")
    else:
        print("\nInserting data into database...")
        print("═" * 80)

    inserted_equipment = 0
    inserted_logs = 0

    with pool.connection() as conn:
        with conn.cursor() as cur:
            try:
                for eq in equipment_data:
                    eq_id = eq["equipment_id"]
                    name = eq["name"]

                    print(f"  Processing: {eq_id} - {name}")

                    # Upsert equipment
                    cur.execute("""
                        INSERT INTO equipment (equipment_id, name)
                        VALUES (%s, %s)
                        ON CONFLICT (equipment_id) DO UPDATE
                            SET name = EXCLUDED.name,
                                updated_at = CURRENT_TIMESTAMP
                        RETURNING id
                    """, (eq_id, name))

                    equipment_db_id = cur.fetchone()["id"]
                    inserted_equipment += 1

                    # Insert logs
                    for log in eq["usage_logs"]:
                        db_date = parse_date(log["date"])
                        if not db_date:
                            print(f"    Skipping invalid date: {log['date']}")
                            continue

                        if not dry_run:
                            cur.execute("""
                                INSERT INTO usage_logs 
                                    (equipment_id, date, hours, cost, revenue)
                                VALUES (%s, %s, %s, %s, %s)
                                ON CONFLICT DO NOTHING
                            """, (
                                equipment_db_id,
                                db_date,
                                log["hours"],
                                log["cost"],
                                log["revenue"]
                            ))

                            if cur.rowcount > 0:
                                inserted_logs += 1

                    print(f"    → {len(eq['usage_logs'])} entries processed")

                if not dry_run:
                    conn.commit()
                    print("\nCommit successful!")
                else:
                    print("\nDry run complete - no changes saved")

                print(f"\nSummary:")
                print(f"  • Equipment records: {inserted_equipment}")
                print(f"  • Usage log entries: {inserted_logs}")

            except Exception as e:
                if not dry_run:
                    conn.rollback()
                print(f"\n❌ Database error: {e}")
                sys.exit(1)


# ============================================================================
# VERIFICATION
# ============================================================================

def verify_data():
    """Quick summary check from database"""
    print("\nVerifying inserted data...")
    print("═" * 80)

    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    e.equipment_id,
                    e.name,
                    COUNT(ul.id) AS log_count,
                    ROUND(COALESCE(SUM(ul.hours), 0)::numeric, 2) AS total_hours,
                    ROUND(COALESCE(SUM(ul.revenue), 0)::numeric, 2) AS total_revenue,
                    ROUND(COALESCE(SUM(ul.profit), 0)::numeric, 2) AS total_profit
                FROM equipment e
                LEFT JOIN usage_logs ul ON e.id = ul.equipment_id
                GROUP BY e.id, e.equipment_id, e.name
                ORDER BY e.equipment_id
            """)

            rows = cur.fetchall()

            if not rows:
                print("No data found in database")
                return

            print(f"{'ID':<12} {'Name':<30} {'Logs':<6} {'Hours':<10} {'Revenue':<12} {'Profit':<12}")
            print("-" * 82)

            grand_total_logs = 0
            grand_total_hours = 0
            grand_total_revenue = 0
            grand_total_profit = 0

            for row in rows:
                eq_id, name, logs, hours, revenue, profit = row
                logs = logs or 0
                hours = hours or 0
                revenue = revenue or 0
                profit = profit or 0

                grand_total_logs += logs
                grand_total_hours += hours
                grand_total_revenue += revenue
                grand_total_profit += profit

                name_display = (name[:27] + "...") if len(name) > 27 else name

                print(f"{eq_id:<12} {name_display:<30} {logs:<6} {hours:>9.2f} ${revenue:>11.2f} ${profit:>11.2f}")

            print("-" * 82)
            print(f"{'TOTAL':<12} {'':<30} {grand_total_logs:<6} {grand_total_hours:>9.2f} ${grand_total_revenue:>11.2f} ${grand_total_profit:>11.2f}")


# ============================================================================
# MAIN
# ============================================================================

def main():
    print("═" * 80)
    print("      EQUIPMENT USAGE REPORT PARSER (2025 Edition)")
    print("═" * 80)

    if len(sys.argv) < 2:
        print("Usage:")
        print(f"  python {sys.argv[0]} <path_to_pdf> [--dry-run]")
        print()
        sys.exit(1)

    pdf_path = sys.argv[1]
    dry_run = "--dry-run" in sys.argv

    if not os.path.isfile(pdf_path):
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)

    init_pool()

    try:
        data = parse_equipment_pdf(pdf_path)

        if not data:
            print("No equipment data found in PDF")
            return

        insert_into_database(data, dry_run=dry_run)

        if not dry_run:
            verify_data()

        print("\n" + "═" * 80)
        print("Process completed successfully!")
        print("═" * 80)

    finally:
        if pool:
            pool.close()
            print("Connection pool closed")


if __name__ == "__main__":
    main()