import json
import unittest

import requests
from pyspark.sql import SparkSession

from dbx_metrics_examples.jobs.metric_reporter.entrypoint import MetricReporterJob


class MetricReporterTest(unittest.TestCase):
    def setUp(self):
        self.spark = (
            SparkSession.builder.master("local[*]")
            .appName("dbx-metrics-test")
            .config("spark.jars", "metrics/target/metrics-0.0.1.jar")
            .config("spark.sql.shuffle.partitions", 2)
            .config("spark.metrics.namespace", "spark")
            .getOrCreate()
        )
        self.job = MetricReporterJob(spark=self.spark)
        self.job.launch(_async=True)

    def test_sample(self):
        self.job.logger.info("Controlling the process in the test thread")
        self.job._wait()
        self.assertGreater(self._get_metric_data("query1"), 0)
        self.assertGreater(self._get_metric_data("query2"), 0)

    def _get_metric_data(self, metric_key):
        web_ui = self.spark.sparkContext.uiWebUrl
        metrics = requests.get(f"{web_ui}/metrics/json/").json().get("gauges")
        self.job.logger.info("Available gauge metrics:")
        self.job.logger.info(json.dumps(metrics))
        metric_key = [
            key for key in metrics.keys() if key.endswith(f"{metric_key}.latency")
        ]
        if not metric_key:
            self.job.logger.error(f"Metric key not found, raw output: {metric_key}")
            self.job.logger.error(f"All available keys: {metrics.keys()}")
            return None
        else:
            return metrics[metric_key[0]].get("value")

    def tearDown(self) -> None:
        for stream in self.spark.streams.active:
            stream.stop()


if __name__ == "__main__":
    unittest.main()
