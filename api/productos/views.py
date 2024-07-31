from rest_framework import viewsets
from .models import Productos
from .serializer import ProductosSerializer


class ProductoViewSet(viewsets.ModelViewSet):
    queryset = Productos.objects.all()
    serializer_class = ProductosSerializer
