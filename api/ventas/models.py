from django.db import models


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
        managed = True
        db_table = "detalle_venta"


class Ventas(models.Model):
    id_venta = models.AutoField(primary_key=True)
    fecha_venta = models.DateField()
    total_venta = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        managed = True
        db_table = "ventas"
