package net.renarde.demos.dbx.metrics

import org.apache.spark.SparkEnv
import org.apache.spark.internal.Logging
import org.apache.spark.metrics.source.{GaugeControl, LatencyMetricSource}

object MetricController extends Logging {

  def getMetric(metricName: String, gaugeName: String): GaugeControl = {
    val metricSource = LatencyMetricSource(metricName, gaugeName)
    SparkEnv.get.metricsSystem.registerSource(metricSource)
    metricSource.control
  }
}



