from test.test_setup import Setup
from test.factories.inventario_factories import InventarioFactory
from rest_framework import status


class InventarioTestCase(Setup):

    def test_listar_inventario(self):
        """Verifica que se puedan listar el inventario."""
        InventarioFactory().create_inventario()
        url = "/api/v1/inventario/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)  # Verifica el inventario


    def test_actualizar_inventario(self):
        """Verifica que se pueda actualizar un inventario existente."""
        inventario = InventarioFactory().create_inventario()
        url = f"/api/v1/inventario/{inventario.id_inventario}/"
        updated_data = {
            "cantidad_disponible": 50,  # Cambia la cantidad disponible
        }
        response = self.client.put(url, updated_data, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data["cantidad_disponible"], updated_data["cantidad_disponible"]
        )

    def test_listar_inventario_sin_token(self):
        """Verifica que se obtenga un error al intentar listar productos sin autenticación."""
        self.client.credentials()  # Elimina las credenciales del cliente
        url = "/api/v1/inventario/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
