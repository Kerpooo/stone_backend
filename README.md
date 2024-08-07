# Inventario de Ventas

## Descripción

Esta es una aplicación de gestión de inventario desarrollada con Django y Django REST framework. Permite administrar productos, ventas y bodegas.

## Requisitos

- Python 3.x
- Django
- Django REST framework

## Iniciar entorno virtual en Python

## Usar las variables de entorno que se requieran

En el archivo .env.example se encuentran las variables de entorno que se usaron en el proyecto. Si se necesita cambiar contraseñas usuario etc de donde esta hospedada la base de datos realizar los camios en ese archivo y cambiar el nombre del archivo a solo .env

```bash
python -m venv env
env\Scripts\activate  # En Windows
```

## Instalar los paquetes requeridos

```bash
pip install -r requirements.txt
```


## Configuración de la base de datos


```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'inventario_ventas',
        'USER': 'tu_usuario',
        'PASSWORD': 'tu_contraseña',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

## Migraciones

Ejecuta las migraciones para crear las tablas en la base de datos:

```bash
python manage.py makemigrations
python manage.py migrate
```

## Crear superusuario

Para acceder al panel de control administrador, crea un superusuario:

```bash
python manage.py createsuperuser
```

## Ejecutar el servidor de desarrollo

```bash
python manage.py runserver
```

## Panel de control administrador

- **username:** admin
- **email:** admin@example.com
- **password:** admin

### URL Acceso al panel de control

```
http://127.0.0.1:8000/admin/
```

## Documentación de la API

Para acceder a la documentación de la API generada con Django REST framework:

```
http://127.0.0.1:8000/docs/
```

## Ejecución de tests

Para ejecutar los tests de la aplicación:

```bash
python manage.py test
```

