# Imagen base de Jupyter con PySpark
FROM jupyter/pyspark-notebook:latest

# Cambiar a usuario root
USER root

# Instalar OpenJDK 8 (compatible con Spark 2.3)
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk-headless wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Instalar Spark 2.3.4 específicamente
ENV SPARK_VERSION=2.3.4
ENV HADOOP_VERSION=2.7
ENV SPARK_HOME=/opt/spark

RUN cd /tmp && \
    wget -q "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    tar xzf "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    rm -rf $SPARK_HOME && \
    mv "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" $SPARK_HOME && \
    rm "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    chown -R $NB_UID:$NB_GID $SPARK_HOME

# Instalar PySpark 2.3.4 y matplotlib para el histograma
RUN pip install --no-cache-dir \
    pyspark==2.3.4 \
    matplotlib

USER $NB_UID 