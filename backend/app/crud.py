from datetime import date
from decimal import Decimal
from typing import Optional
from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Product, DailyList, DailyListItem, DebtEmployee, Debt, DebtItem, DebtPayment
from app import schemas


# Products
async def get_products(session: AsyncSession, category: Optional[str] = None):
    stmt = select(Product).order_by(Product.category, Product.name)
    if category:
        stmt = stmt.where(Product.category == category)
    result = await session.execute(stmt)
    return result.scalars().all()


async def get_product(session: AsyncSession, product_id: int):
    return (await session.execute(select(Product).where(Product.id == product_id))).scalar_one_or_none()


async def create_product(session: AsyncSession, product: schemas.ProductCreate):
    db_product = Product(**product.model_dump())
    session.add(db_product)
    await session.commit()
    await session.refresh(db_product)
    return db_product


# Daily Lists
async def get_daily_list(session: AsyncSession, list_id: int):
    stmt = (
        select(DailyList)
        .where(DailyList.id == list_id)
        .options(selectinload(DailyList.items).selectinload(DailyListItem.product))
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def get_daily_list_by_date(session: AsyncSession, list_date: date):
    stmt = (
        select(DailyList)
        .where(DailyList.list_date == list_date)
        .options(selectinload(DailyList.items).selectinload(DailyListItem.product))
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def get_daily_lists(session: AsyncSession, limit: int = 100, offset: int = 0):
    stmt = select(DailyList).order_by(desc(DailyList.list_date)).limit(limit).offset(offset)
    result = await session.execute(stmt)
    return result.scalars().all()


async def create_daily_list(session: AsyncSession, data: schemas.DailyListCreate):
    # Check if date already exists
    existing = await get_daily_list_by_date(session, data.list_date)
    if existing:
        return existing

    db_list = DailyList(list_date=data.list_date, notes=data.notes)
    session.add(db_list)
    await session.flush()

    for item in data.items:
        db_item = DailyListItem(
            daily_list_id=db_list.id,
            product_id=item.product_id,
            hay=item.hay,
            action=item.action,
            quantity_to_bring=item.quantity_to_bring,
        )
        session.add(db_item)

    await session.commit()
    return await get_daily_list(session, db_list.id)


async def update_daily_list(session: AsyncSession, list_id: int, data: schemas.DailyListUpdate):
    db_list = await get_daily_list(session, list_id)
    if not db_list:
        return None

    if data.notes is not None:
        db_list.notes = data.notes

    # Remove existing items and recreate
    for existing in db_list.items:
        await session.delete(existing)
    await session.flush()

    for item in data.items:
        db_item = DailyListItem(
            daily_list_id=db_list.id,
            product_id=item.product_id,
            hay=item.hay,
            action=item.action,
            quantity_to_bring=item.quantity_to_bring,
        )
        session.add(db_item)

    await session.commit()
    return await get_daily_list(session, list_id)


async def delete_daily_list(session: AsyncSession, list_id: int):
    db_list = await get_daily_list(session, list_id)
    if not db_list:
        return False
    await session.delete(db_list)
    await session.commit()
    return True


# --------------------------
# Deudas de empleados
# --------------------------
async def _upsert_debt_employee(session: AsyncSession, data: schemas.DebtCreate) -> DebtEmployee:
    stmt = select(DebtEmployee).where(
        DebtEmployee.odoo_employee_id == data.odoo_employee_id,
        DebtEmployee.company_id == data.company_id,
    )
    employee = (await session.execute(stmt)).scalar_one_or_none()
    if not employee:
        employee = DebtEmployee(
            odoo_employee_id=data.odoo_employee_id,
            company_id=data.company_id,
            company_name=data.company_name,
            name=data.employee_name,
            identification=data.identification,
            job_title=data.job_title,
            active=True,
        )
        session.add(employee)
        await session.flush()
    else:
        employee.company_name = data.company_name or employee.company_name
        employee.name = data.employee_name or employee.name
        employee.identification = data.identification or employee.identification
        employee.job_title = data.job_title or employee.job_title
        employee.active = True
    return employee


async def _compute_debt_items(session: AsyncSession, db_debt: Debt, items: list[schemas.DebtItemCreate]) -> None:
    total = Decimal("0")
    for item in items:
        subtotal = (item.quantity * item.unit_price).quantize(Decimal("0.01"))
        total += subtotal
        session.add(
            DebtItem(
                debt_id=db_debt.id,
                odoo_product_id=item.odoo_product_id,
                product_name=item.product_name,
                product_code=item.product_code,
                unit_price=item.unit_price,
                quantity=item.quantity,
                subtotal=subtotal,
            )
        )
    db_debt.total = total.quantize(Decimal("0.01"))


async def create_debt(session: AsyncSession, data: schemas.DebtCreate) -> Debt:
    employee = await _upsert_debt_employee(session, data)
    db_debt = Debt(
        employee_id=employee.id,
        company_id=data.company_id,
        debt_date=data.debt_date,
        notes=data.notes,
        total=Decimal("0"),
    )
    session.add(db_debt)
    await session.flush()
    await _compute_debt_items(session, db_debt, data.items)
    await session.commit()
    return await get_debt(session, db_debt.id)


async def get_debt(session: AsyncSession, debt_id: int):
    stmt = (
        select(Debt)
        .where(Debt.id == debt_id)
        .options(
            selectinload(Debt.items),
            selectinload(Debt.employee),
        )
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def get_debts(
    session: AsyncSession,
    company_id: Optional[int] = None,
    employee_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    limit: int = 100,
    offset: int = 0,
):
    stmt = select(Debt).options(selectinload(Debt.items), selectinload(Debt.employee))
    if company_id is not None:
        stmt = stmt.where(Debt.company_id == company_id)
    if employee_id is not None:
        stmt = stmt.where(Debt.employee_id == employee_id)
    if from_date is not None:
        stmt = stmt.where(Debt.debt_date >= from_date)
    if to_date is not None:
        stmt = stmt.where(Debt.debt_date <= to_date)
    stmt = stmt.order_by(desc(Debt.debt_date), desc(Debt.id)).limit(limit).offset(offset)
    result = await session.execute(stmt)
    return result.scalars().all()


async def delete_debt(session: AsyncSession, debt_id: int):
    db_debt = await get_debt(session, debt_id)
    if not db_debt:
        return False
    await session.delete(db_debt)
    await session.commit()
    return True


async def _employee_totals(session: AsyncSession, employee_ids: list[int]) -> dict[int, dict]:
    result = {}
    if not employee_ids:
        return result
    charged_rows = await session.execute(
        select(Debt.employee_id, func.coalesce(func.sum(Debt.total), 0))
        .where(Debt.employee_id.in_(employee_ids))
        .group_by(Debt.employee_id)
    )
    for employee_id, total_charged in charged_rows.all():
        result.setdefault(employee_id, {"charged": Decimal("0"), "paid": Decimal("0")})
        result[employee_id]["charged"] = Decimal(total_charged)

    paid_rows = await session.execute(
        select(DebtPayment.employee_id, func.coalesce(func.sum(DebtPayment.amount), 0))
        .where(DebtPayment.employee_id.in_(employee_ids))
        .group_by(DebtPayment.employee_id)
    )
    for employee_id, total_paid in paid_rows.all():
        result.setdefault(employee_id, {"charged": Decimal("0"), "paid": Decimal("0")})
        result[employee_id]["paid"] = Decimal(total_paid)
    return result


async def get_debtor_summaries(
    session: AsyncSession,
    company_id: Optional[int] = None,
    search: Optional[str] = None,
    only_with_balance: bool = False,
) -> list[schemas.DebtorSummary]:
    stmt = select(DebtEmployee)
    if company_id is not None:
        stmt = stmt.where(DebtEmployee.company_id == company_id)
    if search:
        stmt = stmt.where(DebtEmployee.name.ilike(f"%{search.strip()}%"))
    stmt = stmt.order_by(DebtEmployee.name)
    employees = (await session.execute(stmt)).scalars().all()

    if not employees:
        return []
    totals = await _employee_totals(session, [e.id for e in employees])

    summaries: list[schemas.DebtorSummary] = []
    for employee in employees:
        charged = totals.get(employee.id, {}).get("charged", Decimal("0"))
        paid = totals.get(employee.id, {}).get("paid", Decimal("0"))
        balance = charged - paid
        if only_with_balance and balance <= 0:
            continue
        summaries.append(
            schemas.DebtorSummary(
                employee=schemas.DebtEmployeeResponse.model_validate(employee),
                total_charged=charged,
                total_paid=paid,
                balance=balance,
            )
        )
    return summaries


def _balance(charges: list[Debt], payments: list[DebtPayment]) -> Decimal:
    total_charged = sum((d.total or 0) for d in charges)
    total_paid = sum((p.amount or 0) for p in payments)
    return Decimal(total_charged) - Decimal(total_paid)


async def get_employee_account(session: AsyncSession, employee_id: int) -> schemas.EmployeeAccount:
    employee = (await session.execute(select(DebtEmployee).where(DebtEmployee.id == employee_id))).scalar_one_or_none()
    if not employee:
        return None

    debts_stmt = (
        select(Debt)
        .where(Debt.employee_id == employee_id)
        .options(selectinload(Debt.items))
        .order_by(desc(Debt.debt_date), desc(Debt.id))
    )
    debts = (await session.execute(debts_stmt)).scalars().all()

    payments_stmt = (
        select(DebtPayment)
        .where(DebtPayment.employee_id == employee_id)
        .order_by(desc(DebtPayment.payment_date), desc(DebtPayment.id))
    )
    payments = (await session.execute(payments_stmt)).scalars().all()

    return schemas.EmployeeAccount(
        employee=schemas.DebtEmployeeResponse.model_validate(employee),
        total_charged=sum((d.total or 0) for d in debts),
        total_paid=sum((p.amount or 0) for p in payments),
        balance=_balance(debts, payments),
        debts=[schemas.DebtResponse.model_validate(d) for d in debts],
        payments=[schemas.DebtPaymentResponse.model_validate(p) for p in payments],
    )


async def create_payment(session: AsyncSession, data: schemas.DebtPaymentCreate) -> DebtPayment:
    debtor_data = schemas.DebtCreate(
        odoo_employee_id=data.odoo_employee_id,
        company_id=data.company_id,
        company_name=data.company_name,
        employee_name=data.employee_name,
        identification=data.identification,
        job_title=data.job_title,
        debt_date=data.payment_date,
        items=[],
    )
    employee = await _upsert_debt_employee(session, debtor_data)
    db_payment = DebtPayment(
        employee_id=employee.id,
        company_id=data.company_id,
        amount=data.amount,
        payment_date=data.payment_date,
        notes=data.notes,
    )
    session.add(db_payment)
    await session.commit()
    await session.refresh(db_payment)
    return db_payment


async def get_payments(
    session: AsyncSession,
    employee_id: Optional[int] = None,
    company_id: Optional[int] = None,
    limit: int = 100,
    offset: int = 0,
):
    stmt = select(DebtPayment)
    if employee_id is not None:
        stmt = stmt.where(DebtPayment.employee_id == employee_id)
    if company_id is not None:
        stmt = stmt.where(DebtPayment.company_id == company_id)
    stmt = stmt.order_by(desc(DebtPayment.payment_date), desc(DebtPayment.id)).limit(limit).offset(offset)
    result = await session.execute(stmt)
    return result.scalars().all()


async def delete_payment(session: AsyncSession, payment_id: int):
    db_payment = (await session.execute(select(DebtPayment).where(DebtPayment.id == payment_id))).scalar_one_or_none()
    if not db_payment:
        return False
    await session.delete(db_payment)
    await session.commit()
    return True
