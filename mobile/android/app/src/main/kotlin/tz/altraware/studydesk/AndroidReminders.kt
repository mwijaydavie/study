package tz.altraware.studydesk

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject

internal object AndroidReminders {
    const val CHANNEL = "studydesk.class_reminders.v1"
    // Keep the existing intent and channel IDs across upgrades.
    const val OPEN_REMINDER = "tz.altraware.studydesk.OPEN_CLASS_REMINDER"
    private const val DELIVERY = "tz.altraware.studydesk.DELIVER_CLASS_REMINDER"
    private const val STORE = "studydesk.class_reminders.v1"
    private const val PREFIX = "request."
    private const val ASKED = "notificationPermissionAsked"
    private const val CLASS_CAPACITY = 25 // Two weeks of classes plus one delayed test.
    private const val EVENT_CAPACITY = 32
    private const val NOTIFICATION_ID = 1 // Android identifies notifications by tag *and* ID.

    private data class Saved(val request: ReminderPayload, val build: Long)

    private fun prefs(context: Context) = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun notifications(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun alarms(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    @Suppress("DEPRECATION")
    private fun appBuild(context: Context) = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime

    fun access(context: Context): String {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return if (prefs(context).getBoolean(ASKED, false)) "denied" else "notAsked"
        }
        val manager = notifications(context)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return "blocked"
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return "blocked"
        return "allowed"
    }

    fun markPermissionAsked(context: Context) {
        check(prefs(context).edit().putBoolean(ASKED, true).commit())
    }

    fun settingsIntent(context: Context): Intent {
        if (Build.VERSION.SDK_INT >= 26) {
            val channelBlocked = notifications(context).getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE
            return if (channelBlocked) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL)
            } else {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        }
        return appDetailsIntent(context)
    }

    fun appDetailsIntent(context: Context) = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            notifications(context).createNotificationChannel(NotificationChannel(CHANNEL, "StudyDesk reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Class and campus event reminders and test notifications set in StudyDesk."
            })
        }
    }

    private fun decode(raw: String?): Saved? = raw?.let {
        runCatching {
            val json = JSONObject(it)
            val fields = json.keys().asSequence().associateWith { name -> json.get(name) }
            Saved(ReminderPayload.decode(fields), json.getLong("appBuild"))
        }.getOrNull()
    }

    private fun read(context: Context, key: String) =
        decode(prefs(context).getString(PREFIX + key, null))?.takeIf { it.request.key == key }

    private fun all(context: Context) = prefs(context).all.entries.mapNotNull { (key, value) ->
        if (key.startsWith(PREFIX)) decode(value as? String)?.takeIf { PREFIX + it.request.key == key } else null
    }

    private fun save(context: Context, saved: Saved) {
        val json = JSONObject(saved.request.encode()).put("appBuild", saved.build)
        check(prefs(context).edit().putString(PREFIX + saved.request.key, json.toString()).commit())
    }

    private fun forget(context: Context, key: String) {
        check(prefs(context).edit().remove(PREFIX + key).commit())
    }

    private fun uri(which: String, key: String) = Uri.Builder().scheme("studydesk-reminder").authority(which).appendPath(key).build()
    private val immutable: Int get() = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0

    private fun deliveryIntent(context: Context, key: String, flags: Int): PendingIntent? {
        val intent = Intent(context, ReminderReceiver::class.java).setAction(DELIVERY).setData(uri("deliver", key))
        return PendingIntent.getBroadcast(context, 0, intent, flags or immutable)
    }

    private fun arm(context: Context, request: ReminderPayload) {
        val token = checkNotNull(deliveryIntent(context, request.key, PendingIntent.FLAG_UPDATE_CURRENT))
        // Inexact and subject to Android power/batching restrictions. No exact
        // alarm access, full-screen intent, foreground service or polling.
        try {
            if (Build.VERSION.SDK_INT >= 23) {
                alarms(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, request.target, token)
            } else {
                alarms(context).set(AlarmManager.RTC_WAKEUP, request.target, token)
            }
        } catch (failure: Exception) {
            token.cancel()
            throw failure
        }
    }

    private fun disarm(context: Context, key: String) {
        val token = deliveryIntent(context, key, PendingIntent.FLAG_NO_CREATE) ?: return
        alarms(context).cancel(token)
        token.cancel()
    }

    fun schedule(context: Context, request: ReminderPayload) {
        val now = System.currentTimeMillis()
        check(access(context) == "allowed")
        require(request.canSchedule(now))
        val previous = read(context, request.key)
        val capacity = if (request.isEvent) EVENT_CAPACITY else CLASS_CAPACITY
        require(all(context).count {
            it.request.key != request.key && it.request.isEvent == request.isEvent && !it.request.isExpired(now)
        } < capacity)
        createChannel(context)
        save(context, Saved(request, appBuild(context)))
        try {
            arm(context, request)
        } catch (failure: Exception) {
            if (previous == null) {
                forget(context, request.key)
            } else {
                save(context, previous)
                if (previous.request.canSchedule(System.currentTimeMillis()) && previous.build == appBuild(context)) {
                    runCatching { arm(context, previous.request) }
                }
            }
            throw failure
        }
    }

    fun cancel(context: Context, key: String) {
        forget(context, key) // An already-dispatched broadcast must also see the cancellation.
        disarm(context, key)
        notifications(context).cancel(key, NOTIFICATION_ID)
    }

    fun cancelClassReminders(context: Context) {
        for (saved in all(context)) {
            if (!saved.request.isEvent) cancel(context, saved.request.key)
        }
    }

    fun snapshot(context: Context): Map<String, Any> {
        val now = System.currentTimeMillis()
        val access = access(context)
        val saved = all(context).filterNot { it.request.isExpired(now) }
        val build = appBuild(context)
        val queuedEvents = if (access == "allowed") saved.filter {
            it.request.isEvent && it.build == build &&
                deliveryIntent(context, it.request.key, PendingIntent.FLAG_NO_CREATE) != null
        }.map { it.request.key } else emptyList()
        return mapOf(
            "access" to access,
            "pending" to saved.map { it.request.encode() },
            "queuedEvents" to queuedEvents,
        )
    }

    /** Dart validated entries against the timetable or the private event book. */
    fun reconcile(context: Context, keep: Set<String>): Map<String, Any> {
        val now = System.currentTimeMillis()
        val build = appBuild(context)
        val allowed = access(context) == "allowed"
        for (saved in all(context)) {
            val item = saved.request
            when {
                item.key !in keep || item.isExpired(now) -> cancel(context, item.key)
                item.isDue(now) && (saved.build != build || !allowed || deliveryIntent(context, item.key, PendingIntent.FLAG_NO_CREATE) == null) -> cancel(context, item.key)
                !allowed -> disarm(context, item.key) // Preserve future choices for after permission is restored.
                !item.isDue(now) && !item.canSchedule(now) -> cancel(context, item.key)
                !item.isDue(now) -> {
                    createChannel(context)
                    arm(context, item)
                    if (saved.build != build) save(context, saved.copy(build = build))
                }
            }
        }
        return snapshot(context)
    }

    private fun restoreAfterBoot(context: Context) {
        val now = System.currentTimeMillis()
        val build = appBuild(context)
        val allowed = access(context) == "allowed"
        for (saved in all(context)) {
            val item = saved.request
            if (item.isDue(now)) cancel(context, item.key)
            else if (allowed && saved.build == build && item.canSchedule(now)) arm(context, item)
        }
    }

    fun receive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> restoreAfterBoot(context)
            DELIVERY -> {
                val key = intent.data?.lastPathSegment ?: return
                val saved = read(context, key) ?: return
                val item = saved.request
                val now = System.currentTimeMillis()
                if (!item.isDue(now)) return // An older callback for an edited reminder; do not cancel its replacement.
                val eligible = item.canDeliver(now, saved.build, appBuild(context))
                forget(context, key)
                disarm(context, key)
                if (eligible && access(context) == "allowed") post(context, item.key, item.title, item.body, item)
            }
        }
    }

    fun sendTest(context: Context) {
        check(access(context) == "allowed")
        post(context, "test-now", "StudyDesk reminder test", "This is a test notification, not a class reminder.")
    }

    @Suppress("DEPRECATION") // Notification.Builder(Context) is required on Android 5–7.
    private fun post(context: Context, key: String, title: String, body: String, item: ReminderPayload? = null) {
        createChannel(context)
        val open = Intent(context, MainActivity::class.java).setAction(OPEN_REMINDER).setData(uri("open", key))
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (item?.sessionId != null) {
            open.putExtra("sessionId", item.sessionId)
            open.putExtra("day", item.day)
            open.putExtra("revision", item.revision)
        } else if (item?.eventId != null) {
            open.putExtra("eventId", item.eventId)
            open.putExtra("revision", item.revision)
        }
        val content = PendingIntent.getActivity(context, 0, open, immutable or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_studydesk_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(content)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) builder.setDefaults(Notification.DEFAULT_ALL)
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        notifications(context).notify(key, NOTIFICATION_ID, builder.build())
    }
}

/** System boot and explicit immutable alarm intents; not exported to other apps. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            AndroidReminders.receive(context, intent)
        } catch (_: Exception) {
            Log.w("StudyDesk", "Android could not deliver or restore a StudyDesk reminder.")
        }
    }
}
