from faker import Faker
from api.inventario.models import Inventario
from .bodega_factories import BodegaFactory
from .producto_factories import ProductoFactory

faker = Faker()


class InventarioFactory:
    def build_inventario_JSON(self):
        producto = ProductoFactory().create_producto()
        bodega = BodegaFactory().create_bodega()
        return {
            "id_producto": producto,
            "cantidad_disponible": faker.random_int(
                min=1, max=100
            ),  # Genera una cantidad disponible aleatoria
            "id_bodega": bodega,
        }

    def create_inventario(self):
        return Inventario.objects.create(**self.build_inventario_JSON())
