import asyncio
import logging
import time
from typing import Any, Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 300  # 5 minutos


class OdooError(Exception):
    """Error de conexión o ejecución contra Odoo."""


class OdooClient:
    """Cliente JSON-RPC hacia Odoo (endpoints /jsonrpc)."""

    def __init__(self) -> None:
        self._uid: Optional[int] = None
        self._cache: dict[str, tuple[float, Any]] = {}

    @property
    def _configured(self) -> bool:
        return all(
            [
                settings.ODOO_URL,
                settings.ODOO_DB,
                settings.ODOO_USERNAME,
                settings.ODOO_API_KEY,
            ]
        )

    def _endpoint(self) -> str:
        return f"{settings.ODOO_URL.rstrip('/')}/jsonrpc"

    async def _call(self, service: str, method: str, args: list[Any]) -> Any:
        if not self._configured:
            raise OdooError("Configuración de Odoo incompleta en el .env")
        payload = {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {"service": service, "method": method, "args": args},
        }
        async with httpx.AsyncClient(timeout=settings.ODOO_TIMEOUT) as client:
            response = await client.post(self._endpoint(), json=payload)
        response.raise_for_status()
        data = response.json()
        if data.get("error"):
            raise OdooError(str(data["error"]))
        return data.get("result")

    async def authenticate(self) -> int:
        if self._uid is not None:
            return self._uid
        uid = await self._call(
            "common",
            "login",
            [settings.ODOO_DB, settings.ODOO_USERNAME, settings.ODOO_API_KEY],
        )
        if not uid:
            raise OdooError("Credenciales de Odoo inválidas")
        self._uid = uid
        return uid

    async def execute_kw(self, model: str, method: str, args: list[Any], kwargs: Optional[dict] = None) -> Any:
        uid = await self.authenticate()
        return await self._call(
            "object",
            "execute_kw",
            [settings.ODOO_DB, uid, settings.ODOO_API_KEY, model, method, args, kwargs or {}],
        )

    def _cached(self, key: str) -> Optional[Any]:
        entry = self._cache.get(key)
        if entry and time.monotonic() - entry[0] < CACHE_TTL_SECONDS:
            return entry[1]
        return None

    def _store(self, key: str, value: Any) -> Any:
        self._cache[key] = (time.monotonic(), value)
        return value

    async def test_connection(self) -> dict:
        uid = await self.authenticate()
        companies = await self.get_companies()
        return {
            "connected": True,
            "uid": uid,
            "username": settings.ODOO_USERNAME,
            "db": settings.ODOO_DB,
            "companies": companies,
        }

    async def get_companies(self) -> list[dict]:
        key = "companies"
        cached = self._cached(key)
        if cached is not None:
            return cached
        records = await self.execute_kw(
            "res.company",
            "search_read",
            [[]],
            {"fields": ["id", "name"], "order": "name"},
        )
        return self._store(key, records or [])

    async def get_employees(self, company_id: Optional[int] = None, search: Optional[str] = None) -> list[dict]:
        domain = []
        if company_id:
            domain.append(["company_id", "=", company_id])
        if search:
            keyword = search.strip()
            if keyword:
                domain.append(["name", "ilike", keyword])
        key = f"employees::{company_id}::{search}"
        cached = self._cached(key)
        if cached is not None:
            return cached
        records = await self.execute_kw(
            "hr.employee",
            "search_read",
            [domain],
            {
                "fields": ["id", "name", "identification_id", "job_title", "company_id", "active"],
                "order": "name",
            },
        )
        return self._store(key, records or [])

    async def get_products(self, company_id: Optional[int] = None, search: Optional[str] = None) -> list[dict]:
        domain = [["sale_ok", "=", True]]
        if company_id:
            domain.append("|")
            domain.append(["company_id", "=", False])
            domain.append(["company_id", "=", company_id])
        if search:
            keyword = search.strip()
            if keyword:
                domain.append(["name", "ilike", keyword])
        key = f"products::{company_id}::{search}"
        cached = self._cached(key)
        if cached is not None:
            return cached
        records = await self.execute_kw(
            "product.product",
            "search_read",
            [domain],
            {
                "fields": ["id", "name", "default_code", "list_price", "categ_id", "company_id"],
                "limit": 100,
                "order": "name",
            },
        )
        return self._store(key, records or [])


odoo_client = OdooClient()