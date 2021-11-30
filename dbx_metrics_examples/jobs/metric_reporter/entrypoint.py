import datetime as dt
import pathlib
import time

import pandas as pd
import pyspark.sql.functions as F
from faker import Faker
from pyspark.sql import DataFrame
from pyspark.sql.streaming import StreamingQuery
from pyspark.sql.types import TimestampType

from dbx_metrics_examples.common import Job


class MetricReporter:
    def __init__(self, spark, name):  # noqa
        self._metric = (
            spark._jvm.net.renarde.demos.dbx.metrics.MetricController.getMetric(  # noqa
                name
            )
        )
        self.name = name

    def update(self, value: int):
        self._metric.setValue(value)


class MetricReporterJob(Job):
    fake = Faker()

    TIMEOUT_SECONDS = 60 * 5

    def __init__(self, spark=None, init_conf=None):
        super().__init__(spark, init_conf)
        self._random_timestamp_udf = F.udf(self.random_timestamp, TimestampType())

    @classmethod
    def random_timestamp(cls) -> dt.datetime:
        return cls.fake.date_time_this_month()

    def _wait(self, seconds: int = 10):
        self.logger.info(f"Waiting in the main thread for {seconds} seconds")
        time.sleep(seconds)
        self.logger.info(f"Waiting in the main thread for {seconds} seconds - finished")

    def get_query(self, name: str) -> StreamingQuery:
        metric = MetricReporter(self.spark, name)
        stream = (
            self.spark.readStream.format("rate")
            .option("rowsPerSecond", 100)
            .load()
            .withColumn("event_timestamp", self._random_timestamp_udf())
        )

        def batch_processor(batch: DataFrame, _):
            batch_ts = (
                batch.agg(F.max("event_timestamp").alias("max_ts"))
                .toPandas()
                .loc[0, "max_ts"]
            )
            if not pd.isnull(batch_ts):
                current_ts = dt.datetime.now()
                latency = int((current_ts - batch_ts).total_seconds())
                metric.update(latency)

        query = (
            stream.writeStream.foreachBatch(batch_processor)
            .queryName(name)
            .trigger(processingTime="5 seconds")
            .start()
        )
        return query

    def launch(self, _async: bool = False):
        self.logger.info("Launching metric reporter job")
        self.get_query("query1")
        self.get_query("query2")

        if not _async:
            self.logger.info(f"Waiting for the timeout {self.TIMEOUT_SECONDS}")
            time.sleep(self.TIMEOUT_SECONDS)
            self.logger.info("Await finished, gracefully stopping the streams")
            for stream in self.spark.streams.active:
                stream.stop()

        self.logger.info("Metric reporter job gracefully finished")


if __name__ == "__main__":
    job = MetricReporterJob()
    job.launch()
