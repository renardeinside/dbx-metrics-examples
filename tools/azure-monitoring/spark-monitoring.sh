#!/bin/bash

set -e
set -o pipefail

# These environment variables would normally be set by Spark scripts
# However, for a Databricks init script, they have not been set yet.
# We will keep the names the same here, but not export them.
# These must be changed if the associated Spark environment variables
# are changed.
DB_HOME=/databricks
SPARK_HOME=$DB_HOME/spark
SPARK_CONF_DIR=$SPARK_HOME/conf

# Add your Log Analytics Workspace information below so all clusters use the same
# Log Analytics Workspace
tee -a "$SPARK_CONF_DIR/spark-env.sh" << EOF
export DB_CLUSTER_ID=$DB_CLUSTER_ID
LOG_ANALYTICS_WORKSPACE_ID=$LOG_ANALYTICS_WORKSPACE_ID
LOG_ANALYTICS_WORKSPACE_KEY=$LOG_ANALYTICS_WORKSPACE_KEY
EOF

STAGE_DIR=/dbfs/databricks/spark-monitoring
SPARK_LISTENERS_VERSION=${SPARK_LISTENERS_VERSION:-1.0.0}
SPARK_LISTENERS_LOG_ANALYTICS_VERSION=${SPARK_LISTENERS_LOG_ANALYTICS_VERSION:-1.0.0}
SPARK_VERSION=$(cat /databricks/spark/VERSION 2> /dev/null || echo "")
SPARK_VERSION=${SPARK_VERSION:-2.4.3}
SPARK_SCALA_VERSION=$(sed -n "s/\s*spark.databricks.clusterUsageTags.sparkVersion\s*=\s*\"\([^\"]*\)\"/\1/p" /databricks/common/conf/deploy.conf | \
sed -n "s/.*scala\(.*\)/\1/p")
SPARK_SCALA_VERSION=${SPARK_SCALA_VERSION:-2.11}


# This variable configures the spark-monitoring library metrics sink.
# Any valid Spark metric.properties entry can be added here as well.
# It will get merged with the metrics.properties on the cluster.
METRICS_PROPERTIES=$(cat << EOF
# This will enable the sink for all of the instances.
*.sink.loganalytics.class=org.apache.spark.metrics.sink.loganalytics.LogAnalyticsMetricsSink
*.sink.loganalytics.period=5
*.sink.loganalytics.unit=seconds

# Enable JvmSource for instance master, worker, driver and executor
master.source.jvm.class=org.apache.spark.metrics.source.JvmSource

worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource

driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource

executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource

EOF
)

echo "Copying Spark Monitoring jars"
JAR_FILENAME="spark-listeners_${SPARK_VERSION}_${SPARK_SCALA_VERSION}-${SPARK_LISTENERS_VERSION}.jar"
echo "Copying $JAR_FILENAME"
cp -f "$STAGE_DIR/$JAR_FILENAME" /mnt/driver-daemon/jars
JAR_FILENAME="spark-listeners-loganalytics_${SPARK_VERSION}_${SPARK_SCALA_VERSION}-${SPARK_LISTENERS_LOG_ANALYTICS_VERSION}.jar"
echo "Copying $JAR_FILENAME"
cp -f "$STAGE_DIR/$JAR_FILENAME" /mnt/driver-daemon/jars
echo "Copied Spark Monitoring jars successfully"

echo "Merging metrics.properties"
echo "$(echo "$METRICS_PROPERTIES"; cat "$SPARK_CONF_DIR/metrics.properties")" > "$SPARK_CONF_DIR/metrics.properties" || { echo "Error writing metrics.properties"; exit 1; }
echo "Merged metrics.properties successfully"

# This will enable master/worker metrics
cat << EOF >> "$SPARK_CONF_DIR/spark-defaults.conf"
spark.metrics.conf ${SPARK_CONF_DIR}/metrics.properties
EOF

log4jDirectories=( "executor" "driver" "master-worker" )
for log4jDirectory in "${log4jDirectories[@]}"
do

LOG4J_CONFIG_FILE="$SPARK_HOME/dbconf/log4j/$log4jDirectory/log4j.properties"
echo "BEGIN: Updating $LOG4J_CONFIG_FILE with Log Analytics appender"
sed -i 's/log4j.rootCategory=.*/&, logAnalyticsAppender/g' ${LOG4J_CONFIG_FILE}
tee -a ${LOG4J_CONFIG_FILE} << EOF
# logAnalytics
log4j.appender.logAnalyticsAppender=com.microsoft.pnp.logging.loganalytics.LogAnalyticsAppender
log4j.appender.logAnalyticsAppender.filter.spark=com.microsoft.pnp.logging.SparkPropertyEnricher
EOF
echo "END: Updating $LOG4J_CONFIG_FILE with Log Analytics appender"

echo "BEGIN: Updating $LOG4J_CONFIG_FILE with PublicFile (DBFS) appender"
tee -a ${LOG4J_CONFIG_FILE} << EOF
# dbfs
log4j.appender.publicFile.layout.ConversionPattern=[%p][%d{yy/MM/dd HH:mm:ss}][%c][%m]%n

log4j.logger.org.spark_project.jetty.server=ERROR
log4j.logger.org.apache.spark.storage.memory.MemoryStore=ERROR
log4j.logger.org.apache.spark.storage.BlockManager=ERROR

log4j.logger.org.apache.spark.executor.Executor=ERROR
log4j.logger.org.apache.spark.ContextCleaner=ERROR
log4j.logger.org.apache.spark.sql.execution.streaming=ERROR
log4j.logger.org.apache.spark.scheduler.TaskSetManager=ERROR
log4j.logger.org.spark-project.jetty=WARN
log4j.logger.org.spark-project.jetty.util.component.AbstractLifeCycle=ERROR
log4j.logger.org.apache.spark.repl.SparkIMain$exprTyper=INFO
log4j.logger.org.apache.spark.repl.SparkILoop$SparkILoopInterpreter=INFO
log4j.logger.org.apache.parquet=ERROR
log4j.logger.parquet=ERROR

log4j.logger.org.apache.hadoop.hive.metastore.RetryingHMSHandler=FATAL
log4j.logger.org.apache.hadoop.hive.ql.exec.FunctionRegistry=ERROR
log4j.logger.org.apache.spark.scheduler.DAGScheduler=WARN
log4j.logger.shaded.databricks.org.apache.hadoop.fs.azure=ERROR
log4j.logger.shaded.databricks.org.apache.hadoop.fs.azure=ERROR
log4j.logger.com.databricks.tahoe=WARN
log4j.logger.SessionState=WARN
log4j.logger.org.apache.spark.SparkContext=ERROR
log4j.logger.org.apache.spark.sql.execution=ERROR
log4j.logger.com.databricks=ERROR
log4j.logger.com.zaxxer.hikari.HikariDataSource=ERROR
log4j.logger.org.apache.spark.SparkConf=ERROR
log4j.logger.org.apache.spark.SecurityManager=ERROR
log4j.logger.org.apache.spark.util=ERROR
log4j.logger.org.apache.spark.SparkEnv=ERROR
log4j.logger.org.apache.spark.storage=ERROR
log4j.logger.org.apache.spark.metrics.MetricsSystem=ERROR
log4j.logger.org.eclipse.jetty=ERROR
log4j.logger.org.apache.spark.ui.SparkUI=ERROR
log4j.logger.com.amazonaws.util.EC2MetadataUtils=FATAL
log4j.logger.org.apache.spark.sql.hive=ERROR
log4j.logger.org.apache.hadoop.hive=ERROR
log4j.logger.org.apache.spark.scheduler=ERROR
log4j.logger.org.apache.spark.deploy.client=ERROR
log4j.logger.org.apache.spark.network=ERROR
log4j.logger.org.apache.spark.sql.internal=ERROR
log4j.logger.shaded.v9_4.org.eclipse.jetty=ERROR
log4j.logger.shaded.v9_4.org.eclipse.jetty=ERROR
log4j.logger.org.apache.hadoop.conf=ERROR
log4j.logger.org.apache.spark.deploy=ERROR
log4j.logger.org.apache.spark.deploy=ERROR
log4j.logger.org.apache.spark.sql.catalyst=ERROR
log4j.logger.DataNucleus=ERROR
log4j.logger.org.apache.spark.eventhubs=ERROR
log4j.logger.org.apache.spark.sql.eventhubs=ERROR
log4j.logger.com.microsoft.azure.eventhubs=ERROR
log4j.logger.org.apache.spark.MapOutputTrackerMasterEndpoint=ERROR
log4j.logger.org.apache.spark.rdd=ERROR
EOF
echo "END: Updating $LOG4J_CONFIG_FILE with PublicFile (DBFS) appender"

done

# The spark.extraListeners property has an entry from Databricks by default.
# We have to read it here because we did not find a way to get this setting when the init script is running.
# If Databricks changes the default value of this property, it needs to be changed here.
cat << EOF > "$DB_HOME/driver/conf/00-custom-spark-driver-defaults.conf"
[driver] {
    "spark.extraListeners" = "com.databricks.backend.daemon.driver.DBCEventLoggingListener,org.apache.spark.listeners.UnifiedSparkListener"
    "spark.unifiedListener.sink" = "org.apache.spark.listeners.sink.loganalytics.LogAnalyticsListenerSink"
}
EOF
