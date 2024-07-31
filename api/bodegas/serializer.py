from rest_framework import serializers
from .models import Bodega


class BodegaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Bodega
        fields = "__all__"
