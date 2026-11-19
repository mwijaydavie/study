package tz.altraware.studydesk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CampusPayloadTest {
    private val day = 1_795_046_400_000L // Nov 19, 2026 00:00 UTC
    private val minute = ReminderPayload.MINUTE_MS
    private val id = "0123456789abcdef0123456789abcdef"
    private val timed = ReminderPayload(
        key = "event:$id",
        target = day + 4 * 60 * minute + 45 * minute,
        expires = day + 5 * 60 * minute,
        title = "Example workshop",
        body = "Workshop · 08:00 EAT",
        lead = 15,
        revision = "revision-1",
        eventId = id,
    )

    @Test
    fun eventCodecChecksIdAndDoesNotAcceptClassOrTestFields() {
        assertTrue(timed.isEvent)
        assertEquals(timed, ReminderPayload.decode(timed.encode()))
        assertThrows(IllegalArgumentException::class.java) { timed.copy(key = "test") }
        assertThrows(IllegalArgumentException::class.java) { timed.copy(eventId = id.uppercase()) }
        assertThrows(IllegalArgumentException::class.java) { timed.copy(sessionId = "thu-is237") }
        assertThrows(IllegalArgumentException::class.java) { timed.copy(day = "2026-11-19") }
        assertThrows(IllegalArgumentException::class.java) { timed.copy(lead = 10) }
        assertThrows(IllegalArgumentException::class.java) { timed.copy(revision = null) }
    }

    @Test
    fun allDayReminderIsFor0900EATUntilMidnightOfFirstDay() {
        val morning = timed.copy(target = day + 6 * 60 * minute, expires = day + 21 * 60 * minute, lead = 0)
        assertFalse(morning.canDeliver(morning.target - 1, 1, 1))
        assertTrue(morning.canDeliver(morning.target, 1, 1))
        assertFalse(morning.canDeliver(morning.expires, 1, 1))
        assertFalse(morning.canDeliver(morning.target, 1, 2))
        assertThrows(IllegalArgumentException::class.java) { morning.copy(expires = morning.expires + minute) }
        assertThrows(IllegalArgumentException::class.java) {
            morning.copy(target = morning.target + minute, expires = morning.expires + minute)
        }
    }

    @Test
    fun futureWindowUsesEventTargetAndLeavesClassWindowBounded() {
        val year = 365 * 24 * 60 * minute
        val classRequest = timed.copy(
            key = "class:thu-is237:2026-11-19", eventId = null, sessionId = "thu-is237", day = "2026-11-19",
        )
        assertTrue(timed.canSchedule(timed.target - year))
        assertFalse(timed.canSchedule(timed.target - year - 1))
        assertFalse(timed.canSchedule(timed.target))
        assertFalse(classRequest.canSchedule(timed.target - year))
        assertTrue(classRequest.canSchedule(timed.target - minute))
    }

    @Test
    fun calendarDraftUsesUtcDayBoundariesAndTimedInstantsAreNotShifted() {
        val tomorrow = day + 24 * 60 * minute
        val allDay = CalendarDraft("Test event", "", day, tomorrow, true)
        assertEquals("UTC", allDay.timeZone)
        assertEquals(allDay, CalendarDraft.decode(mapOf(
            "title" to "Test event", "venue" to "", "begin" to day, "end" to tomorrow, "allDay" to true,
        )))
        assertThrows(IllegalArgumentException::class.java) {
            allDay.copy(begin = day - 3 * 60 * minute) // This is EAT midnight, not a date-only boundary.
        }
        assertThrows(IllegalArgumentException::class.java) { allDay.copy(end = null) }
        assertThrows(IllegalArgumentException::class.java) { allDay.copy(end = day) }
        val withTime = CalendarDraft("Test event", "Room 1", day - 3 * 60 * minute + 10 * minute, null, false)
        assertEquals("Africa/Dar_es_Salaam", withTime.timeZone)
        assertEquals(day - 170 * minute, withTime.begin) // 00:10 EAT starts on the previous UTC date.
    }
}
