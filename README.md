# Equipment Tracker - Full Stack

Internal equipment utilization tracking system for portfolio companies.

## Architecture

- **Backend**: Docker (PostgreSQL + FastAPI)
- **Mobile**: Flutter (iOS + Android)
- **Data Pipeline**: Python PDF parser

## Quick Start

### Backend Setup
```bash
docker-compose up -d
python parse_equipment.py "report.pdf"
```

### Mobile App Setup
```bash
cd mobile/equipment_tracker_app
flutter pub get
flutter run
```

## Repository Structure
- `/api` - FastAPI backend
- `/mobile/equipment_tracker_app` - Flutter mobile app
- `/parse_equipment.py` - PDF data ingestion script
- `/docker-compose.yml` - Infrastructure setup
