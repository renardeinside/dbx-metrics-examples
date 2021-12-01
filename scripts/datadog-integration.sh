#!/bin/bash

echo "Running on the driver? $DB_IS_DRIVER"

if [[ $DB_IS_DRIVER = "TRUE" ]]; then
  echo "Driver ip: $DB_DRIVER_IP"

  # modify driver config
  sudo bash -c "cat <<EOF >> /databricks/driver/conf/custom-spark-metrics-name-conf.conf
[driver] {
  spark.metrics.namespace = metrics
  spark.sql.streaming.metricsEnabled = true
}
EOF"

  #modify metrics config
  sudo bash -c "cat <<EOF >> /databricks/spark/conf/metrics.properties
*.sink.statsd.class=org.apache.spark.metrics.sink.StatsdSink
*.sink.statsd.host=localhost
*.sink.statsd.port=8125
*.sink.statsd.prefix=spark

master.source.jvm.class=org.apache.spark.metrics.source.JvmSource
worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource
driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource
executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource
EOF"

  #INSTALL DATADOG AGENT
  DD_TAGS="environment:${DD_ENV},databricks_cluster_id:${DB_CLUSTER_ID},spark_host_ip:${SPARK_LOCAL_IP}, spark_node:driver"

  DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$DD_API_KEY DD_HOST_TAGS=$DD_TAGS bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

  # WAIT FOR DATADOG AGENT TO BE INSTALLED
  while [ -z "$datadog_installed" ]; do
    if [ -e "/etc/datadog-agent/datadog.yaml" ]; then
      datadog_installed=TRUE
    fi
    sleep 2
  done
  echo "Datadog Agent is installed"

  sudo bash -c "cat <<EOF >> /etc/datadog-agent/datadog.yaml
use_dogstatsd: true
# bind on all interfaces so it's accessible from executors
bind_host: 0.0.0.0
dogstatsd_non_local_traffic: true
dogstatsd_stats_enable: false
logs_enabled: true
EOF"

  #CONFIGURE ADDITIONAL SPARK METRICS AND LOGS
  sudo bash -c "cat <<EOF >> /etc/datadog-agent/conf.d/spark.yaml
init_config:

logs:
    - type: file
      path: /databricks/driver/logs/*.log
      source: spark
      service: databricks
      log_processing_rules:
        - type: multi_line
          name: new_log_start_with_date
          pattern: \d{2,4}[\-\/]\d{2,4}[\-\/]\d{2,4}.*
EOF"

  #START THE AGENT
  sudo service datadog-agent restart

fi