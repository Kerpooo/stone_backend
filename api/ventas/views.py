from rest_framework import viewsets, permissions
from .serializer import *
from .models import DetalleVenta, Ventas
from django.db import connection
from rest_framework import status
import json
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

# Create your views here.


class VentaViewSet(viewsets.ViewSet):

    permission_classes = [permissions.IsAuthenticated]

    queryset = Ventas.objects.all()

    def list(self, request, format=None):
        queryset = Ventas.objects.all().order_by("-fecha_venta")
        serializer = VentasSerializer(queryset, many=True)
        return Response(serializer.data)

    def retrieve(self, request, pk=None):
        queryset = Ventas.objects.all()
        venta = get_object_or_404(queryset, pk=pk)
        venta_serializer = VentasSerializer(venta)

        # Obtener los detalles de la venta
        detalles = DetalleVenta.objects.filter(id_venta=pk)
        detalles_data = []
        
        for detalle in detalles:
            producto = detalle.id_producto
            detalle_data = {
                "id_detalle": detalle.id_detalle,
                "cantidad": detalle.cantidad,
                "precio_unitario": producto.precio,  # Suponiendo que el modelo Productos tiene un campo 'precio'
                "nombre_producto": producto.nombre,  # Suponiendo que el modelo Productos tiene un campo 'nombre'
                "total": detalle.cantidad * producto.precio,
                "id_venta": detalle.id_venta.id_venta,
                "id_producto": detalle.id_producto.id_producto,
            }
            detalles_data.append(detalle_data)

        response_data = {
            "venta": venta_serializer.data,
            "detalles": detalles_data,
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
