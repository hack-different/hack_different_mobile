package com.hackdifferent.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val dayFormat = DateTimeFormatter.ofPattern("EEE, MMM d", Locale.US)
private val dayTimeFormat = DateTimeFormatter.ofPattern("EEE, MMM d · h:mm a", Locale.US)

/**
 * An event's start for display: "Tue, Nov 10 · 6:05 PM" in [zone] for an ISO 8601 instant, "Tue, Nov 10" for a
 * date alone, and the text as it came for anything else.
 */
public fun formatEventStart(start: String, zone: ZoneId = ZoneId.systemDefault()): String =
    runCatching { Instant.parse(start).atZone(zone).format(dayTimeFormat) }.getOrNull()
        ?: runCatching { LocalDate.parse(start).format(dayFormat) }.getOrNull()
        ?: start
