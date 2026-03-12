from __future__ import annotations

import io
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Dict, List, Literal, Optional, Sequence

from openpyxl import Workbook
from psycopg.rows import dict_row
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Spacer, Table, TableStyle, Paragraph
from reportlab.lib.styles import getSampleStyleSheet

ReportName = Literal["all_equipment", "age", "profit_margin", "utilization", "cost"]
ReportFormat = Literal["xlsx", "pdf"]
ProfitMode = Literal["per_hour_delta", "percent_margin"]


@dataclass(frozen=True)
class RenderedReport:
    filename: str
    content_type: str
    content: bytes


def ensure_reporting_schema(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            ALTER TABLE equipment
            ADD COLUMN IF NOT EXISTS acquisition_date DATE
            """
        )
    conn.commit()


def fetch_report_rows(
    conn,
    report_name: ReportName,
    equipment_code: Optional[str],
    profit_mode: ProfitMode,
) -> List[Dict[str, Any]]:
    if report_name == "all_equipment":
        return _fetch_all_equipment_dump(conn, equipment_code)
    if report_name == "age":
        return _fetch_age_rows(conn, equipment_code)
    if report_name == "profit_margin":
        return _fetch_profit_rows(conn, equipment_code, profit_mode)
    if report_name == "utilization":
        return _fetch_utilization_rows(conn, equipment_code)
    if report_name == "cost":
        return _fetch_cost_rows(conn, equipment_code)

    raise ValueError(f"Unsupported report: {report_name}")


def render_report(
    report_name: ReportName,
    rows: Sequence[Dict[str, Any]],
    output_format: ReportFormat,
    profit_mode: ProfitMode,
    equipment_code: Optional[str],
) -> RenderedReport:
    suffix = equipment_code or "all"
    metric_suffix = f"_{profit_mode}" if report_name == "profit_margin" else ""
    filename = f"{report_name}{metric_suffix}_{suffix}.{output_format}"

    if output_format == "xlsx":
        payload = _render_excel(rows, report_name, profit_mode)
        return RenderedReport(
            filename=filename,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            content=payload,
        )

    payload = _render_pdf(rows, report_name, profit_mode)
    return RenderedReport(
        filename=filename,
        content_type="application/pdf",
        content=payload,
    )


def _fetch_all_equipment_dump(conn, equipment_code: Optional[str]) -> List[Dict[str, Any]]:
    clause = ""
    args: List[Any] = []
    if equipment_code:
        clause = "WHERE e.equipment_id = %s"
        args.append(equipment_code)

    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"""
            SELECT
              e.equipment_id,
              e.name,
              e.acquisition_date,
              ul.date AS usage_date,
              ul.hours,
              ul.cost,
              ul.revenue,
              ul.profit
            FROM equipment e
            LEFT JOIN usage_logs ul ON ul.equipment_id = e.id
            {clause}
            ORDER BY e.equipment_id, ul.date
            """,
            args,
        )
        return list(cur.fetchall())


def _fetch_age_rows(conn, equipment_code: Optional[str]) -> List[Dict[str, Any]]:
    clause = ""
    args: List[Any] = []
    if equipment_code:
        clause = "WHERE e.equipment_id = %s"
        args.append(equipment_code)

    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"""
            SELECT
              e.equipment_id,
              e.name,
              e.acquisition_date,
              CASE
                WHEN e.acquisition_date IS NULL THEN NULL
                ELSE (CURRENT_DATE - e.acquisition_date)
              END AS age_days,
              CASE
                WHEN e.acquisition_date IS NULL THEN NULL
                ELSE ROUND(((CURRENT_DATE - e.acquisition_date) / 365.25)::numeric, 2)
              END AS age_years
            FROM equipment e
            {clause}
            ORDER BY e.equipment_id
            """,
            args,
        )
        return list(cur.fetchall())


def _fetch_profit_rows(
    conn,
    equipment_code: Optional[str],
    profit_mode: ProfitMode,
) -> List[Dict[str, Any]]:
    clause = ""
    args: List[Any] = []
    if equipment_code:
        clause = "WHERE e.equipment_id = %s"
        args.append(equipment_code)

    metric_sql = (
        "CASE WHEN COALESCE(SUM(ul.hours),0) = 0 THEN 0 "
        "ELSE ROUND(((SUM(ul.revenue)/SUM(ul.hours)) - (SUM(ul.cost)/SUM(ul.hours)))::numeric, 2) END"
        if profit_mode == "per_hour_delta"
        else "CASE WHEN COALESCE(SUM(ul.revenue),0) = 0 THEN 0 "
        "ELSE ROUND((((SUM(ul.revenue)-SUM(ul.cost))/SUM(ul.revenue))*100)::numeric, 2) END"
    )
    metric_name = "profit_per_hour_delta" if profit_mode == "per_hour_delta" else "profit_margin_percent"

    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"""
            SELECT
              e.equipment_id,
              e.name,
              COALESCE(SUM(ul.hours), 0) AS total_hours,
              COALESCE(SUM(ul.cost), 0) AS total_cost,
              COALESCE(SUM(ul.revenue), 0) AS total_revenue,
              CASE WHEN COALESCE(SUM(ul.hours),0) = 0 THEN 0 ELSE ROUND((SUM(ul.cost)/SUM(ul.hours))::numeric, 2) END AS cost_per_hour,
              CASE WHEN COALESCE(SUM(ul.hours),0) = 0 THEN 0 ELSE ROUND((SUM(ul.revenue)/SUM(ul.hours))::numeric, 2) END AS revenue_per_hour,
              {metric_sql} AS {metric_name}
            FROM equipment e
            LEFT JOIN usage_logs ul ON ul.equipment_id = e.id
            {clause}
            GROUP BY e.id, e.equipment_id, e.name
            ORDER BY e.equipment_id
            """,
            args,
        )
        return list(cur.fetchall())


def _fetch_utilization_rows(conn, equipment_code: Optional[str]) -> List[Dict[str, Any]]:
    clause = ""
    args: List[Any] = []
    if equipment_code:
        clause = "WHERE e.equipment_id = %s"
        args.append(equipment_code)

    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"""
            SELECT
              e.equipment_id,
              e.name,
              COALESCE(SUM(ul.hours), 0) AS hours_used
            FROM equipment e
            LEFT JOIN usage_logs ul ON ul.equipment_id = e.id
            {clause}
            GROUP BY e.id, e.equipment_id, e.name
            ORDER BY e.equipment_id
            """,
            args,
        )
        return list(cur.fetchall())


def _fetch_cost_rows(conn, equipment_code: Optional[str]) -> List[Dict[str, Any]]:
    clause = ""
    args: List[Any] = []
    if equipment_code:
        clause = "WHERE e.equipment_id = %s"
        args.append(equipment_code)

    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            f"""
            SELECT
              e.equipment_id,
              e.name,
              COALESCE(SUM(ul.hours), 0) AS total_hours,
              COALESCE(SUM(ul.cost), 0) AS total_cost,
              CASE WHEN COALESCE(SUM(ul.hours),0) = 0 THEN 0 ELSE ROUND((SUM(ul.cost)/SUM(ul.hours))::numeric, 2) END AS cost_per_hour
            FROM equipment e
            LEFT JOIN usage_logs ul ON ul.equipment_id = e.id
            {clause}
            GROUP BY e.id, e.equipment_id, e.name
            ORDER BY e.equipment_id
            """,
            args,
        )
        return list(cur.fetchall())


def _render_excel(
    rows: Sequence[Dict[str, Any]],
    report_name: ReportName,
    profit_mode: ProfitMode,
) -> bytes:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = report_name.replace("_", " ").title()

    metric_label = (
        "profit_per_hour_delta"
        if profit_mode == "per_hour_delta"
        else "profit_margin_percent"
    )

    if not rows:
        sheet.append(["message"])
        sheet.append(["No rows available for selected filters"])
    else:
        headers = list(rows[0].keys())
        headers = [metric_label if h == metric_label else h for h in headers]
        sheet.append(headers)
        for row in rows:
            sheet.append([_stringify_cell(row.get(column)) for column in rows[0].keys()])

    buf = io.BytesIO()
    workbook.save(buf)
    return buf.getvalue()


def _render_pdf(
    rows: Sequence[Dict[str, Any]],
    report_name: ReportName,
    profit_mode: ProfitMode,
) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=landscape(letter),
        leftMargin=0.4 * inch,
        rightMargin=0.4 * inch,
        topMargin=0.4 * inch,
        bottomMargin=0.4 * inch,
    )

    styles = getSampleStyleSheet()
    story = [
        Paragraph(report_name.replace("_", " ").title(), styles["Heading2"]),
        Paragraph(f"Generated: {date.today().isoformat()}", styles["Normal"]),
        Spacer(1, 0.15 * inch),
    ]

    if not rows:
        story.append(Paragraph("No rows available for selected filters.", styles["Normal"]))
    else:
        headers = list(rows[0].keys())
        if report_name == "profit_margin":
            headers = [
                "profit_per_hour_delta" if h == "profit_per_hour_delta" and profit_mode == "per_hour_delta" else
                "profit_margin_percent" if h == "profit_margin_percent" and profit_mode == "percent_margin" else h
                for h in headers
            ]

        table_data = [headers]
        for row in rows:
            table_data.append([_stringify_cell(row.get(key)) for key in rows[0].keys()])

        table = Table(table_data, repeatRows=1)
        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.lightgrey),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.black),
                    ("GRID", (0, 0), (-1, -1), 0.25, colors.grey),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, -1), 8),
                    ("ALIGN", (0, 0), (-1, -1), "LEFT"),
                ]
            )
        )
        story.append(table)

    doc.build(story)
    return buffer.getvalue()


def _stringify_cell(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return value
