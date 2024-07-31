from .models import Inventario
from .serializer import InventarioSerializer
from rest_framework import viewsets


class InventarioViewSet(viewsets.ModelViewSet):
    queryset = Inventario.objects.all()
    serializer_class = InventarioSerializer
