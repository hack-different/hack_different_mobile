package com.hackdifferent.core

import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals

class EventDatesTest {
    @Test
    fun anInstantShowsLocalDayAndTime() {
        assertEquals("Tue, Nov 10 · 6:05 PM", formatEventStart("2026-11-11T02:05:00Z", ZoneId.of("America/Los_Angeles")))
    }

    @Test
    fun aDateShowsTheDay() {
        assertEquals("Wed, Nov 11", formatEventStart("2026-11-11"))
    }

    @Test
    fun anythingElseIsShownAsItCame() {
        assertEquals("Every Tuesday", formatEventStart("Every Tuesday"))
    }
}
