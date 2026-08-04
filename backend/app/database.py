import asyncio
import logging
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.exc import OperationalError, DBAPIError

from app.config import settings

logger = logging.getLogger(__name__)

MAX_RETRIES = 5
RETRY_DELAY = 1.0
BACKOFF_FACTOR = 2.0

engine = create_async_engine(settings.DATABASE_URL, echo=False, future=True)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()


def _is_connection_error(exc: Exception) -> bool:
    """Detecta si el error es de conexión o caída de la base de datos."""
    if isinstance(exc, OperationalError):
        return True
    if isinstance(exc, DBAPIError) and getattr(exc, "connection_invalidated", False):
        return True
    return False


async def _dispose_engine_pool() -> None:
    """Libera el pool de conexiones para forzar una reconexión limpia."""
    try:
        await engine.dispose()
        logger.info("Pool de conexiones liberado; se creará una nueva al reintentar.")
    except Exception as e:
        logger.warning("Error al liberar pool de conexiones: %s", e)


async def get_db() -> AsyncSession:
    """Dependency de FastAPI que entrega una sesión con reintentos y reconexión."""
    last_error = None

    for attempt in range(MAX_RETRIES):
        try:
            async with AsyncSessionLocal() as session:
                # Verificamos que la conexión esté viva antes de entregarla
                await session.execute(text("SELECT 1"))
                yield session
                return
        except Exception as exc:
            last_error = exc
            if not _is_connection_error(exc):
                raise

            logger.warning(
                "Conexión a base de datos fallida (intento %d/%d): %s",
                attempt + 1,
                MAX_RETRIES,
                exc,
            )

            if attempt < MAX_RETRIES - 1:
                await _dispose_engine_pool()
                wait_seconds = RETRY_DELAY * (BACKOFF_FACTOR ** attempt)
                logger.info("Reintentando conexión en %.1f segundos...", wait_seconds)
                await asyncio.sleep(wait_seconds)

    logger.error("No se pudo conectar a la base de datos tras %d intentos", MAX_RETRIES)
    raise last_error
