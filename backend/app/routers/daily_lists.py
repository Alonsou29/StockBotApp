from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app import crud, schemas

router = APIRouter(prefix="/daily-lists", tags=["daily-lists"])


@router.get("/", response_model=list[schemas.DailyListSummary])
async def read_daily_lists(limit: int = 100, offset: int = 0, db: AsyncSession = Depends(get_db)):
    return await crud.get_daily_lists(db, limit=limit, offset=offset)


@router.get("/by-date/{list_date}", response_model=schemas.DailyListResponse)
async def read_daily_list_by_date(list_date: date, db: AsyncSession = Depends(get_db)):
    daily_list = await crud.get_daily_list_by_date(db, list_date)
    if not daily_list:
        raise HTTPException(status_code=404, detail="Daily list not found for this date")
    return daily_list


@router.get("/{list_id}", response_model=schemas.DailyListResponse)
async def read_daily_list(list_id: int, db: AsyncSession = Depends(get_db)):
    daily_list = await crud.get_daily_list(db, list_id)
    if not daily_list:
        raise HTTPException(status_code=404, detail="Daily list not found")
    return daily_list


@router.post("/", response_model=schemas.DailyListResponse, status_code=201)
async def create_daily_list(data: schemas.DailyListCreate, db: AsyncSession = Depends(get_db)):
    existing = await crud.get_daily_list_by_date(db, data.list_date)
    if existing:
        raise HTTPException(status_code=409, detail="Daily list already exists for this date")
    return await crud.create_daily_list(db, data)


@router.put("/{list_id}", response_model=schemas.DailyListResponse)
async def update_daily_list(list_id: int, data: schemas.DailyListUpdate, db: AsyncSession = Depends(get_db)):
    updated = await crud.update_daily_list(db, list_id, data)
    if not updated:
        raise HTTPException(status_code=404, detail="Daily list not found")
    return updated


@router.delete("/{list_id}", status_code=204)
async def delete_daily_list(list_id: int, db: AsyncSession = Depends(get_db)):
    deleted = await crud.delete_daily_list(db, list_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Daily list not found")
    return None
