from test.test_setup import Setup
from test.factories.bodega_factories import BodegaFactory
from rest_framework import status


class BodegaTestCase(Setup):

    def test_listar_bodegas(self):
        BodegaFactory().create_bodega()
        url = "/api/v1/bodega/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)  # Verifica el número de bodegas

    def test_crear_bodega(self):
        """Verifica que se pueda crear una nueva bodega correctamente."""
        url = "/api/v1/bodega/"
        data = {
            "nombre": "Bodega 2",
            "capacidad_max": 200,
            "capacidad_uso": 100,
            "ubicacion": "Ubicación 2",
        }
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + str(self.token))
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["nombre"], data["nombre"])

    def test_detalle_bodega(self):
        """Verifica que se pueda obtener los detalles de una bodega específica."""
        bodega = BodegaFactory().create_bodega()
        url = f"/api/v1/bodega/{bodega.id}/"
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + str(self.token))
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], bodega.id)

    def test_actualizar_bodega(self):
        """Verifica que se pueda actualizar una bodega existente."""
        bodega = BodegaFactory().create_bodega()
        url = f"/api/v1/bodega/{bodega.id}/"
        data = {
            "nombre": "Bodega Actualizada",
            "capacidad_max": 300,
            "capacidad_uso": 150,
            "ubicacion": "Ubicación Actualizada",
        }
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + str(self.token))
        response = self.client.put(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["nombre"], data["nombre"])

    def test_eliminar_bodega(self):
        """Verifica que se pueda eliminar una bodega existente."""
        bodega = BodegaFactory().create_bodega()
        url = f"/api/v1/bodega/{bodega.id}/"
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + str(self.token))
        response = self.client.delete(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        # Verifica que la bodega haya sido eliminada
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_listar_bodegas_sin_token(self):
        self.client.credentials()  # Elimina las credenciales del cliente
        url = "/api/v1/bodega/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
