from __future__ import annotations

import io
import re
from datetime import date, datetime
from typing import Any, Dict, Iterable, List, Optional

import openpyxl
import pdfplumber


EquipmentPayload = Dict[str, Any]


def parse_equipment_pdf_bytes(raw_bytes: bytes) -> List[EquipmentPayload]:
    """
    Parse equipment usage PDF bytes into structured equipment payloads.
    """
    extracted_data: List[EquipmentPayload] = []

    eq_header_pattern = re.compile(r"Equipment:\s+([\w\d-]+)\s+-\s+(.+)")
    data_row_pattern = re.compile(
        r"(\d{1,2}/\d{1,2}/\d{4})"
        r".*?"
        r"(\d+\.\d{2})"
        r".*?"
        r"([\d,]+\.\d{2})"
        r".*?"
        r"([\d,]+\.\d{2})"
    )

    current_equipment: Optional[EquipmentPayload] = None

    with pdfplumber.open(io.BytesIO(raw_bytes)) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if not text:
                continue

            for line in text.split("\n"):
                eq_match = eq_header_pattern.search(line)
                if eq_match:
                    current_equipment = {
                        "equipment_id": eq_match.group(1).strip(),
                        "name": eq_match.group(2).strip(),
                        "usage_logs": [],
                    }
                    extracted_data.append(current_equipment)
                    continue

                row_match = data_row_pattern.search(line)
                if row_match and current_equipment:
                    hours = float(row_match.group(2).replace(",", ""))
                    cost = float(row_match.group(3).replace(",", ""))
                    revenue = float(row_match.group(4).replace(",", ""))

                    current_equipment["usage_logs"].append(
                        {
                            "date": row_match.group(1),
                            "hours": hours,
                            "cost": cost,
                            "revenue": revenue,
                            "profit": revenue - cost,
                        }
                    )

    return extracted_data


def parse_equipment_excel_bytes(raw_bytes: bytes) -> List[EquipmentPayload]:
    """
    Parse XLSX file bytes into structured equipment payloads.
    Expected columns (case-insensitive aliases):
      - equipment_id (or equipment, equipment code)
      - name (optional, defaults to equipment_id)
      - acquisition_date (optional, used for age reports)
      - date
      - hours
      - cost
      - revenue
    """
    workbook = openpyxl.load_workbook(io.BytesIO(raw_bytes), data_only=True)
    aggregated: Dict[str, EquipmentPayload] = {}

    for sheet in workbook.worksheets:
        rows = list(sheet.iter_rows(values_only=True))
        if not rows:
            continue

        header_index, column_map = _find_header_map(rows)
        if header_index is None or column_map is None:
            continue

        for row in rows[header_index + 1 :]:
            if row is None:
                continue

            equipment_code = _cell_to_str(row[column_map["equipment_id"]])
            if not equipment_code:
                continue

            equipment_name = _cell_to_str(row[column_map["name"]]) or equipment_code
            parsed_acquisition_date = None
            if "acquisition_date" in column_map:
                parsed_acquisition_date = _parse_date_cell(row[column_map["acquisition_date"]])
            parsed_date = _parse_date_cell(row[column_map["date"]])
            hours = _parse_float(row[column_map["hours"]])
            cost = _parse_float(row[column_map["cost"]])
            revenue = _parse_float(row[column_map["revenue"]])

            if parsed_date is None or hours is None or cost is None or revenue is None:
                continue

            payload = aggregated.get(equipment_code)
            if payload is None:
                payload = {
                    "equipment_id": equipment_code,
                    "name": equipment_name,
                    "acquisition_date": (
                        parsed_acquisition_date.isoformat() if parsed_acquisition_date else None
                    ),
                    "usage_logs": [],
                }
                aggregated[equipment_code] = payload
            elif parsed_acquisition_date and not payload.get("acquisition_date"):
                payload["acquisition_date"] = parsed_acquisition_date.isoformat()

            payload["usage_logs"].append(
                {
                    "date": parsed_date.strftime("%m/%d/%Y"),
                    "hours": hours,
                    "cost": cost,
                    "revenue": revenue,
                    "profit": revenue - cost,
                }
            )

    return list(aggregated.values())


def _find_header_map(
    rows: List[Iterable[Any]],
) -> tuple[Optional[int], Optional[Dict[str, int]]]:
    required_aliases = {
        "equipment_id": {"equipment_id", "equipmentid", "equipment", "equipmentcode", "assetid"},
        "name": {"name", "equipmentname", "assetname"},
        "acquisition_date": {"acquisitiondate", "purchasedate", "purchasedon"},
        "date": {"date", "usagedate", "workdate"},
        "hours": {"hours", "hoursused", "totalhours"},
        "cost": {"cost", "totalcost"},
        "revenue": {"revenue", "totalrevenue"},
    }

    for idx, row in enumerate(rows[:20]):
        normalized = {
            _normalize_header(value): col_idx
            for col_idx, value in enumerate(row)
            if value is not None and _normalize_header(value)
        }

        resolved: Dict[str, int] = {}
        for key, aliases in required_aliases.items():
            match = next((normalized[h] for h in aliases if h in normalized), None)
            if match is not None:
                resolved[key] = match

        if all(k in resolved for k in ("equipment_id", "date", "hours", "cost", "revenue")):
            if "name" not in resolved:
                # fall back to equipment id when name column is absent
                resolved["name"] = resolved["equipment_id"]
            return idx, resolved

    return None, None


def _normalize_header(value: Any) -> str:
    if value is None:
        return ""
    return re.sub(r"[^a-z0-9]", "", str(value).strip().lower())


def _cell_to_str(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _parse_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (float, int)):
        return float(value)

    raw = str(value).strip().replace(",", "")
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _parse_date_cell(value: Any) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value

    raw = str(value).strip()
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%m-%d-%Y", "%m/%d/%y"):
        try:
            return datetime.strptime(raw, fmt).date()
        except ValueError:
            continue
    return None
