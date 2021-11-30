#!/bin/bash

echo "Running on the driver? $DB_IS_DRIVER"
echo "Driver ip: $DB_DRIVER_IP"

cat <<EOF >> /tmp/start_datadog.sh
#!/bin/bash

if [ \$DB_IS_DRIVER ]; then
  echo "On the driver. Installing Datadog ..."

  cat >/databricks/driver/conf/custom-spark-metrics-name-conf.conf <<EOL
  [driver] {
    spark.metrics.namespace = "${CLUSTER_NAME}"
    spark.sql.streaming.metricsEnabled = "true"
  }
  EOL

  sudo sed -i '/^driver.sink.ganglia.class/,+4 s/^/#/g' /databricks/spark/conf/metrics.properties
  sudo bash -c "cat <<EOF >> /databricks/spark/conf/metrics.properties
  *.sink.statsd.class=org.apache.spark.metrics.sink.StatsdSink
  *.sink.statsd.host=127.0.0.1
  *.sink.statsd.port=8125
  *.sink.statsd.prefix=spark_metrics
  *.sink.statsd.host.unit=seconds
  *.sink.statsd.host.period=1

  master.source.jvm.class=org.apache.spark.metrics.source.JvmSource
  worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource
  driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource
  executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource
  EOF"

  # CONFIGURE HOST TAGS FOR DRIVER
  DD_TAGS="environment:\${DD_ENV}","databricks_cluster_id:\${DB_CLUSTER_ID}","databricks_cluster_name:\${DB_CLUSTER_NAME}","spark_host_ip:\${SPARK_LOCAL_IP}","spark_node:driver"

  # INSTALL THE LATEST DATADOG AGENT 7 ON DRIVER AND WORKER NODES
  DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=\$DD_API_KEY DD_HOST_TAGS=\$DD_TAGS bash -c "\$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

  # WAIT FOR DATADOG AGENT TO BE INSTALLED
  while [ -z \$datadoginstalled ]; do
    if [ -e "/etc/datadog-agent/datadog.yaml" ]; then
      datadoginstalled=TRUE
    fi
    sleep 2
  done
  echo "Datadog Agent is installed"

  # ENABLE LOGS IN datadog.yaml TO COLLECT DRIVER LOGS
  echo "logs_enabled: true" >> /etc/datadog-agent/datadog.yaml
  echo "use_dogstatsd: true" >> /etc/datadog-agent/datadog.yaml
  echo "collect_ec2_tags: yes" >> /etc/datadog-agent/datadog.yaml
  echo "dogstatsd_port: 8125" >> /etc/datadog-agent/datadog.yaml

  while [ -z \$gotparams ]; do
    if [ -e "/tmp/driver-env.sh" ]; then
      DB_DRIVER_PORT=\$(grep -i "CONF_UI_PORT" /tmp/driver-env.sh | cut -d'=' -f2)
      gotparams=TRUE
    fi
    sleep 2
  done

  current=\$(hostname -I | xargs)

  # WRITING SPARK CONFIG FILE
  echo "init_config:
instances:
    - spark_url: http://\$DB_DRIVER_IP:\$DB_DRIVER_PORT
      spark_cluster_mode: spark_driver_mode
      cluster_name: \$current
      streaming_metrics: true
logs:
    - type: file
      path: /databricks/driver/logs/*.log
      source: spark
      service: databricks
      log_processing_rules:
        - type: multi_line
          name: new_log_start_with_date
          pattern: \d{2,4}[\-\/]\d{2,4}[\-\/]\d{2,4}.*" > /etc/datadog-agent/conf.d/spark.yaml

  # RESTARTING AGENT
  sudo service datadog-agent restart

fi
EOF

# CLEANING UP
if [ \$DB_IS_DRIVER ]; then
  chmod a+x /tmp/start_datadog.sh
  /tmp/start_datadog.sh >> /tmp/datadog_start.log 2>&1 & disown
fi