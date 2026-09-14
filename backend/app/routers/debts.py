from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app import crud, schemas

router = APIRouter(prefix="/debts", tags=["debts"])


@router.post("/", response_model=schemas.DebtResponse, status_code=201)
async def create_debt(data: schemas.DebtCreate, db: AsyncSession = Depends(get_db)):
    if not data.items:
        raise HTTPException(status_code=400, detail="La deuda debe tener al menos un item")
    return await crud.create_debt(db, data)


@router.get("/", response_model=list[schemas.DebtResponse])
async def read_debts(
    company_id: Optional[int] = None,
    employee_id: Optional[int] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_debts(
        db,
        company_id=company_id,
        employee_id=employee_id,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
        offset=offset,
    )


@router.get("/employees", response_model=list[schemas.DebtorSummary])
async def read_debtors(
    company_id: Optional[int] = None,
    search: Optional[str] = None,
    only_with_balance: bool = False,
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_debtor_summaries(
        db,
        company_id=company_id,
        search=search,
        only_with_balance=only_with_balance,
    )


@router.get("/employees/{employee_id}", response_model=schemas.EmployeeAccount)
async def read_employee_account(employee_id: int, db: AsyncSession = Depends(get_db)):
    account = await crud.get_employee_account(db, employee_id)
    if not account:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return account


@router.get("/payments", response_model=list[schemas.DebtPaymentResponse])
async def read_payments(
    employee_id: Optional[int] = None,
    company_id: Optional[int] = None,
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_payments(
        db,
        employee_id=employee_id,
        company_id=company_id,
        limit=limit,
        offset=offset,
    )


@router.post("/payments", response_model=schemas.DebtPaymentResponse, status_code=201)
async def create_payment(data: schemas.DebtPaymentCreate, db: AsyncSession = Depends(get_db)):
    return await crud.create_payment(db, data)


@router.delete("/payments/{payment_id}", status_code=204)
async def delete_payment(payment_id: int, db: AsyncSession = Depends(get_db)):
    deleted = await crud.delete_payment(db, payment_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Abono no encontrado")
    return None


@router.get("/{debt_id}", response_model=schemas.DebtResponse)
async def read_debt(debt_id: int, db: AsyncSession = Depends(get_db)):
    debt = await crud.get_debt(db, debt_id)
    if not debt:
        raise HTTPException(status_code=404, detail="Deuda no encontrada")
    return debt


@router.delete("/{debt_id}", status_code=204)
async def delete_debt(debt_id: int, db: AsyncSession = Depends(get_db)):
    deleted = await crud.delete_debt(db, debt_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Deuda no encontrada")
    return None