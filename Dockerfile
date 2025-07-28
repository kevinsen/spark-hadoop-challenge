# Imagen base estable de Jupyter con PySpark
FROM jupyter/pyspark-notebook:latest

# Cambiar a usuario root para instalar dependencias adicionales
USER root

# Copiar requirements.txt
COPY requirements.txt /tmp/requirements.txt

# Instalar dependencias Python adicionales
RUN pip install --no-cache-dir -r /tmp/requirements.txt

USER $NB_UID 