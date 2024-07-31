from django.urls import path, include
from rest_framework import routers
from .productos.views import ProductoViewSet
from .bodegas.views import BodegaViewSet
from .inventario.views import InventarioViewSet
from .ventas.views import VentaViewSet

router = routers.DefaultRouter()
router.register(r"productos", ProductoViewSet)
router.register(r"inventario", InventarioViewSet)
router.register(r"bodega", BodegaViewSet)
router.register(r"ventas", VentaViewSet)


urlpatterns = [path("", include(router.urls))]
