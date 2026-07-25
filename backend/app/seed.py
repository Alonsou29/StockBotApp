VERDURAS = [
    "TOMATE",
    "CEBOLLA",
    "ZANAHORIA",
    "PAPA",
    "CEBOLLA M",
    "PIMENTON R",
    "PIMENTON V",
    "AMERICANA",
    "ROMANA",
    "BERENGENA",
    "APIO",
    "REMOLACHA",
    "AGUACATE",
    "PEPINO",
    "AJI DULCE",
    "AJI MARGA",
    "PLATANOS 1",
    "PLATANOS 2",
    "PLATANOS 3",
    "TOPOCHO",
    "YUCA",
    "AUYAMA",
    "AUY ENANA",
    "REPOLLO M",
    "REPOLLO B",
    "JOJOTO",
    "PAPITA COL",
    "OCUMO",
    "ÑAME",
    "BATATA BLA",
    "BATATA RO",
    "OCUMITO",
    "BROCOLI",
    "COLIFLOR",
    "GENGIBRE",
    "CURCUMA",
    "PINGA DE PE",
    "MONGOL",
    "VAINITA",
    "NABO",
    "CALABACIN",
    "AJO",
    "CEBOLLIN",
    "CILANTRO",
    "PORRO",
    "ACELGA",
    "ESPINACA",
    "CEDANO",
    "PERIJIL",
]

FRUTAS = [
    "PERA",
    "ROJA GRAN",
    "ROJA PEQ",
    "GALA GRAN",
    "VERDE GRAN",
    "VERDE PEQ",
    "ARANDANOS",
    "CIRUELA CRI",
    "CIRUELA IMP",
    "FRESAS",
    "MANGO",
    "GUANABANA",
    "NARANJA",
    "NARANJA IM",
    "UVA CRIOLLA",
    "UVA IMPOR",
    "PARCHITA",
    "GUAYABA",
    "MELON",
    "LECHOSA",
    "TOMATE DE ARBOL",
    "CAMBUR CRIOLLO",
    "CAMBUR MANZANO",
    "CAMBUR BANANO",
    "BOROJO",
    "TAMARINDO CHINO",
    "COCO",
    "DURAZNO G",
    "DURAZNO P",
    "MAMON",
    "PATILLA",
    "PIÑA GRAND",
    "PIÑA MEDIA",
    "PIÑA PEQUE",
    "KIWI",
    "MORA",
    "MANDARINA",
    "MANDARINA IMPORTADA",
    "TAMARINDO",
    "PANELA",
    "MIEL",
    "MEREY",
    "LIMON",
]


async def seed_products(session) -> int:
    from sqlalchemy import select
    from app.models import Product

    existing = (await session.execute(select(Product))).scalars().all()
    if existing:
        return 0

    products = []
    for name in VERDURAS:
        products.append(Product(name=name, category="verdura"))
    for name in FRUTAS:
        products.append(Product(name=name, category="fruta"))

    session.add_all(products)
    await session.commit()
    return len(products)
