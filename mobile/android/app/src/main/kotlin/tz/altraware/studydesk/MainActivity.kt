package tz.altraware.studydesk

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var reminders: MethodChannel? = null
    private var campus: MethodChannel? = null
    private var documents: MethodChannel? = null
    private var documentBridge: AndroidDocuments? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminders = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tz.altraware.studydesk/class_reminders").also {
            it.setMethodCallHandler(::handleReminderCall)
        }
        campus = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tz.altraware.studydesk/campus_events").also {
            it.setMethodCallHandler { call, result -> CampusAndroid.handle(this, call, result) }
        }
        val library = AndroidDocuments(this)
        documentBridge = library
        documents = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tz.altraware.studydesk/documents").also {
            it.setMethodCallHandler(library::handle)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        reminders?.setMethodCallHandler(null)
        reminders = null
        campus?.setMethodCallHandler(null)
        campus = null
        documents?.setMethodCallHandler(null)
        documents = null
        documentBridge?.detach()
        documentBridge = null
        permissionResult?.error("interrupted", "Android closed the permission request.", null)
        permissionResult = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == AndroidReminders.OPEN_REMINDER) reminders?.invokeMethod("reminderOpened", null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        documentBridge?.onActivityResult(requestCode, resultCode, data)
    }

    private fun handleReminderCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "snapshot" -> result.success(AndroidReminders.snapshot(this))
                "reconcile" -> {
                    val keep = (call.arguments as List<*>).filterIsInstance<String>().toSet()
                    result.success(AndroidReminders.reconcile(this, keep))
                }
                "requestPermission" -> requestNotificationPermission(result)
                "schedule" -> {
                    AndroidReminders.schedule(this, ReminderPayload.decode(call.arguments as Map<*, *>))
                    result.success(null)
                }
                "cancel" -> {
                    AndroidReminders.cancel(this, call.arguments as String)
                    result.success(null)
                }
                "cancelClassReminders" -> {
                    AndroidReminders.cancelClassReminders(this)
                    result.success(null)
                }
                "sendTest" -> {
                    AndroidReminders.sendTest(this)
                    result.success(null)
                }
                "openSettings" -> {
                    try {
                        startActivity(AndroidReminders.settingsIntent(this))
                    } catch (_: ActivityNotFoundException) {
                        startActivity(AndroidReminders.appDetailsIntent(this))
                    }
                    result.success(null)
                }
                "takeOpened" -> result.success(takeOpenedReminder())
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("reminders_unavailable", "StudyDesk could not update Android reminders.", null)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        val current = AndroidReminders.access(this)
        if (permissionResult != null) {
            result.error("request_in_progress", "The notification permission prompt is already open.", null)
        } else if (Build.VERSION.SDK_INT >= 33 && current == "notAsked") {
            AndroidReminders.markPermissionAsked(this)
            permissionResult = result
            try {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
            } catch (failure: Exception) {
                permissionResult = null
                throw failure
            }
        } else {
            result.success(current)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST) {
            permissionResult?.success(AndroidReminders.access(this))
            permissionResult = null
        }
    }

    private fun takeOpenedReminder(): Map<String, String>? {
        val source = intent ?: return null
        if (source.action != AndroidReminders.OPEN_REMINDER) return null
        // Dart checks that the target still exists and matches the saved revision.
        // Taps only open details; they never write data or schedule anything.
        val keys = if (source.hasExtra("eventId")) listOf("eventId", "revision") else listOf("sessionId", "day", "revision")
        val payload = keys.mapNotNull { key -> source.getStringExtra(key)?.let { key to it } }.toMap()
        source.action = Intent.ACTION_MAIN
        return payload.takeIf { it.size == keys.size }
    }

    companion object {
        private const val PERMISSION_REQUEST = 0x5344
    }
}
