package org.apache.spark.metrics.source

import com.codahale.metrics.Gauge

import java.util.concurrent.atomic.AtomicLong

class GaugeControl extends Serializable {

  // we use atomic long here to avoid issues while setting the value in multi threaded environments
  private val valueRef = new AtomicLong()

  def setValue(newValue: Long): Unit = {
    valueRef.set(newValue)
  }

  private[source] val gauge: Gauge[Long] = new Gauge[Long] {
    override def getValue: Long = GaugeControl.this.valueRef.longValue()
  }
}

