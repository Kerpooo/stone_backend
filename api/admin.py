from django.contrib import admin
from .models import Bodega, Inventario, Productos, Ventas

# Register your models here.
admin.site.register([Bodega, Inventario, Productos, Ventas])
