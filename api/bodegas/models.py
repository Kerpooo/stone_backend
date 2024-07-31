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