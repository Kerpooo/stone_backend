from rest_framework import viewsets
from rest_framework.views import APIView
from .serializer import *
from .models import *
from django.db import connection
from rest_framework import status
import json
from rest_framework.response import Response

# Create your views here.


class BodegaViewSet(viewsets.ModelViewSet):
    queryset = Bodega.objects.all()
    serializer_class = BodegaSerializer


class ProductoViewSet(viewsets.ModelViewSet):
    queryset = Productos.objects.all()
    serializer_class = ProductosSerializer


class InventarioViewSet(viewsets.ModelViewSet):
    queryset = Inventario.objects.all()
    serializer_class = InventarioSerializer


class VentaViewSet(viewsets.ModelViewSet):
    queryset = Ventas.objects.all()
    serializer_class = VentasSerializer


class GenerarVentaView(APIView):
    def post(self, request, format=None):
        serializer = GenerarVentaSerializer(data=request.data)
        if serializer.is_valid():
            venta = serializer.data["venta"]
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "CALL inventario_ventas.insertar_venta_con_detalles(%s);",
                        [json.dumps(venta)],
                    )
                return Response(
                    {"status": "success", "message": "Venta generada correctamente"},
                    status=status.HTTP_201_CREATED,
                )
            except Exception as e:
                return Response(
                    {"status": "error", "message": str(e)},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
