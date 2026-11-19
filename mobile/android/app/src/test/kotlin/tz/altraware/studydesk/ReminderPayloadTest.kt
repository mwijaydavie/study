package tz.altraware.studydesk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderPayloadTest {
    private val lead = 15
    private val target = 1_795_063_500_000L
    private val reminder = ReminderPayload(
        key = "class:thu-is237:2026-11-19",
        target = target,
        expires = target + lead * ReminderPayload.MINUTE_MS,
        title = "IS237",
        body = "08:00 EAT · Computer Lab",
        sessionId = "thu-is237",
        day = "2026-11-19",
        lead = lead,
        revision = "revision-1",
    )

    @Test
    fun codecRoundTripAndStableKeyAfterEditing() {
        assertEquals(reminder, ReminderPayload.decode(reminder.encode()))
        val edited = reminder.copy(target = reminder.expires - 30 * ReminderPayload.MINUTE_MS, lead = 30)
        assertEquals(reminder.key, edited.key)
        assertFalse(edited.target == reminder.target)
    }

    @Test
    fun inexactDeliveryExpiresAtClassStartAndCannotSurviveAnUnreconciledUpdate() {
        assertFalse(reminder.canDeliver(target - 1, 1, 1))
        assertTrue(reminder.canDeliver(target, 1, 1))
        assertTrue(reminder.canDeliver(reminder.expires - 1, 1, 1))
        assertFalse(reminder.canDeliver(reminder.expires, 1, 1))
        assertFalse(reminder.canDeliver(target, 1, 2))
    }

    @Test
    fun rejectsWrongIdentityOrLeadAndKeepsTestsSeparate() {
        assertThrows(IllegalArgumentException::class.java) { reminder.copy(key = "test") }
        assertThrows(IllegalArgumentException::class.java) { reminder.copy(lead = 10) }
        assertThrows(IllegalArgumentException::class.java) { reminder.copy(day = "2026-11-26") }
        val test = ReminderPayload("test", target, target + ReminderPayload.MINUTE_MS, "Test", "Test")
        assertEquals(test, ReminderPayload.decode(test.encode()))
    }
}
