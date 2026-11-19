package tz.altraware.studydesk

/** Calendar extras, not a direct calendar provider write. */
internal data class CalendarDraft(
    val title: String,
    val venue: String,
    val begin: Long,
    val end: Long?,
    val allDay: Boolean,
) {
    init {
        require(title.isNotBlank() && title.length <= 120 && venue.length <= 120)
        require(begin > 0 && (end == null || end > begin))
        if (allDay) {
            // Android all-day values are UTC date boundaries, not EAT midnight instants.
            require(begin % DAY_MS == 0L && end != null && end % DAY_MS == 0L)
        }
    }

    val timeZone: String get() = if (allDay) "UTC" else "Africa/Dar_es_Salaam"

    companion object {
        private const val DAY_MS = 86_400_000L

        fun decode(map: Map<*, *>) = CalendarDraft(
            title = map["title"] as String,
            venue = map["venue"] as String,
            begin = (map["begin"] as Number).toLong(),
            end = (map["end"] as? Number)?.toLong(),
            allDay = map["allDay"] as Boolean,
        )
    }
}
