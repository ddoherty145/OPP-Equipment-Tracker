# Equipment Tracker Smoke Test Checklist

## Startup and Navigation
- Launch app cold start on Android and iOS.
- Verify `Equipment`, `Logs`, and `Analytics` tabs render and switch.
- Use refresh action and confirm loading overlay appears and clears.

## Data Persistence
- Add a new equipment entry and confirm it appears in the list.
- Add a usage log for that equipment and confirm it appears in `Logs`.
- Restart app and verify the equipment and usage log persist.

## Validation and UX States
- Try saving equipment with blank code/name and confirm validation errors.
- Try saving usage log with negative hours/cost/revenue and confirm validation errors.
- Verify empty state text appears when there are no user-created records after clearing filters.

## Analytics and Filters
- Open `Analytics` tab and verify KPI cards show non-zero values from demo/entered data.
- Set equipment and date-range filters and verify KPIs and chart update deterministically.
- Clear filters and verify summary returns to unfiltered totals.

## Export and Share
- Generate Excel export from `Analytics`; confirm share sheet opens.
- Generate PDF export from `Analytics`; confirm share sheet opens.
- Cross-check exported totals against on-screen summary values.
