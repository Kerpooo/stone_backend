from django.urls import path, include
from rest_framework import routers
from api import views

router = routers.DefaultRouter()
router.register(r"productos", views.ProductoViewSet)
router.register(r"inventario", views.InventarioViewSet)
router.register(r"bodega", views.BodegaViewSet)
router.register(r"ventas", views.VentaViewSet)


urlpatterns = [
    path("", include(router.urls)),
    path(
        "generar_venta/",
        views.GenerarVentaView.as_view(),
        name="generar venta",
    ),
]
