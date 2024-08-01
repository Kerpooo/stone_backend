from django.db import models


class Productos(models.Model):
    id_producto = models.AutoField(primary_key=True)
    nombre = models.CharField(unique=True, max_length=255)
    descripcion = models.TextField(blank=True, null=True)
    precio = models.DecimalField(max_digits=10, decimal_places=2)
    activo = models.BooleanField(default=False)

    class Meta:
        managed = True
        db_table = "productos"
