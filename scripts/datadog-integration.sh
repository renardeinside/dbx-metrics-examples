#!/bin/bash

# echo "Running on the driver? $DB_IS_DRIVER"
# echo "Driver ip: $DB_DRIVER_IP"

# Get the cluster name
CLUSTER_NAME=$DB_CLUSTER_NAME

if [ -z "$CLUSTER_NAME" ]
then
      echo "\$CLUSTER_NAME is empty"
      CLUSTER_NAME="pool"
else
      echo "\$CLUSTER_NAME is NOT empty"
fi

CLUSTER_NAME=$CLUSTER_NAME-$DB_CLUSTER_ID

# Set spark.metrics.namespace
cat >/databricks/driver/conf/custom-spark-metrics-name-conf.conf <<EOL
[driver] {
  spark.metrics.namespace = "${CLUSTER_NAME}"
  spark.sql.streaming.metricsEnabled = "true"
}
EOL

#modify metrics config
#Leave host.period to 1 second to get all metrics
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

cat <<EOF >> /tmp/start_datadog.sh
#!/bin/bash
sudo apt-get install jq

CLUSTER_NAME=$CLUSTER_NAME

echo $DB_IS_DRIVER
if [[ $DB_IS_DRIVER = "TRUE" ]]; then
  echo "On the driver. Installing Datadog ..."

  # install the Datadog agent
  DD_AGENT_MAJOR_VERSION=6 bash -c "\$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)"

# USING stashd FOR SPARK METRICS
echo "#using stashd
use_dogstatsd: true
collect_ec2_tags: yes
tags: ["driver:$CLUSTER_NAME", "sparknodetype:driver", "sparknodeip:$DB_DRIVER_IP", "dbclustername:$CLUSTER_NAME"]

dogstatsd_port: 8125" >> /etc/datadog-agent/datadog.yaml

  # RESTARTING AGENT
  sudo service datadog-agent restart

else
  echo "On the Executor. Installing Datadog ..."

  # install the Datadog agent
  DD_AGENT_MAJOR_VERSION=6 bash -c "\$(curl -L https://raw.githubusercontent.com/DataDog/datadog-agent/master/cmd/agent/install_script.sh)"

# USING stashd FOR SPARK METRICS
echo "#using stashd
use_dogstatsd: true
collect_ec2_tags: yes
tags: ["executor:$CLUSTER_NAME", "sparknodetype:executors","dbclustername:$CLUSTER_NAME"]

dogstatsd_port: 8125" >> /etc/datadog-agent/datadog.yaml

  # RESTARTING AGENT
  sudo service datadog-agent restart

fi
EOF

# CLEANING UP
chmod a+x /tmp/start_datadog.sh
/tmp/start_datadog.sh >> /tmp/datadog_start.log 2>&1 & disown