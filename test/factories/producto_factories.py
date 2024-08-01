from faker import Faker
from api.productos.models import Productos  

faker = Faker()


class ProductoFactory:
    def build_producto_JSON(self):
        return {
            "nombre": faker.word(),  # Genera un nombre de producto aleatorio
            "descripcion": faker.text(),  # Genera una descripción de producto aleatoria
            "precio": faker.pydecimal(
                left_digits=4, right_digits=2, positive=True
            ),  # Genera un precio aleatorio
        }

    def create_producto(self):
        return Productos.objects.create(**self.build_producto_JSON())
