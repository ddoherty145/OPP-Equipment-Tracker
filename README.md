<<<<<<< HEAD
# equipment_tracker_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
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
>>>>>>> f197cb0b02a57c351626adeacb700627b5f61ccd
