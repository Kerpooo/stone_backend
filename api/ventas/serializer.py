from rest_framework import serializers
from .models import Ventas, DetalleVenta


class VentasSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ventas
        fields = "__all__"


class DetalleVentaSerializer(serializers.ModelSerializer):
    class Meta:
        model = DetalleVenta
        fields = "__all__"


# Producto unico
class ProductoVentaSerializer(serializers.Serializer):
    id_producto = serializers.IntegerField()
    cantidad = serializers.IntegerField()


# Lista de los productos
class GenerarVentaSerializer(serializers.Serializer):
    venta = ProductoVentaSerializer(many=True)
