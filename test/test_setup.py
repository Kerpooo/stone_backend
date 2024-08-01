from rest_framework.test import APITestCase
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework import status
from api.bodegas.models import Bodega


class Setup(APITestCase):
    def setUp(self):
        # Crear un usuario y obtener el token
        self.user = User.objects.create_user(
            username="testuser", password="testpassword"
        )
        self.token = RefreshToken.for_user(self.user).access_token
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + str(self.token))

        return super().setUp()
