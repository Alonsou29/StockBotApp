from datetime import date
from typing import Optional
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Product, DailyList, DailyListItem
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
