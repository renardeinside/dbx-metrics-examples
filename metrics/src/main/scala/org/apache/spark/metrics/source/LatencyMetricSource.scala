package org.apache.spark.metrics.source

import com.codahale.metrics.MetricRegistry

case class LatencyMetricSource(metricName: String, gaugeName: String) extends Source {

  val control = new GaugeControl

  override val sourceName: String = metricName

  override val metricRegistry: MetricRegistry = new MetricRegistry

  metricRegistry.gauge(gaugeName, () => control.gauge)
}
