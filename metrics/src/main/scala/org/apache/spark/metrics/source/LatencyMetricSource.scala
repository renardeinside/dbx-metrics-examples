package org.apache.spark.metrics.source

import com.codahale.metrics.MetricRegistry

case class LatencyMetricSource(name: String) extends Source {

  val control = new GaugeControl

  override val sourceName: String = name

  override val metricRegistry: MetricRegistry = new MetricRegistry

  metricRegistry.gauge("latency", () => control.gauge)
}
