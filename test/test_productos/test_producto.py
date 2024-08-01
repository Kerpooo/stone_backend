from test.test_setup import Setup
from test.factories.producto_factories import ProductoFactory
from rest_framework import status


class ProductoTestCase(Setup):

    def test_listar_productos(self):
        """Verifica que se puedan listar los productos."""
        ProductoFactory().create_producto()
        url = "/api/v1/productos/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)  # Verifica el número de productos

    def test_crear_producto(self):
        """Verifica que se pueda crear un nuevo producto correctamente."""
        url = "/api/v1/productos/"
        data = {
            "nombre": "Producto 1",
            "descripcion": "Descripción del producto 1",
            "precio": 100.00,
        }
        response = self.client.post(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["nombre"], data["nombre"])

    def test_detalle_producto(self):
        """Verifica que se pueda obtener los detalles de un producto específico."""
        producto = ProductoFactory().create_producto()
        url = f"/api/v1/productos/{producto.id_producto}/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id_producto"], producto.id_producto)

    def test_actualizar_producto(self):
        """Verifica que se pueda actualizar un producto existente."""
        producto = ProductoFactory().create_producto()
        url = f"/api/v1/productos/{producto.id_producto}/"
        data = {
            "nombre": "Producto Actualizado",
            "descripcion": "Descripción actualizada",
            "precio": 150.00,
        }
        response = self.client.put(url, data, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["nombre"], data["nombre"])

    def test_eliminar_producto(self):
        """Verifica que se pueda eliminar un producto existente."""
        producto = ProductoFactory().create_producto()
        url = f"/api/v1/productos/{producto.id_producto}/"
        response = self.client.delete(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        # Verifica que el producto haya sido eliminado
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_listar_productos_sin_token(self):
        """Verifica que se obtenga un error al intentar listar productos sin autenticación."""
        self.client.credentials()  # Elimina las credenciales del cliente
        url = "/api/v1/productos/"
        response = self.client.get(url, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
