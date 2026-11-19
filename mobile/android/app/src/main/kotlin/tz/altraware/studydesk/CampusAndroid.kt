package tz.altraware.studydesk

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

internal object CampusAndroid {
    private const val STORE = "studydesk.campus_events.v1"
    private const val SNAPSHOT = "snapshot"
    private const val SCHEMA_VERSION = 1

    private fun prefs(context: Context) = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "readEvents" -> result.success(prefs(activity).getString(SNAPSHOT, null))
                "writeEvents" -> {
                    val raw = call.arguments as String
                    require(raw.length <= 1_500_000)
                    val json = JSONObject(raw)
                    require(json.getInt("version") == SCHEMA_VERSION && json.getJSONArray("items").length() <= 100)
                    // Complete this private disk write before Dart queues a new notification.
                    val store = prefs(activity)
                    val previous = store.getString(SNAPSHOT, null)
                    if (!store.edit().putString(SNAPSHOT, raw).commit()) {
                        // commit() may have changed the process cache even when the disk failed.
                        store.edit().putString(SNAPSHOT, previous).commit()
                        error("Campus storage write failed")
                    }
                    result.success(null)
                }
                "addToCalendar" -> result.success(openCalendar(activity, CalendarDraft.decode(call.arguments as Map<*, *>)))
                "openSource" -> {
                    val source = Uri.parse(call.arguments as String)
                    require(source.scheme == "https" && !source.host.isNullOrBlank() && source.userInfo.isNullOrEmpty())
                    result.success(launch(activity, Intent(Intent.ACTION_VIEW, source).addCategory(Intent.CATEGORY_BROWSABLE)))
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("campus_unavailable", "Could not complete the campus event action.", null)
        }
    }

    private fun openCalendar(activity: Activity, draft: CalendarDraft): Boolean {
        val intent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
            .putExtra(CalendarContract.Events.TITLE, draft.title)
            .putExtra(CalendarContract.Events.EVENT_LOCATION, draft.venue)
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, draft.begin)
            .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, draft.allDay)
            .putExtra(CalendarContract.Events.EVENT_TIMEZONE, draft.timeZone)
        draft.end?.let { intent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, it) }
        // No READ/WRITE_CALENDAR and no assumption that the editor saved the event.
        return launch(activity, intent)
    }

    private fun launch(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    }
}
