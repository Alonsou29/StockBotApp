import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, DBAPIError

from app.config import settings
from app.database import engine, Base, AsyncSessionLocal
from app.routers import products, daily_lists
from app.seed import seed_products

logger = logging.getLogger(__name__)

STARTUP_MAX_RETRIES = 10
STARTUP_RETRY_DELAY = 1.0
STARTUP_BACKOFF_FACTOR = 1.5


def _is_connection_error(exc: Exception) -> bool:
    if isinstance(exc, OperationalError):
        return True
    if isinstance(exc, DBAPIError) and getattr(exc, "connection_invalidated", False):
        return True
    return False


async def _ensure_schema_with_retry() -> None:
    """Crea las tablas reintentando si la base de datos no está disponible."""
    for attempt in range(STARTUP_MAX_RETRIES):
        try:
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            logger.info("Esquema de base de datos verificado.")
            return
        except Exception as exc:
            if not _is_connection_error(exc):
                raise
            logger.warning(
                "No se pudo conectar a la base de datos para crear tablas (intento %d/%d): %s",
                attempt + 1,
                STARTUP_MAX_RETRIES,
                exc,
            )
            if attempt < STARTUP_MAX_RETRIES - 1:
                await engine.dispose()
                wait_seconds = STARTUP_RETRY_DELAY * (STARTUP_BACKOFF_FACTOR ** attempt)
                logger.info("Reintentando en %.1f segundos...", wait_seconds)
                await asyncio.sleep(wait_seconds)
    logger.error("No se pudo conectar a la base de datos durante el inicio.")
    raise


async def _seed_products_with_retry() -> None:
    """Siembra los productos reintentando si la BD no responde."""
    for attempt in range(STARTUP_MAX_RETRIES):
        try:
            async with AsyncSessionLocal() as session:
                await seed_products(session)
            logger.info("Productos sembrados correctamente.")
            return
        except Exception as exc:
            if not _is_connection_error(exc):
                raise
            logger.warning(
                "No se pudo sembrar productos (intento %d/%d): %s",
                attempt + 1,
                STARTUP_MAX_RETRIES,
                exc,
            )
            if attempt < STARTUP_MAX_RETRIES - 1:
                await engine.dispose()
                wait_seconds = STARTUP_RETRY_DELAY * (STARTUP_BACKOFF_FACTOR ** attempt)
                logger.info("Reintentando seed en %.1f segundos...", wait_seconds)
                await asyncio.sleep(wait_seconds)
    logger.error("No se pudo sembrar productos durante el inicio.")
    raise


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _ensure_schema_with_retry()
    await _seed_products_with_retry()
    yield


app = FastAPI(
    title="Frutería El Trébol API",
    description="Backend para automatizar la lista diaria de productos.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router)
app.include_router(daily_lists.router)


@app.get("/")
async def root():
    return {"message": "Frutería El Trébol API"}


@app.get("/health")
async def health():
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        return {"status": "ok", "database": "connected"}
    except Exception as exc:
        logger.warning("Health check falló: %s", exc)
        raise HTTPException(
            status_code=503,
            detail={"status": "error", "database": "disconnected", "detail": str(exc)},
        )
