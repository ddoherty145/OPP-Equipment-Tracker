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
cd .
flutter pub get
flutter run
```

## Repository Structure
- `/api` - FastAPI backend
- `/lib` - Flutter mobile app source
- `/parse_equipment.py` - PDF data ingestion script
- `/docker-compose.yml` - Infrastructure setup

## App Usage Guide
- See [Tab Feature Guide](docs/tab_feature_guide.md) for a quick walkthrough of each app tab and expected interactions.
