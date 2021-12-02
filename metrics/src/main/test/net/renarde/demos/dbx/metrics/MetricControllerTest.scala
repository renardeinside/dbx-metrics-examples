package net.renarde.demos.dbx.metrics

import org.apache.spark.SparkEnv
import org.apache.spark.sql.SparkSession
import org.scalatest.funsuite.AnyFunSuite

class MetricControllerTest extends AnyFunSuite {

  val spark: SparkSession = SparkSession
    .builder()
    .appName("dbx-metrics-test")
    .master("local[*]")
    .config("spark.sql.shuffle.partitions", 2)
    .config("spark.metrics.namespace", "metrics")
    .config("spark.sql.streaming.metricsEnabled", "true")
    .getOrCreate()

  test("metricController") {
    val sourceName = "testMetric"
    val metricName = "gaugeMetric"
    val testValue = 100
    val testGauge = MetricController.getMetric(sourceName, metricName)
    testGauge.setValue(testValue)
    val gaugeFromMetricSystem = SparkEnv.get.metricsSystem.getSourcesByName(sourceName).head.metricRegistry.getGauges.get(metricName)
    assert(gaugeFromMetricSystem.getValue == testValue)
  }
}
