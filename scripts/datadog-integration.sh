#!/bin/bash

echo "Running on the driver? $DB_IS_DRIVER"
echo "Driver ip: $DB_DRIVER_IP"

cat <<EOF >> /tmp/start_datadog.sh
#!/bin/bash

if [ \$DB_IS_DRIVER ]; then
  echo "On the driver. Installing Datadog ..."

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

  cat << EOT >> /home/ubuntu/databricks/spark/conf/metrics.properties
  *.sink.statsd.host=${DB_DRIVER_IP}
  EOT

  cat << EOC >> /etc/datadog-agent/datadog.yaml
  use_dogstatsd: true
  # bind on all interfaces so it's accessible from executors
  bind_host: 0.0.0.0
  dogstatsd_non_local_traffic: true
  dogstatsd_stats_enable: false
  logs_enabled: false
  cloud_provider_metadata:
    - "aws"
  EOC

  echo "dogstatsd_metrics_stats_enable: false" >> /etc/datadog-agent/datadog.yaml

  # RESTARTING AGENT
  sudo service datadog-agent restart

fi
EOF

# CLEANING UP
if [ \$DB_IS_DRIVER ]; then
  chmod a+x /tmp/start_datadog.sh
  /tmp/start_datadog.sh >> /tmp/datadog_start.log 2>&1 & disown
fi