from django.db import models

# Create your models here.

# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Bodega(models.Model):
    nombre = models.CharField(max_length=100)
    capacidad_max = models.IntegerField()
    capacidad_uso = models.IntegerField()
    ubicacion = models.CharField(max_length=255)
    espacio_disponible = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = "bodega"


class DetalleVenta(models.Model):
    id_detalle = models.AutoField(primary_key=True)
    id_venta = models.ForeignKey(
        "Ventas", models.DO_NOTHING, db_column="id_venta", blank=True, null=True
    )
    id_producto = models.ForeignKey(
        "Productos", models.DO_NOTHING, db_column="id_producto", blank=True, null=True
    )
    cantidad = models.IntegerField()
    total = models.DecimalField(max_digits=10, decimal_places=2)
    precio_unitario = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    nombre_producto = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        managed = False
        db_table = "detalle_venta"


class Inventario(models.Model):
    id_inventario = models.AutoField(primary_key=True)
    id_producto = models.OneToOneField(
        "Productos", models.DO_NOTHING, db_column="id_producto", blank=True, null=True
    )
    cantidad_disponible = models.IntegerField()
    id_bodega = models.ForeignKey(
        Bodega, models.DO_NOTHING, db_column="id_bodega", blank=True, null=True
    )

    class Meta:
        managed = False
        db_table = "inventario"


class Productos(models.Model):
    id_producto = models.AutoField(primary_key=True)
    nombre = models.CharField(unique=True, max_length=255)
    descripcion = models.TextField(blank=True, null=True)
    precio = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        managed = False
        db_table = "productos"


class Ventas(models.Model):
    id_venta = models.AutoField(primary_key=True)
    fecha_venta = models.DateField()
    total_venta = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        managed = False
        db_table = "ventas"
