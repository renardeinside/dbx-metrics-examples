package net.renarde.demos.dbx.metrics

import org.apache.spark.SparkEnv
import org.apache.spark.internal.Logging
import org.apache.spark.metrics.source.{GaugeControl, LatencyMetricSource}

object MetricController extends Logging {
  val metrics: collection.mutable.Map[String, GaugeControl] = collection.mutable.Map.empty

  def getMetric(name: String): GaugeControl = {
    val metricSource = LatencyMetricSource(name)
    SparkEnv.get.metricsSystem.registerSource(metricSource)
    metricSource.control
  }
}



