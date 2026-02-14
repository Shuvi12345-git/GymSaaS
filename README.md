# GymSaaS

A commercial-grade Gym Management System built with **FastAPI** (Backend) and **Flutter** (Frontend).

## Features

- **Member Management**: Register members, assign batches (Morning/Evening/Ladies), and track status (Active/Inactive).
- **Attendance Tracking**:
  - Daily check-ins via dashboard.
  - Prevents double check-ins within 4 hours.
  - **Automated Inactivity**: Members who haven't checked in for 90 days are automatically marked 'Inactive'.
- **Financial Engine**:
  - Track payments (Registration + Monthly fees).
  - Dashboard overview of Paid, Due, and Overdue fees.
  - Simulated payment gateway integration.
- **Personal Training (PT)**:
  - Admin can assign custom Workout Schedules and Diet Charts.
  - PT members see their personalized plans in the app.
- **Reporting**:
  - Export Member and Payment data to Excel.
  - Daily Attendance Reports.

## Tech Stack

- **Backend**: Python, FastAPI, MongoDB (Motor), Pandas
- **Frontend**: Flutter (Web/Mobile), Google Fonts, Provider pattern
- **Database**: MongoDB Atlas

## How to Run

### 1. Backend

1.  Navigate to the backend folder:
    ```bash
    cd backend
    ```
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  Run the server:
    ```bash
    python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
    ```
    *API will be available at http://localhost:8000*

### 2. Frontend

1.  Navigate to the frontend folder:
    ```bash
    cd frontend
    ```
2.  Install packages:
    ```bash
    flutter pub get
    ```
3.  Run the app (Web):
    ```bash
    flutter run -d chrome
    ```

## Project Structure

- `backend/`: FastAPI application, database logic, and automation scripts.
- `frontend/`: Flutter application code (Screens, Widgets, Models).
