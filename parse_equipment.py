"""
Equipment Usage Report Parser
Parses PDF reports from ERP system and imports into PostgreSQL database
"""

import re
import psycopg2
import os
import sys
from datetime import datetime
from typing import List, Dict, Any

from api.import_parsers import parse_equipment_pdf_bytes

# ============================================================================
# DATABASE CONNECTION (SIMPLE - NO POOLING)
# ============================================================================

def connect_to_database():
    """
    Connect to Docker PostgreSQL database
    
    Returns:
        psycopg2.connection: Database connection object
    """
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            database=os.getenv("DB_NAME", "equipment_db"),
            user=os.getenv("DB_USER", "admin"),
            password=os.getenv("DB_PASSWORD", "admin")
        )
        print("✅ Successfully connected to database")
        return conn
    except psycopg2.Error as e:
        print(f"❌ Database connection error: {e}")
        sys.exit(1)


# ============================================================================
# PDF PARSING
# ============================================================================

def parse_equipment_pdf(pdf_path: str) -> List[Dict[str, Any]]:
    """
    Parse Equipment Usage Report PDF and extract structured data
    
    Args:
        pdf_path: Path to the PDF file
        
    Returns:
        List of dictionaries containing equipment data and usage logs
    """
    extracted_data = []
    
    print(f"\n📄 Opening PDF: {pdf_path}")
    print("=" * 80)
    
    try:
        with open(pdf_path, "rb") as f:
            extracted_data = parse_equipment_pdf_bytes(f.read())
        
        print("\n" + "=" * 80)
        print(f"✅ Extraction complete!")
        print(f"📊 Found {len(extracted_data)} equipment records")
        
        total_logs = sum(len(eq["usage_logs"]) for eq in extracted_data)
        print(f"📈 Total usage log entries: {total_logs}")
        
        return extracted_data
        
    except Exception as e:
        print(f"❌ Error parsing PDF: {e}")
        sys.exit(1)


# ============================================================================
# DATABASE INSERTION
# ============================================================================

def format_date(date_str: str) -> str:
    """Convert date from MM/DD/YYYY to YYYY-MM-DD format"""
    try:
        date_parts = date_str.split('/')
        month = date_parts[0].zfill(2)
        day = date_parts[1].zfill(2)
        year = date_parts[2]
        return f"{year}-{month}-{day}"
    except (IndexError, ValueError) as e:
        print(f"⚠️  Warning: Invalid date format '{date_str}': {e}")
        return None


def insert_into_database(equipment_data: List[Dict[str, Any]]) -> None:
    """Insert parsed equipment data into PostgreSQL database"""
    if not equipment_data:
        print("⚠️  No data to insert")
        return
    
    conn = connect_to_database()
    cursor = conn.cursor()
    
    total_equipment = 0
    total_logs = 0
    
    print("\n" + "=" * 80)
    print("💾 Inserting data into database...")
    print("=" * 80 + "\n")
    
    try:
        for equipment in equipment_data:
            equipment_id = equipment['equipment_id']
            name = equipment['name']
            
            print(f"📝 Processing: {equipment_id} - {name}")
            
            # Insert or update equipment
            cursor.execute("""
                INSERT INTO equipment (equipment_id, name)
                VALUES (%s, %s)
                ON CONFLICT (equipment_id) 
                DO UPDATE SET 
                    name = EXCLUDED.name,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING id
            """, (equipment_id, name))
            
            equipment_db_id = cursor.fetchone()[0]
            total_equipment += 1
            print(f"   ✅ Equipment saved (DB ID: {equipment_db_id})")
            
            # Insert usage logs
            log_count = 0
            skipped_count = 0
            
            for log in equipment['usage_logs']:
                formatted_date = format_date(log['date'])
                
                if not formatted_date:
                    skipped_count += 1
                    continue
                
                try:
                    cursor.execute("""
                        INSERT INTO usage_logs (equipment_id, date, hours, cost, revenue)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT DO NOTHING
                    """, (equipment_db_id, formatted_date, log['hours'], log['cost'], log['revenue']))
                    
                    if cursor.rowcount > 0:
                        log_count += 1
                        total_logs += 1
                        
                except psycopg2.Error as e:
                    print(f"   ⚠️  Warning: Could not insert log for {formatted_date}: {e}")
                    skipped_count += 1
                    continue
            
            print(f"   📊 Inserted {log_count} usage logs", end="")
            if skipped_count > 0:
                print(f" ({skipped_count} skipped)")
            else:
                print()
            print()
        
        conn.commit()
        
        print("=" * 80)
        print("✅ Database insertion complete!")
        print(f"📊 Summary:")
        print(f"   • Equipment records: {total_equipment}")
        print(f"   • Usage log entries: {total_logs}")
        print("=" * 80)
        
    except psycopg2.Error as e:
        conn.rollback()
        print(f"\n❌ Database error: {e}")
        print("🔄 All changes have been rolled back")
        sys.exit(1)
    except Exception as e:
        conn.rollback()
        print(f"\n❌ Unexpected error: {e}")
        print("🔄 All changes have been rolled back")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()
        print("🔌 Database connection closed")


# ============================================================================
# VERIFICATION
# ============================================================================

def verify_data() -> None:
    """Verify the data was inserted correctly"""
    print("\n" + "=" * 80)
    print("🔍 Verifying inserted data...")
    print("=" * 80 + "\n")
    
    conn = connect_to_database()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT 
                e.equipment_id,
                e.name,
                COUNT(ul.id) as log_count,
                SUM(ul.hours) as total_hours,
                SUM(ul.cost) as total_cost,
                SUM(ul.revenue) as total_revenue,
                SUM(ul.profit) as total_profit
            FROM equipment e
            LEFT JOIN usage_logs ul ON e.id = ul.equipment_id
            GROUP BY e.id, e.equipment_id, e.name
            ORDER BY e.equipment_id
        """)
        
        results = cursor.fetchall()
        
        if not results:
            print("⚠️  No data found in database")
            return
        
        print(f"{'Equipment ID':<15} {'Name':<30} {'Logs':<8} {'Hours':<10} {'Revenue':<12} {'Profit':<12}")
        print("-" * 95)
        
        total_logs = 0
        total_hours = 0
        total_revenue = 0
        total_profit = 0
        
        for row in results:
            eq_id, name, log_count, hours, cost, revenue, profit = row
            
            log_count = log_count or 0
            hours = float(hours or 0)
            revenue = float(revenue or 0)
            profit = float(profit or 0)
            
            total_logs += log_count
            total_hours += hours
            total_revenue += revenue
            total_profit += profit
            
            display_name = name[:28] + "..." if len(name) > 30 else name
            
            print(f"{eq_id:<15} {display_name:<30} {log_count:<8} {hours:<10.2f} ${revenue:<11.2f} ${profit:<11.2f}")
        
        print("-" * 95)
        print(f"{'TOTAL':<15} {'':<30} {total_logs:<8} {total_hours:<10.2f} ${total_revenue:<11.2f} ${total_profit:<11.2f}")
        print()
        
    except psycopg2.Error as e:
        print(f"❌ Error verifying data: {e}")
    finally:
        cursor.close()
        conn.close()


# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main function"""
    print("\n" + "=" * 80)
    print(" " * 20 + "EQUIPMENT USAGE REPORT PARSER")
    print("=" * 80)
    
    if len(sys.argv) < 2:
        print("\n❌ Error: No PDF file specified")
        print("\n📖 Usage:")
        print(f"   python {sys.argv[0]} <path_to_pdf>")
        print("\n📝 Example:")
        print(f'   python {sys.argv[0]} "Equipment Usage Report.pdf"')
        print()
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    
    if not os.path.exists(pdf_path):
        print(f"\n❌ Error: File not found: {pdf_path}")
        sys.exit(1)
    
    file_size = os.path.getsize(pdf_path) / 1024
    print(f"\n📁 File: {os.path.basename(pdf_path)}")
    print(f"📏 Size: {file_size:.2f} KB")
    print(f"📍 Path: {pdf_path}")
    
    equipment_data = parse_equipment_pdf(pdf_path)
    
    if not equipment_data:
        print("\n⚠️  No equipment data found in PDF")
        sys.exit(1)
    
    insert_into_database(equipment_data)
    verify_data()
    
    print("\n✅ Process completed successfully!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()