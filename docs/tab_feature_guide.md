# Equipment Tracker Tab Guide

This guide explains each app tab, what it is for, and how to use it.

## Equipment Tab

Purpose:
- Manage equipment line items (each piece of equipment).
- Review basic totals per equipment.

How to use:
- Click `Add` to create a new equipment item.
- Use `Edit` / `Delete` from the row menu.
- Use `Sync Imports` to pull imported backend data into local app data.

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
- Use `Sync Imports` to refresh local logs from imported backend data.

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

What you see:
- Last import result (equipment processed, logs inserted/skipped).
- Backend analytics snapshot after upload.
- Auto-sync status message when enabled.

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
  - `$ / hr delta`
  - `% margin`
- Click `Generate & Share`.

## Recommended User Flow

1. Upload source files in `Import`.
2. Let auto-sync populate app tabs.
3. Review/adjust data in `Equipment` and `Logs`.
4. Validate trends in `Analytics`.
5. Generate deliverables from `Reports`.
