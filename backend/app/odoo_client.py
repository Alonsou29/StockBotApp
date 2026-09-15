import asyncio
import logging
import time
from decimal import Decimal
from typing import Any, Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 300  # 5 minutos

_STOCK_LOCATIONS = {1: 5, 2: 30}  # company_id -> ubicacion "Existencias"


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

    def _stock_location(self, company_id: Optional[int]) -> int:
        return _STOCK_LOCATIONS.get(company_id or 1, 5)

    async def adjust_stock(self, company_id: Optional[int], items: list[dict[str, Any]]) -> dict[int, float]:
        """Ajusta el stock on-hand en Odoo.

        - items: [{product_id, delta}]
        - delta negativo descuenta stock, positivo lo devuelve.
        - Si falla cualquier ajuste, lanza OdooError (aborta la operacion).
        """
        if not self._configured:
            raise OdooError("Configuración de Odoo incompleta en el .env")
        location_id = self._stock_location(company_id)
        uid = await self.authenticate()
        results: dict[int, float] = {}
        for item in items:
            product_id = int(item["product_id"])
            delta = Decimal(str(item["delta"]))
            if delta == 0:
                continue
            try:
                quant_ids = await self.execute_kw(
                    "stock.quant", "search", [[["product_id", "=", product_id], ["location_id", "=", location_id]]]
                )
                if quant_ids:
                    quant_data = await self.execute_kw(
                        "stock.quant", "read", [quant_ids[0], ["quantity"]]
                    )
                    current = Decimal(str(quant_data[0].get("quantity") or 0))
                    quant_id = int(quant_ids[0])
                else:
                    current = Decimal("0")
                    created = await self.execute_kw(
                        "stock.quant",
                        "create",
                        [[
                            {
                                "product_id": product_id,
                                "location_id": location_id,
                                "inventory_quantity": float(delta),
                                "inventory_quantity_set": True,
                            }
                        ]],
                    )
                    quant_id = int(created[0])
                target = (current + delta).quantize(Decimal("0.001"))
                await self.execute_kw(
                    "stock.quant",
                    "write",
                    [[quant_id], {"inventory_quantity": float(target), "inventory_quantity_set": True}],
                )
                await self.execute_kw(
                    "stock.quant",
                    "action_apply_inventory",
                    [[quant_id]],
                    {"context": {}},
                )
                results[product_id] = float(target)
            except OdooError:
                raise
            except Exception as exc:
                raise OdooError(f"No se pudo ajustar stock del producto {product_id}: {exc}")
        logger.info("Ajuste de stock en Odoo (loc %s): %s", location_id, results)
        return results


odoo_client = OdooClient()