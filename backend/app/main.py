from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.routers import products, daily_lists
from app.seed import seed_products
from app.database import AsyncSessionLocal


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as session:
        await seed_products(session)
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
    return {"status": "ok"}
