from rest_framework import serializers
from .models import Productos, Bodega, Inventario, Ventas


class ProductosSerializer(serializers.ModelSerializer):
    class Meta:
        model = Productos
        fields = "__all__"


class BodegaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Bodega
        fields = "__all__"


class InventarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventario
        fields = "__all__"


class VentasSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ventas
        fields = "__all__"


# Generar ventas


# Producto unico
class ProductoVentaSerializer(serializers.Serializer):
    id_producto = serializers.IntegerField()
    cantidad = serializers.IntegerField()


# Lista de los productos
class GenerarVentaSerializer(serializers.Serializer):
    venta = ProductoVentaSerializer(many=True)


