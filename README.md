# Frutería El Trébol - App de Lista Diaria

Aplicación para automatizar el inventario diario de verduras y frutas de la frutería El Trébol.

## Stack

- **Backend**: Python + FastAPI + SQLAlchemy async
- **Base de datos**: PostgreSQL (con soporte para SQLite en desarrollo)
- **Frontend**: Flutter (móvil)
- **Contenedores**: Docker + Docker Compose

## Estructura

```
fruteria_trebol_app/
├── backend/              # FastAPI
├── frontend/fruteria_trebol/  # Flutter
├── docker-compose.yml
└── README.md
```

## Levantar con Docker (recomendado)

Asegurate de tener Docker y Docker Compose instalados.

```bash
cd fruteria_trebol_app
docker-compose up --build
```

Esto levanta:

- PostgreSQL en `localhost:5432`
- Backend FastAPI en `http://localhost:8000`

La documentación de la API está en `http://localhost:8000/docs`.

## Levantar backend manualmente

Recomendado Python 3.12 o 3.13.

1. Crear entorno virtual e instalar dependencias:

```bash
cd fruteria_trebol_app/backend
python3.13 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Copiar y editar el archivo de variables:

```bash
cp .env.example .env
# Si no tienes PostgreSQL, usa SQLite:
# DATABASE_URL=sqlite+aiosqlite:///./trebol.db
```

3. Ejecutar el servidor:

```bash
uvicorn app.main:app --reload
```

## Levantar frontend Flutter

1. Asegurate de tener Flutter instalado.
2. Configura la URL del backend en `lib/services/api_service.dart`:
   - Emulador Android: `http://10.0.2.2:8000`
   - iOS simulador: `http://localhost:8000`
   - Dispositivo físico: IP de tu computadora

```bash
cd fruteria_trebol_app/frontend/fruteria_trebol
flutter pub get
flutter run
```

## Características

- Listado de productos precargados (verduras y frutas).
- Crear y editar lista del día con fecha.
- Indicar "Hay" y "Traer" para cada producto.
- Guardar historial de listas anteriores.
- Sin login ni autenticación (por ahora).

## API Endpoints principales

- `GET /products` - listar productos
- `GET /products?category=verdura` - filtrar por categoría
- `POST /products/seed` - volver a sembrar productos (idempotente)
- `GET /daily-lists/` - historial de listas
- `GET /daily-lists/by-date/{yyyy-mm-dd}` - lista de una fecha
- `POST /daily-lists/` - crear lista
- `PUT /daily-lists/{id}` - actualizar lista
- `DELETE /daily-lists/{id}` - eliminar lista
