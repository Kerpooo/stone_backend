from .models import Bodega
from .serializer import BodegaSerializer
from rest_framework import viewsets


class BodegaViewSet(viewsets.ModelViewSet):
    queryset = Bodega.objects.all()
    serializer_class = BodegaSerializer
