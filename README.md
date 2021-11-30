## Databricks metrics examples


This repository collects examples of working with custom metrics in Spark on Databricks, in particular:

* Adding custom metrics in Scala
* Reporting these custom metrics from Scala and Python
* Visualizing these metrics in Datadog 

### Local development setup

Versions:
* Maven 3.8.3
* Java 1.8
* Python 3.7
* Spark 3.1.2


Python setup:
```
conda create --name dbx_metrics_examples python=3.7
conda activate dbx_metrics_examples
```

### Metrics exposure in Ganglia

After launching the sample job in Python, you can go to the cluster metrics section and search for "latency" metric:

![Alt text](images/ganglia.png "Title")


### Reporting metrics to Datadog 


This is the official integration script used from the Datadog <-> Databricks integration docs. 
However, it might not be up-to-date, so always take a look at the official docs.

1. Add Datadog API Key:
```
databricks secrets create-scope --scope=datadog
databricks secrets put --scope=datadog --key=apiKey --string-value=... # better to read from the file for better security
```

2. Configure the init-script and env variables. `conf/deployment.json` contains an example configuration.