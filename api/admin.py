from django.contrib import admin
from .bodegas.models import Bodega
from .inventario.models import Inventario
from .productos.models import Productos
from .ventas.models import Ventas

# Register your models here.
admin.site.register([Bodega, Inventario, Productos, Ventas])
