from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app import crud, schemas

router = APIRouter(prefix="/products", tags=["products"])


@router.get("/", response_model=list[schemas.ProductResponse])
async def read_products(category: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    return await crud.get_products(db, category=category)


@router.post("/", response_model=schemas.ProductResponse, status_code=201)
async def create_product(product: schemas.ProductCreate, db: AsyncSession = Depends(get_db)):
    return await crud.create_product(db, product)


@router.get("/{product_id}", response_model=schemas.ProductResponse)
async def read_product(product_id: int, db: AsyncSession = Depends(get_db)):
    product = await crud.get_product(db, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.post("/seed", status_code=201)
async def seed_products(db: AsyncSession = Depends(get_db)):
    from app.seed import seed_products
    count = await seed_products(db)
    return {"seeded": count}
