# GRANDATA - Test Data Engineering -> *Kevin Santos*

## Ejercicio 1 - Spark + Docker
1. **Calcular el monto total** que facturará el proveedor del servicio por envíos de sms.
- **Monto toal a facturar: $1,696,022.50**

2. **Generar un dataset** que contenga los ID de los 100 usuarios con mayor facturación por envío de sms y el monto total a facturar a cada uno. Además del ID, incluir el ID hasheado mediante el algoritmo MD5. Escribir el dataset en formato parquet con compresión gzip.
- [Dataset](output/top_100_users_ds/)

3. **Graficar un histograma** de cantidad de llamadas que se realizan por hora del día.
![Histograma de llamadas por hora](output/pyplot/calls_by_hour_hist.png)
---

## Ejercicio 2 - Preguntas Generales

### 1. Administración de Recursos en Cluster Hadoop

La empresa cuenta con un cluster on premise de Hadoop en el cual se ejecuta, tanto el data pipeline principal de los datos, como los análisis exploratorios de los equipos de Data Science y Data Engineering. Teniendo en cuenta que cada proceso compite por un número específico de recursos del cluster:

**¿Cómo priorizaría los procesos productivos sobre los procesos de análisis exploratorios?**
<br>
Entiendo que por medio de YARN pueden armarse queues con distintos niveles de prioridades.
En este caso haría 2 queues:
- Queue "prod" con alta prioridad y asignado un 80% de recursos.
- Queue "analytics" con baja prioridad y un 20% de recursos.
Según vi en la [documentación de hadoop](https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/CapacityScheduler.html) esto se logra utilizando el capacity-scheduler y propiedades de preemption para los procesos productivos.

**Debido a que los procesos productivos del pipeline poseen un uso intensivo tanto de CPU como de memoria, ¿qué estrategia utilizaría para administrar su ejecución durante el día? ¿qué herramientas de scheduling conoce para tal fin?**
<br>
Estimo que pueden usarse estrategias basadas en el manejo de recursos en un tiempo u horario específico. Para eso puede usarse un orquestador de tareas como Airflow.

- **Configuración de recursos dinámicos por horario:**
Entiendo que con YARN se pueden programar politicas para distribuir el uso por horarios en sus queues. En este caso sería algo:
   - En horarios pico o productivos: Asignar 90% a producción, 10% a analytics
   - En horarios no productivos: Permitir 60% producción, 40% analytics

- **Scheduling de tareas con orquestador:**
Puede usarse un orchestatror que ejecute DAGS con horarios o intervalos de horarios programados.
Por ejemplo con Apache Airflow pueden programarse para que los DAGs de tareas analiticas se ejecuten en horarios no productivos. Y en horarios productivos ejecutar los procesos más criticos con alta prioridad.


### 2. Optimización de Performance en Data Lake

Existe una tabla del Data Lake con alta transaccionalidad, que es actualizada diariamente con un gran volumen de datos. Consultas que cruzan información con esta tabla ven afectada su performance en tiempos de respuesta.

**Según su criterio, ¿cuáles serían las posibles causas de este problema?**
<br>
Por experiencia eso suele suceder en tablas que no se particionan correctamente o que cadecen directamente de particionado. Un particionado efectivo es aquel al que se le da uso en los filtros de las consultas. Por lo general en tablas transaccionales se utilizan campos de fechas "no nulos" para definir particiones como por ejemplo 'year', 'month', 'day', 'hour'. Pero siempre hay que tener en cuenta que los usuarios utilicen esas particiones en sus filtros explicitamente.
<br>
Otros problemas de performance pueden darse por ejemplo si la tabla esta compuesta por muchos archivos pequeños (reparticionado ineficiente), o si el formato de los archivos de datos es poco óptimos para grandes volúmenes de datos (CSV, JSON, por ejemplo).

**Dada la respuesta anterior, qué sugeriría para solucionarlo.**
<br>
Sugerencias:
<br>

- Compactación y formato optimizado:
```python
# Conversión a formato Parquet con particionado
df.coalesce(10) \
  .write \
  .mode("overwrite") \
  .option("compression", "snappy") \
  .partitionBy("year", "month", "day") \
  .parquet("path/to/table")
```

- Implementación de Delta Lake para transaccionalidad ACID:
```python
df.write \
  .format("delta") \
  .option("mergeSchema", "true") \
  .mode("overwrite") \
  .save("path/to/delta_table")
# Luego se puede ir haciendo delta.merge de los cdc y haciendo update de la tabla delta
```

- Configuración de Spark para grandes volúmenes:
```python
spark_config = {
    "spark.sql.adaptive.enabled": "true", # autotunea las consultas en runtime
    "spark.sql.adaptive.skewJoin.enabled": "true", # particiona los sesgos de datos
    "spark.sql.files.maxPartitionBytes": "128MB" # balancea la lectura de datos
}
```

### 3. Configuración de Recursos en Cluster Spark

Imagine un clúster Hadoop de 3 nodos, con 50 GB de memoria y 12 cores por nodo. Necesita ejecutar un proceso de Spark que utilizará la mitad de los recursos del clúster, dejando la otra mitad disponible para otros jobs que se lanzarán posteriormente.

**¿Qué configuraciones en la sesión de Spark implementaría para garantizar que la mitad del clúster esté disponible para los jobs restantes?**
<br>
Recursos: 3 nodos × 50GB RAM × 12 cores = 150GB total, 36 cores total
Objetivo: Reservar la mitad para 1 job y disponibilizar el resto (75GB RAM, 18 cores)
<br>

**Configuración específica:**
Seteo limites 'duros'
```python
# Configuración de sesión Spark
spark = SparkSession.builder \
    .appName("SparkProcess50") \
    .config("spark.yarn.queue", "spark_job") # definir una queue para el job que usa la mitad
    .config("spark.driver.memory", "4g") \
    .config("spark.driver.cores", "2") \
    .config("spark.executor.instances", "7") \
    .config("spark.executor.memory", "8g") \
    .config("spark.executor.cores", "2") \
    .config("spark.executor.memoryOverhead", "2g") \
    .config("spark.dynamicAllocation.enabled", "false") \
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
    .getOrCreate()
```

**Justificación técnica:**
- **Asignación de recursos:**
  - Driver: 4GB memoria + 2 cores
  - Executors: 7 × 8GB = 56GB + 7 × 2 cores = 14 cores
  - Overhead: 7 × 2GB = 14GB para SO y garbage collection
  - Total: 74GB < 75GB objetivo, 16 cores < 18 cores objetivo

- **Configuración de YARN:**
Entendí que la idea es usar las queues de YARN para decirle explicitamente a que queue pertenece el job que se envía a ejecutar, de esta forma teniendo 2 queues (spark_job, other_jobs) puedo forzar la división de los recursos (spark_job usará el 50% y other_jobs el resto), pero si el job de spark_job  termina, liberará esos recursos a other_jobs.

*(XML generado con Claude usando el context de hadoop)*
```xml
<!-- Configuración para garantizar separación de recursos -->
<!-- Límites por nodo -->
<property>
  <name>yarn.nodemanager.resource.memory-mb</name>
  <value>48000</value>
  <description>48GB total por nodo</description>
</property>

<property>
  <name>yarn.nodemanager.resource.cpu-vcores</name>
  <value>10</value>
  <description>10 vCores total por nodo</description>
</property>

<!-- Límites para containers individuales -->
<property>
  <name>yarn.scheduler.maximum-allocation-mb</name>
  <value>12000</value>
  <description>Máximo 12GB por container (evita monopolización)</description>
</property>

<!-- Capacity Scheduler para separar jobs -->
<property>
  <name>yarn.resourcemanager.scheduler.class</name>
  <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler</value>
</property>

<!-- capacity-scheduler.xml -->
<!-- Crear queues separadas -->
<property>
  <name>yarn.scheduler.capacity.root.queues</name>
  <value>spark_job,other_jobs</value>
</property>

<!-- Queue para tu job Spark - MÁXIMO 50% -->
<property>
  <name>yarn.scheduler.capacity.root.spark_job.capacity</name>
  <value>50</value>
  <description>Tu job solo puede usar 50% máximo</description>
</property>

<property>
  <name>yarn.scheduler.capacity.root.spark_job.maximum-capacity</name>
  <value>50</value>
  <description>NUNCA puede exceder 50% aunque esté libre</description>
</property>

<!-- Queue para otros jobs - GARANTIZADO 50% -->
<property>
  <name>yarn.scheduler.capacity.root.other_jobs.capacity</name>
  <value>50</value>
  <description>Otros jobs tienen garantizado 50%</description>
</property>

<property>
  <name>yarn.scheduler.capacity.root.other_jobs.maximum-capacity</name>
  <value>100</value>
  <description>Pueden usar más si spark_job no está activo</description>
</property>
```

---
#### Commandos útiles para la Jupyter:
- Docker image build \
`docker build -t pyspark-notebook:latest .`

- Run jupyter-lab/notebook:
```
╰─± docker run -it --rm -p 8888:8888 -p 4040:4040 -v $(pwd):/home/jovyan/work pyspark-notebook:latest
```


