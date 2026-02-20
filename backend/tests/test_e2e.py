"""
Backend E2E tests: hit real FastAPI app and MongoDB (test DB).
Uses async client so Motor runs in the same event loop (avoids "Event loop is closed").
Run from repo root: pytest backend/tests/ -v
Or from backend: pytest tests/ -v
"""
import sys
from pathlib import Path

_backend = Path(__file__).resolve().parent.parent
if str(_backend) not in sys.path:
    sys.path.insert(0, str(_backend))

import pytest
from httpx import ASGITransport, AsyncClient

from main import app

# Run all tests in this module as async; session-scoped client shares one event loop with Motor
pytestmark = pytest.mark.asyncio


@pytest.fixture(scope="session")
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def test_root(client: AsyncClient):
    r = await client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "success"
    assert "Gym API" in (data.get("message") or "")


async def test_version(client: AsyncClient):
    r = await client.get("/version")
    assert r.status_code == 200
    data = r.json()
    assert "min_app_version" in data
    assert "api_version" in data


async def test_member_crud_and_by_phone(client: AsyncClient):
    payload = {
        "name": "E2E Test User",
        "phone": "9876543210",
        "email": "e2e@example.com",
        "membership_type": "Regular",
        "batch": "Morning",
    }
    r = await client.post("/members", json=payload)
    assert r.status_code == 200, r.text
    created = r.json()
    member_id = created["id"]
    assert created["name"] == payload["name"]
    assert created["phone"] == payload["phone"]
    assert created["email"] == payload["email"]
    assert created["membership_type"] == "Regular"
    assert created["batch"] == "Morning"
    assert created["status"] == "Active"

    r2 = await client.get(f"/members/{member_id}")
    assert r2.status_code == 200
    assert r2.json()["id"] == member_id

    r3 = await client.get("/members/by-phone/9876543210")
    assert r3.status_code == 200
    assert r3.json()["phone"] == "9876543210"

    r4 = await client.get("/members")
    assert r4.status_code == 200
    members = r4.json()
    assert isinstance(members, list)
    assert member_id in [m["id"] for m in members]


async def test_attendance_check_in_check_out(client: AsyncClient):
    payload = {
        "name": "Attendance Test",
        "phone": "9876543211",
        "email": "att@example.com",
        "membership_type": "Regular",
        "batch": "Evening",
    }
    r = await client.post("/members", json=payload)
    assert r.status_code == 200, r.text
    member_id = r.json()["id"]

    r_in = await client.post(f"/attendance/check-in/{member_id}")
    assert r_in.status_code == 200, r_in.text
    check_in_data = r_in.json()
    assert check_in_data["member_id"] == member_id
    assert check_in_data["date_ist"]
    assert check_in_data["batch"]
    assert check_in_data["check_in_at"]
    assert check_in_data["check_out_at"] is None

    r_dup = await client.post(f"/attendance/check-in/{member_id}")
    assert r_dup.status_code == 400

    r_today = await client.get("/attendance/today")
    assert r_today.status_code == 200
    today_list = r_today.json()
    assert isinstance(today_list, list)
    assert any(e["member_id"] == member_id for e in today_list)

    r_out = await client.post(f"/attendance/check-out/{member_id}")
    assert r_out.status_code == 200, r_out.text
    assert r_out.json()["check_out_at"] is not None


async def test_payments_and_log_monthly(client: AsyncClient):
    payload = {
        "name": "Payment Test",
        "phone": "9876543212",
        "email": "pay@example.com",
        "membership_type": "Regular",
        "batch": "Morning",
    }
    r = await client.post("/members", json=payload)
    assert r.status_code == 200, r.text
    member_id = r.json()["id"]

    r_list = await client.get("/payments", params={"member_id": member_id})
    assert r_list.status_code == 200
    payments = r_list.json()
    assert isinstance(payments, list)
    assert len(payments) >= 2

    from datetime import date
    period = date.today().strftime("%Y-%m")
    r_log = await client.post(
        "/payments/log-monthly",
        json={"member_id": member_id, "period": period, "amount": 500},
    )
    assert r_log.status_code == 200, r_log.text
    log_data = r_log.json()
    assert log_data["status"] == "Paid"
    assert log_data["amount"] == 500
    assert log_data["period"] == period

    r_sum = await client.get("/payments/fees-summary")
    assert r_sum.status_code == 200


async def test_billing_issue_and_history_and_pay(client: AsyncClient):
    payload = {
        "name": "Billing Walk-in",
        "phone": "9876543213",
        "email": "bill@example.com",
        "membership_type": "Regular",
        "batch": "Ladies",
    }
    r_issue = await client.post("/billing/issue", json=payload)
    assert r_issue.status_code == 200, r_issue.text
    inv = r_issue.json()
    invoice_id = inv["id"]
    member_id = inv["member_id"]
    assert inv["status"] == "Unpaid"
    assert inv["total"] == 1500
    assert len(inv["items"]) >= 2

    r_hist = await client.get("/billing/history", params={"member_id": member_id})
    assert r_hist.status_code == 200
    history = r_hist.json()
    assert isinstance(history, list)
    assert any(h["id"] == invoice_id for h in history)

    r_pay = await client.post("/billing/pay", params={"invoice_id": invoice_id})
    assert r_pay.status_code == 200, r_pay.text
    paid_inv = r_pay.json()
    assert paid_inv["status"] == "Paid"
    assert paid_inv["paid_at"] is not None


async def test_analytics_dashboard(client: AsyncClient):
    r = await client.get("/analytics/dashboard")
    assert r.status_code == 200, r.text
    data = r.json()
    assert "active_members" in data
    assert "inactive_members" in data
    assert "total_collections" in data
    assert "pending_fees_amount" in data
    assert "today_attendance_count" in data


async def test_export_endpoints(client: AsyncClient):
    r_billing = await client.get("/export/billing")
    assert r_billing.status_code == 200
    assert "application" in r_billing.headers.get("content-type", "")

    r_members = await client.get("/export/members")
    assert r_members.status_code == 200

    r_payments = await client.get("/export/payments")
    assert r_payments.status_code == 200


async def test_get_member_404(client: AsyncClient):
    r = await client.get("/members/000000000000000000000000")
    assert r.status_code == 404


async def test_get_member_invalid_id(client: AsyncClient):
    r = await client.get("/members/not-an-object-id")
    assert r.status_code == 400
