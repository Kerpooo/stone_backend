from django.db import models
from ..bodegas.models import Bodega



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
