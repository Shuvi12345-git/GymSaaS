from contextlib import asynccontextmanager
from datetime import datetime, date, timedelta
from enum import Enum
from io import BytesIO
from zoneinfo import ZoneInfo

from fastapi import BackgroundTasks, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, EmailStr, Field, field_serializer

# MongoDB connection
MONGODB_URL = "mongodb+srv://gym_admin:8qxXOYKp1El0bw0B@clustergymadmin.zkcgd9b.mongodb.net/?appName=Clustergymadmin"
DATABASE_NAME = "gym_db"
COLLECTION_MEMBERS = "gym_members"
COLLECTION_ATTENDANCE = "attendance_logs"
COLLECTION_PAYMENTS = "payments"

# Fee model: ₹1000 registration + Monthly (₹500 Regular / ₹2000 PT)
REGISTRATION_FEE = 1000
MONTHLY_FEE_REGULAR = 500
MONTHLY_FEE_PT = 2000

IST = ZoneInfo("Asia/Kolkata")

client = AsyncIOMotorClient(MONGODB_URL)
db = client[DATABASE_NAME]
members_collection = db[COLLECTION_MEMBERS]
attendance_collection = db[COLLECTION_ATTENDANCE]
payments_collection = db[COLLECTION_PAYMENTS]


def now_ist() -> datetime:
    """Current datetime in IST."""
    return datetime.now(IST)


def today_ist() -> date:
    """Current date in IST."""
    return now_ist().date()


def batch_from_ist(dt: datetime) -> str:
    """Return Morning, Evening, or Ladies based on IST hour. Morning 4-11, Evening 12-16, Ladies 17-23, else Evening."""
    h = dt.hour
    if 4 <= h <= 11:
        return "Morning"
    if 17 <= h <= 23:
        return "Ladies"
    return "Evening"  # 0-3, 12-16


@asynccontextmanager
async def lifespan(app: FastAPI):
    """On startup: run 90-day attendance auto-cancellation."""
    from datetime import timezone
    today = today_ist()
    cutoff = today - timedelta(days=90)
    cutoff_dt = datetime(cutoff.year, cutoff.month, cutoff.day, tzinfo=timezone.utc)
    await members_collection.update_many(
        {"last_attendance_date": {"$exists": True, "$lt": cutoff_dt}},
        {"$set": {"status": "Inactive"}},
    )
    yield
    # shutdown if needed
    pass


app = FastAPI(title="Gym API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local dev (Flutter web uses varying ports)
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MembershipType(str, Enum):
    regular = "Regular"
    pt = "PT"


class Batch(str, Enum):
    morning = "Morning"
    evening = "Evening"
    ladies = "Ladies"


class MemberCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    phone: str = Field(..., min_length=1, max_length=20)
    email: EmailStr
    membership_type: MembershipType
    batch: Batch
    status: str = Field(default="Active", max_length=50)


class MemberResponse(BaseModel):
    id: str
    name: str
    phone: str
    email: str
    membership_type: str
    batch: str
    status: str
    created_at: datetime
    last_attendance_date: date | None = None
    workout_schedule: str | None = None
    diet_chart: str | None = None


class MemberPTUpdate(BaseModel):
    workout_schedule: str | None = None
    diet_chart: str | None = None


class PaymentResponse(BaseModel):
    id: str
    member_id: str
    member_name: str
    amount: int
    fee_type: str  # registration | monthly
    period: str | None = None  # e.g. "2025-02" for monthly
    status: str  # Paid | Due | Overdue
    due_date: date | None = None
    paid_at: datetime | None = None
    created_at: datetime


class AttendanceRecord(BaseModel):
    id: str
    member_id: str
    member_name: str
    check_in_at: datetime  # IST, for display
    date_ist: str
    batch: str

    @field_serializer("check_in_at")
    def serialize_check_in_at(self, dt: datetime) -> str:
        return dt.isoformat()


# ---------- Notifications (simulated WhatsApp/Email) ----------
def notify_registration(name: str, email: str, phone: str):
    """Simulated: send welcome/registration notification."""
    pass  # In production: WhatsApp/Email API

def notify_payment_received(name: str, amount: int, email: str, phone: str):
    """Simulated: send payment received notification."""
    pass

def notify_status_change(name: str, new_status: str, email: str, phone: str):
    """Simulated: send membership status change notification."""
    pass


@app.get("/")
def root():
    return {"status": "success", "message": "Gym API is Live!"}


@app.post("/members", response_model=MemberResponse)
async def create_member(member: MemberCreate):
    from datetime import timezone
    doc = member.model_dump()
    doc["created_at"] = datetime.now(timezone.utc)
    mt = doc["membership_type"].value if isinstance(doc["membership_type"], MembershipType) else doc["membership_type"]
    doc["workout_schedule"] = doc.get("workout_schedule")
    doc["diet_chart"] = doc.get("diet_chart")
    result = await members_collection.insert_one(doc)
    mid = str(result.inserted_id)
    doc["_id"] = result.inserted_id

    # Create registration fee (Due) and first monthly fee (Due)
    today = today_ist()
    due_dt = datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
    monthly_amount = MONTHLY_FEE_PT if mt == "PT" else MONTHLY_FEE_REGULAR
    period = today.strftime("%Y-%m")
    await payments_collection.insert_many([
        {"member_id": mid, "member_name": doc["name"], "amount": REGISTRATION_FEE, "fee_type": "registration", "period": None, "status": "Due", "due_date": due_dt, "paid_at": None, "created_at": datetime.now(timezone.utc)},
        {"member_id": mid, "member_name": doc["name"], "amount": monthly_amount, "fee_type": "monthly", "period": period, "status": "Due", "due_date": due_dt, "paid_at": None, "created_at": datetime.now(timezone.utc)},
    ])
    notify_registration(doc["name"], doc["email"], doc["phone"])

    return MemberResponse(
        id=mid,
        name=doc["name"],
        phone=doc["phone"],
        email=doc["email"],
        membership_type=mt,
        batch=doc["batch"].value if isinstance(doc["batch"], Batch) else doc["batch"],
        status=doc["status"],
        created_at=doc["created_at"],
        last_attendance_date=doc.get("last_attendance_date"),
        workout_schedule=doc.get("workout_schedule"),
        diet_chart=doc.get("diet_chart"),
    )


@app.get("/members/by-phone/{phone}", response_model=MemberResponse)
async def get_member_by_phone(phone: str):
    """For member login: lookup by phone."""
    doc = await members_collection.find_one({"phone": phone})
    if not doc:
        raise HTTPException(status_code=404, detail="Member not found")
    return _doc_to_member_response(doc)


@app.get("/members", response_model=list[MemberResponse])
async def list_members():
    cursor = members_collection.find().sort("created_at", -1)
    members = []
    async for doc in cursor:
        members.append(
            MemberResponse(
                id=str(doc["_id"]),
                name=doc["name"],
                phone=doc["phone"],
                email=doc["email"],
                membership_type=doc["membership_type"] if isinstance(doc["membership_type"], str) else doc["membership_type"].value,
                batch=doc["batch"] if isinstance(doc["batch"], str) else doc["batch"].value,
                status=doc.get("status", "Active"),
                created_at=doc["created_at"],
                last_attendance_date=_to_date(doc.get("last_attendance_date")),
                workout_schedule=doc.get("workout_schedule"),
                diet_chart=doc.get("diet_chart"),
            )
        )
    return members


@app.patch("/members/{member_id}", response_model=MemberResponse)
async def update_member_pt(member_id: str, body: MemberPTUpdate):
    """Admin: update PT member's workout schedule and/or diet chart."""
    from bson import ObjectId
    try:
        oid = ObjectId(member_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid member ID")
    update = {}
    if body.workout_schedule is not None:
        update["workout_schedule"] = body.workout_schedule
    if body.diet_chart is not None:
        update["diet_chart"] = body.diet_chart
    if not update:
        result = await members_collection.find_one({"_id": oid})
        if not result:
            raise HTTPException(status_code=404, detail="Member not found")
        return _doc_to_member_response(result)
    result = await members_collection.find_one_and_update(
        {"_id": oid},
        {"$set": update},
        return_document=True,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Member not found")
    return _doc_to_member_response(result)


def _doc_to_member_response(doc) -> MemberResponse:
    return MemberResponse(
        id=str(doc["_id"]),
        name=doc["name"],
        phone=doc["phone"],
        email=doc["email"],
        membership_type=doc["membership_type"] if isinstance(doc["membership_type"], str) else doc["membership_type"].value,
        batch=doc["batch"] if isinstance(doc["batch"], str) else doc["batch"].value,
        status=doc.get("status", "Active"),
        created_at=doc["created_at"],
        last_attendance_date=_to_date(doc.get("last_attendance_date")),
        workout_schedule=doc.get("workout_schedule"),
        diet_chart=doc.get("diet_chart"),
    )


def _to_date(v):
    """Convert datetime to date for API; leave date as is."""
    if v is None:
        return None
    return v.date() if hasattr(v, "date") else v


# ---------- Attendance ----------

CHECK_IN_COOLDOWN_HOURS = 4


@app.post("/attendance/check-in/{member_id}", response_model=AttendanceRecord)
async def check_in(member_id: str):
    """Record check-in in IST. Prevents duplicate check-in within 4 hours."""
    from bson import ObjectId
    from datetime import timezone

    try:
        try:
            oid = ObjectId(member_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid member ID")

        member = await members_collection.find_one({"_id": oid})
        if not member:
            raise HTTPException(status_code=404, detail="Member not found")

        now = now_ist()
        date_ist_str = now.strftime("%Y-%m-%d")
        batch = batch_from_ist(now)

        cutoff = now - timedelta(hours=CHECK_IN_COOLDOWN_HOURS)
        cutoff_utc = cutoff.astimezone(timezone.utc)
        recent = await attendance_collection.find_one(
            {"member_id": member_id, "check_in_at_utc": {"$gte": cutoff_utc}},
            sort=[("check_in_at_utc", -1)],
        )
        if recent:
            raise HTTPException(
                status_code=400,
                detail=f"Already checked in within the last {CHECK_IN_COOLDOWN_HOURS} hours. Try again later.",
            )

        check_in_at_utc = now.astimezone(timezone.utc)
        doc = {
            "member_id": member_id,
            "check_in_at_utc": check_in_at_utc,
            "check_in_at_ist": now.isoformat(),
            "date_ist": date_ist_str,
            "batch": batch,
            "member_name": member.get("name", ""),
        }
        result = await attendance_collection.insert_one(doc)
        # Store as datetime at midnight UTC so MongoDB (BSON) can encode it
        today_date = now.date()
        last_attendance_dt = datetime(today_date.year, today_date.month, today_date.day, tzinfo=timezone.utc)
        await members_collection.update_one(
            {"_id": oid},
            {"$set": {"last_attendance_date": last_attendance_dt}},
        )

        return AttendanceRecord(
            id=str(result.inserted_id),
            member_id=member_id,
            member_name=doc["member_name"],
            check_in_at=now,
            date_ist=date_ist_str,
            batch=batch,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error during check-in: {e!s}")


@app.get("/attendance/today", response_model=list[AttendanceRecord])
async def attendance_today():
    """All check-ins for current date in IST, sorted by batch then time."""
    date_ist_str = today_ist().strftime("%Y-%m-%d")
    cursor = attendance_collection.find({"date_ist": date_ist_str}).sort([("batch", 1), ("check_in_at_utc", 1)])
    out = []
    async for doc in cursor:
        check_in_at_ist = (
            datetime.fromisoformat(doc["check_in_at_ist"]) if doc.get("check_in_at_ist") else doc["check_in_at_utc"]
        )
        if check_in_at_ist.tzinfo is None:
            check_in_at_ist = check_in_at_ist.replace(tzinfo=IST)
        else:
            check_in_at_ist = check_in_at_ist.astimezone(IST)
        out.append(
            AttendanceRecord(
                id=str(doc["_id"]),
                member_id=doc["member_id"],
                member_name=doc.get("member_name", ""),
                check_in_at=check_in_at_ist,
                date_ist=doc["date_ist"],
                batch=doc["batch"],
            )
        )
    return out


INACTIVE_DAYS_THRESHOLD = 90


@app.post("/admin/mark-inactive-by-attendance")
async def mark_inactive_by_attendance():
    """
    Only mark Inactive when last_attendance_date exists and is older than 90 days (IST).
    Members who have never checked in (no last_attendance_date) are left unchanged.
    """
    from datetime import timezone

    today = today_ist()
    cutoff = today - timedelta(days=INACTIVE_DAYS_THRESHOLD)
    cutoff_dt = datetime(cutoff.year, cutoff.month, cutoff.day, tzinfo=timezone.utc)
    result = await members_collection.update_many(
        {"last_attendance_date": {"$exists": True, "$lt": cutoff_dt}},
        {"$set": {"status": "Inactive"}},
    )
    return {"updated_count": result.modified_count, "cutoff_date_ist": cutoff.isoformat()}


# ---------- Payments & Fees ----------

@app.get("/payments", response_model=list[PaymentResponse])
async def list_payments(member_id: str | None = None, status: str | None = None):
    """List payments. Filter by member_id and/or status (Paid/Due/Overdue)."""
    from datetime import timezone
    q = {}
    if member_id:
        q["member_id"] = member_id
    if status:
        q["status"] = status
    cursor = payments_collection.find(q).sort("created_at", -1)
    out = []
    async for doc in cursor:
        out.append(PaymentResponse(
            id=str(doc["_id"]),
            member_id=doc["member_id"],
            member_name=doc.get("member_name", ""),
            amount=doc["amount"],
            fee_type=doc["fee_type"],
            period=doc.get("period"),
            status=doc["status"],
            due_date=_to_date(doc.get("due_date")),
            paid_at=doc.get("paid_at"),
            created_at=doc["created_at"],
        ))
    return out


@app.get("/payments/fees-summary")
async def fees_summary():
    """Paid/Due/Overdue counts and total amounts for Fees Management tab."""
    from datetime import timezone
    today = today_ist()
    today_dt = datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
    pipeline = [
        {"$group": {"_id": "$status", "count": {"$sum": 1}, "total_amount": {"$sum": "$amount"}}}
    ]
    cursor = payments_collection.aggregate(pipeline)
    paid = due = overdue = 0
    paid_amt = due_amt = overdue_amt = 0
    async for row in cursor:
        s = row["_id"]
        c, a = row["count"], row["total_amount"]
        if s == "Paid":
            paid, paid_amt = c, a
        elif s == "Due":
            due, due_amt = c, a
        elif s == "Overdue":
            overdue, overdue_amt = c, a
    # Mark Due -> Overdue where due_date < today
    await payments_collection.update_many(
        {"status": "Due", "due_date": {"$lt": today_dt}},
        {"$set": {"status": "Overdue"}},
    )
    # Re-run summary after update
    cursor2 = payments_collection.aggregate(pipeline)
    paid = due = overdue = 0
    paid_amt = due_amt = overdue_amt = 0
    async for row in cursor2:
        s = row["_id"]
        c, a = row["count"], row["total_amount"]
        if s == "Paid":
            paid, paid_amt = c, a
        elif s == "Due":
            due, due_amt = c, a
        elif s == "Overdue":
            overdue, overdue_amt = c, a
    return {
        "paid": {"count": paid, "total_amount": paid_amt},
        "due": {"count": due, "total_amount": due_amt},
        "overdue": {"count": overdue, "total_amount": overdue_amt},
    }


@app.post("/payments/pay", response_model=PaymentResponse)
async def record_payment(member_id: str, payment_id: str, background_tasks: BackgroundTasks):
    """Record a payment (simulated). Sends payment-received notification."""
    from bson import ObjectId
    from datetime import timezone
    try:
        oid = ObjectId(payment_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid payment ID")
    doc = await payments_collection.find_one({"_id": oid, "member_id": member_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Payment not found")
    if doc["status"] == "Paid":
        raise HTTPException(status_code=400, detail="Already paid")
    now = datetime.now(timezone.utc)
    await payments_collection.update_one(
        {"_id": oid},
        {"$set": {"status": "Paid", "paid_at": now}},
    )
    member = await members_collection.find_one({"_id": ObjectId(member_id)})
    if member:
        background_tasks.add_task(notify_payment_received, member.get("name", ""), doc["amount"], member.get("email", ""), member.get("phone", ""))
    updated = await payments_collection.find_one({"_id": oid})
    return PaymentResponse(
        id=str(updated["_id"]),
        member_id=updated["member_id"],
        member_name=updated.get("member_name", ""),
        amount=updated["amount"],
        fee_type=updated["fee_type"],
        period=updated.get("period"),
        status=updated["status"],
        due_date=_to_date(updated.get("due_date")),
        paid_at=updated.get("paid_at"),
        created_at=updated["created_at"],
    )


@app.get("/analytics/dashboard")
async def analytics_dashboard():
    """Total Active/Inactive, Pending Fees, Regular vs PT split."""
    from datetime import timezone
    active = await members_collection.count_documents({"status": "Active"})
    inactive = await members_collection.count_documents({"status": "Inactive"})
    regular = await members_collection.count_documents({"membership_type": "Regular"})
    pt = await members_collection.count_documents({"membership_type": "PT"})
    pipeline = [{"$match": {"status": {"$in": ["Due", "Overdue"]}}}, {"$group": {"_id": None, "total": {"$sum": "$amount"}}}]
    cur = payments_collection.aggregate(pipeline)
    pending_fees = 0
    async for row in cur:
        pending_fees = row["total"]
        break
    return {
        "active_members": active,
        "inactive_members": inactive,
        "regular_count": regular,
        "pt_count": pt,
        "pending_fees_amount": pending_fees,
    }


@app.post("/admin/run-fee-reminders")
async def run_fee_reminders(background_tasks: BackgroundTasks):
    """Trigger fee-due reminders (BackgroundTasks). Simulated WhatsApp/Email."""
    # In production: find Due/Overdue payments, send reminders
    background_tasks.add_task(lambda: None)  # placeholder
    return {"message": "Fee reminders queued."}


@app.post("/admin/seed-inactive-test")
async def seed_inactive_test():
    """
    Creates 2 dummy members with last_attendance_date set to 91 days ago (IST).
    Use this to test the 90-day automation: run this, then run Mark inactive (90d) to see them turn Inactive.
    """
    from datetime import timezone

    today = today_ist()
    old_date = today - timedelta(days=91)
    old_dt = datetime(old_date.year, old_date.month, old_date.day, tzinfo=timezone.utc)

    dummy_members = [
        {
            "name": "Test User (90d ago)",
            "phone": "9999900001",
            "email": "test90d1@example.com",
            "membership_type": "Regular",
            "batch": "Morning",
            "status": "Active",
            "created_at": datetime.now(timezone.utc),
            "last_attendance_date": old_dt,
        },
        {
            "name": "Another Test (90d ago)",
            "phone": "9999900002",
            "email": "test90d2@example.com",
            "membership_type": "PT",
            "batch": "Evening",
            "status": "Active",
            "created_at": datetime.now(timezone.utc),
            "last_attendance_date": old_dt,
        },
    ]
    inserted = []
    for doc in dummy_members:
        result = await members_collection.insert_one(doc)
        inserted.append({"id": str(result.inserted_id), "name": doc["name"]})
    return {"message": "Created 2 test members with last check-in 91 days ago.", "members": inserted}


# ---------- Export to Excel ----------

@app.get("/export/members")
async def export_members_excel():
    """Export members list to Excel."""
    import pandas as pd
    cursor = members_collection.find().sort("created_at", -1)
    rows = []
    async for doc in cursor:
        rows.append({
            "id": str(doc["_id"]),
            "name": doc.get("name", ""),
            "phone": doc.get("phone", ""),
            "email": doc.get("email", ""),
            "membership_type": doc.get("membership_type", ""),
            "batch": doc.get("batch", ""),
            "status": doc.get("status", ""),
            "last_attendance_date": str(_to_date(doc.get("last_attendance_date")) or ""),
        })
    df = pd.DataFrame(rows)
    buf = BytesIO()
    df.to_excel(buf, index=False, engine="openpyxl")
    buf.seek(0)
    return StreamingResponse(buf, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": "attachment; filename=members.xlsx"})


@app.get("/export/payments")
async def export_payments_excel():
    """Export payments list to Excel."""
    import pandas as pd
    cursor = payments_collection.find().sort("created_at", -1)
    rows = []
    async for doc in cursor:
        rows.append({
            "id": str(doc["_id"]),
            "member_id": doc.get("member_id", ""),
            "member_name": doc.get("member_name", ""),
            "amount": doc.get("amount", 0),
            "fee_type": doc.get("fee_type", ""),
            "period": doc.get("period", ""),
            "status": doc.get("status", ""),
            "due_date": str(_to_date(doc.get("due_date")) or ""),
            "paid_at": str(doc.get("paid_at")) if doc.get("paid_at") else "",
        })
    df = pd.DataFrame(rows)
    buf = BytesIO()
    df.to_excel(buf, index=False, engine="openpyxl")
    buf.seek(0)
    return StreamingResponse(buf, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": "attachment; filename=payments.xlsx"})
