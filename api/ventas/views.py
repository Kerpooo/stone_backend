from rest_framework import viewsets
from .serializer import *
from .models import DetalleVenta, Ventas
from django.db import connection
from rest_framework import status
import json
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

# Create your views here.


class VentaViewSet(viewsets.ViewSet):

    queryset = Ventas.objects.all()

    def list(self, request, format=None):
        queryset = Ventas.objects.all().order_by("-fecha_venta")
        serializer = VentasSerializer(queryset, many=True)
        return Response(serializer.data)

    def retrieve(self, request, format=None, pk=None):
        queryset = Ventas.objects.all()
        venta = get_object_or_404(queryset, pk=pk)
        serializer = VentasSerializer(venta)

        # Obtener los detalles de la venta
        detalles = DetalleVenta.objects.filter(id_venta=pk)
        detalles_serializer = DetalleVentaSerializer(detalles, many=True)

        response_data = {
            "venta": serializer.data,
            "detalles": detalles_serializer.data,
        }

        return Response(response_data)

    def destroy(self, request, pk=None):
        venta = get_object_or_404(Ventas, pk=pk)
        venta.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    def create(self, request, format=None):
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
