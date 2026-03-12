# Equipment Tracker Tab Guide

This guide explains each app tab, what it is for, and how to use it.

## Navigation Summary

Main tabs in the app:
- Equipment
- Logs
- Analytics
- Import
- Reports

## Equipment Tab

Purpose:
- Manage equipment line items (each piece of equipment).
- Review basic totals per equipment.

How to use:
- Click `Add` to create a new equipment item.
- Use `Edit` / `Delete` from the row menu.
- Use `Sync Imports` to pull imported backend data into tab data.

What you see:
- Equipment code (unique identifier), name, total hours, and total profit.

## Logs Tab

Purpose:
- View and manage usage log entries for equipment.
- Filter and inspect operational data over time.

How to use:
- Click `Add Log` to create a usage entry.
- Use `Edit` / `Delete` from each row menu.
- Filter by equipment and date range.
- Use `Clear Filters` to reset.
- Use `Sync Imports` to refresh logs from imported backend data.

What you see:
- Date, hours, cost, revenue, and profit per entry.

## Analytics Tab

Purpose:
- Analyze performance metrics and trends.
- Export analytics snapshots.

How to use:
- Apply equipment/date filters to focus analysis.
- Review KPI cards (Revenue, Profit, Hours, Margin).
- Review the hours trend chart.
- Export with `Export Excel` or `Export PDF`.
- Use `Sync Imports` to refresh analytics source data from backend imports.

What you see:
- Aggregated totals and trend visualization based on current filters.

## Import Tab

Purpose:
- Upload source files (PDF/Excel) to backend parser/import endpoints.

How to use:
- Set `API Base URL` (for emulator use `http://10.0.2.2:8000`).
- Upload with `Import PDF` or `Import Excel`.
- Keep `Auto-sync other tabs after import` enabled for seamless workflow.
- If auto-sync is off, use `Sync Imports` in Equipment/Logs/Analytics tabs manually.

What you see:
- Last import result (equipment processed, logs inserted/skipped).
- Backend analytics snapshot after upload.
- Auto-sync status message when enabled.

Notes:
- On web (Chrome/Edge), auto-sync updates an in-memory tab dataset from backend data.
- On desktop/mobile, auto-sync updates local SQLite-backed tab data.

## Reports Tab

Purpose:
- Generate preset business reports in Excel or PDF.

Available report types:
- All Equipment Dump
- Age Report (uses acquisition date)
- Profit Margin Report
- Utilization Report
- Cost Report

How to use:
- Choose report type.
- Optionally enter `Equipment ID` for single line-item reporting; leave blank for bulk.
- Choose output format (`Excel` or `PDF`).
- For Profit Margin Report, choose metric mode:
  - `$ / hr delta` = `(revenue/hour) - (cost/hour)`
  - `% margin` = `((revenue - cost) / revenue) * 100`
- Click `Generate & Share`.

## Recommended User Flow

1. Upload source files in `Import`.
2. Let auto-sync populate tabs (or run manual sync from Equipment/Logs/Analytics).
3. Review and adjust data in `Equipment` and `Logs`.
4. Validate totals and trends in `Analytics`.
5. Generate business deliverables from `Reports`.
