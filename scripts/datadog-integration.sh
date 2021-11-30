#!/bin/bash

echo "Running on the driver? $DB_IS_DRIVER"

if [[ $DB_IS_DRIVER = "TRUE" ]]; then
  echo "Driver ip: $DB_DRIVER_IP"

  #modify metrics config
  sudo sed -i '/^driver.sink.ganglia.class/,+4 s/^/#/g' /databricks/spark/conf/metrics.properties
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

  #FIND THE SPARK UI PORT ON DRIVER
  while [ -z "$gotparams" ]; do
    if [ -e "/tmp/driver-env.sh" ]; then
      DB_DRIVER_PORT=$(grep -i "CONF_UI_PORT" /tmp/driver-env.sh | cut -d'=' -f2)
      gotparams=TRUE
    fi
    sleep 2
  done

  current=$(hostname -I | xargs)

  #CONFIGURE ADDITIONAL SPARK METRICS AND LOGS
  sudo bash -c "cat <<EOF >> /etc/datadog-agent/conf.d/spark.yaml
init_config:
  instances:
      - spark_url: http://$DB_DRIVER_IP:$DB_DRIVER_PORT
        spark_cluster_mode: spark_driver_mode
        cluster_name: $current
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
  sudo service datadog-agent start

fi