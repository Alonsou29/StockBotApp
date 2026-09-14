from typing import Optional
from fastapi import APIRouter, HTTPException

from app.odoo_client import odoo_client

router = APIRouter(prefix="/odoo", tags=["odoo"])


@router.get("/health")
async def odoo_health():
    try:
        return await odoo_client.test_connection()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Odoo no disponible: {exc}")


@router.get("/companies")
async def odoo_companies():
    try:
        return await odoo_client.get_companies()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Odoo no disponible: {exc}")


@router.get("/employees")
async def odoo_employees(company_id: Optional[int] = None, search: Optional[str] = None):
    try:
        return await odoo_client.get_employees(company_id=company_id, search=search)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Odoo no disponible: {exc}")


@router.get("/products")
async def odoo_products(company_id: Optional[int] = None, search: Optional[str] = None):
    try:
        return await odoo_client.get_products(company_id=company_id, search=search)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Odoo no disponible: {exc}")