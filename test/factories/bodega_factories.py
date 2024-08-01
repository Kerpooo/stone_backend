from faker import Faker

from api.bodegas.models import Bodega

faker = Faker()


class BodegaFactory:
    def build_bodega_JSON(self):
        return {
            "nombre": faker.name,
            "capacidad_max": faker.random_int(100, 1000),
            "capacidad_uso": faker.random_int(0, 100),
            "ubicacion": faker.country(),
        }

    def create_bodega(self):
        return Bodega.objects.create(**self.build_bodega_JSON())
