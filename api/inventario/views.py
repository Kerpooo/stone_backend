from .models import Inventario
from .serializer import InventarioSerializer
from rest_framework import viewsets, permissions
from rest_framework.response import Response


class InventarioViewSet(viewsets.ModelViewSet):
    queryset = Inventario.objects.all()
    serializer_class = InventarioSerializer
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, format=None):
        queryset = self.get_queryset()
        data = []
        for item in queryset:
            data.append(
                {
                    "id": item.id_inventario,
                    "cantidad_disponible": item.cantidad_disponible,
                    "nombre_producto": (
                        item.id_producto.nombre if item.id_producto else None
                    ),
                    "nombre_bodega": item.id_bodega.nombre if item.id_bodega else None,
                }
            )
        return Response(data)
