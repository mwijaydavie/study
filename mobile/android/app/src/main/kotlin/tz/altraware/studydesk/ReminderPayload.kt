package tz.altraware.studydesk

/** Platform-channel contract and delivery rules; no Android types are needed here. */
internal data class ReminderPayload(
    val key: String,
    val target: Long,
    val expires: Long,
    val title: String,
    val body: String,
    val sessionId: String? = null,
    val day: String? = null,
    val lead: Int? = null,
    val revision: String? = null,
    val eventId: String? = null,
) {
    init {
        require(target > 0 && expires > target && title.length in 1..160 && body.length in 1..500)
        if (eventId != null) {
            require(EVENT_ID.matches(eventId) && key == "event:$eventId" && sessionId == null && day == null)
            require((revision?.length ?: 0) in 1..4096)
            if (lead == 0) {
                // An all-day alert starts at 09:00 EAT and expires at EAT midnight.
                require(target % DAY_MS == 6 * 60 * MINUTE_MS && expires - target == 15 * 60 * MINUTE_MS)
            } else {
                require(lead != null && lead in LEADS && expires - target == lead * MINUTE_MS)
            }
        } else if (sessionId == null) {
            require(key == TEST_KEY && day == null && lead == null && revision == null)
            require(expires - target <= 60 * MINUTE_MS)
        } else {
            require(SESSION_ID.matches(sessionId) && day != null && DATE.matches(day))
            require(key == "class:$sessionId:$day" && (revision?.length ?: 0) in 1..1500)
            require(lead != null && lead in LEADS && expires - target == lead * MINUTE_MS)
        }
    }

    val isEvent: Boolean get() = eventId != null

    fun canSchedule(now: Long) = target > now && if (isEvent) {
        target - now <= 365 * DAY_MS
    } else {
        expires - now <= 14 * DAY_MS
    }

    fun isDue(now: Long) = now >= target
    fun isExpired(now: Long) = now >= expires
    fun canDeliver(now: Long, savedBuild: Long, currentBuild: Long) =
        isDue(now) && !isExpired(now) && savedBuild == currentBuild

    fun encode(): Map<String, Any> = buildMap {
        put("key", key)
        put("target", target)
        put("expires", expires)
        put("title", title)
        put("body", body)
        sessionId?.let { put("sessionId", it) }
        eventId?.let { put("eventId", it) }
        day?.let { put("day", it) }
        lead?.let { put("lead", it) }
        revision?.let { put("revision", it) }
    }

    companion object {
        const val TEST_KEY = "test"
        const val MINUTE_MS = 60_000L
        private const val DAY_MS = 24 * 60 * MINUTE_MS
        private val EVENT_ID = Regex("[a-f0-9]{32}")
        private val SESSION_ID = Regex("[a-z0-9_-]{1,80}")
        private val DATE = Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")
        private val LEADS = setOf(5, 15, 30, 60)

        fun decode(map: Map<*, *>) = ReminderPayload(
            key = map["key"] as String,
            target = (map["target"] as Number).toLong(),
            expires = (map["expires"] as Number).toLong(),
            title = map["title"] as String,
            body = map["body"] as String,
            sessionId = map["sessionId"] as? String,
            day = map["day"] as? String,
            lead = (map["lead"] as? Number)?.toInt(),
            revision = map["revision"] as? String,
            eventId = map["eventId"] as? String,
        )
    }
}
