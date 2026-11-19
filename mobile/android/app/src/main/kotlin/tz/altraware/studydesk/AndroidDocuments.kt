package tz.altraware.studydesk

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** The OS grants read access to the single document chosen by the user. */
internal class AndroidDocuments(private val activity: Activity) {
    private val appContext = activity.applicationContext
    private val vault = DocumentVault(File(appContext.filesDir, DocumentVault.DIRECTORY))
    private var picker: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> onWorker(result) { vault.list().map { it.summary() } }
            "pick" -> pick(result)
            "remove" -> onWorker(result) {
                vault.remove(requireId(call.arguments))
                null
            }
            "open", "share" -> handoff(result, call.arguments, share = call.method == "share")
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION") // FlutterActivity forwards Android activity results.
    private fun pick(result: MethodChannel.Result) {
        if (picker != null) {
            result.error("document_busy", "A file picker is already open.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, DocumentFormat.entries.map { it.mime }.toTypedArray())
            .putExtra(Intent.EXTRA_LOCAL_ONLY, true)
        picker = result
        try {
            activity.startActivityForResult(intent, PICK_DOCUMENT)
        } catch (failure: Exception) {
            picker = null
            report(result, failure, "document_picker")
        }
    }

    fun onActivityResult(request: Int, status: Int, data: Intent?) {
        if (request != PICK_DOCUMENT) return
        val result = picker ?: return
        picker = null
        if (status != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null || uri.scheme != ContentResolver.SCHEME_CONTENT) {
            result.error("document_read", "Could not read the selected document.", null)
            return
        }
        onWorker(result, "document_read") { copy(uri) }
    }

    private fun copy(uri: Uri): Map<String, Any> {
        val resolver = appContext.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
        } ?: throw DocumentFailure("document_read")
        return vault.add(name) {
            resolver.openInputStream(uri) ?: throw DocumentFailure("document_read")
        }.summary()
    }

    private fun requireId(id: Any?) = id as? String ?: throw DocumentFailure("document_missing")

    private fun handoff(result: MethodChannel.Result, id: Any?, share: Boolean) {
        io.execute {
            val intent: Intent = try {
                val document = vault.find(requireId(id))
                val uri = FileProvider.getUriForFile(appContext, "${appContext.packageName}.documents", document.file)
                if (share) {
                    val send = Intent(Intent.ACTION_SEND).setType(document.format.mime)
                        .putExtra(Intent.EXTRA_STREAM, uri)
                        .apply { clipData = ClipData.newRawUri("StudyDesk document", uri) }
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    Intent.createChooser(send, "Share a copy")
                } else {
                    Intent(Intent.ACTION_VIEW).setDataAndType(uri, document.format.mime)
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            } catch (failure: Exception) {
                report(result, failure)
                return@execute
            }
            activity.runOnUiThread {
                if (activity.isFinishing || activity.isDestroyed) {
                    result.success(false)
                    return@runOnUiThread
                }
                try {
                    activity.startActivity(intent)
                    result.success(true) // Dispatch only; opening does not report a save or upload.
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                } catch (failure: Exception) {
                    report(result, failure)
                }
            }
        }
    }

    fun detach() {
        picker?.error("document_interrupted", "The Android file picker was closed.", null)
        picker = null
    }

    private fun onWorker(result: MethodChannel.Result, fallback: String = "document_storage", work: () -> Any?) {
        io.execute {
            try {
                result.success(work())
            } catch (failure: Exception) {
                report(result, failure, fallback)
            }
        }
    }

    private fun report(result: MethodChannel.Result, failure: Exception, fallback: String = "document_storage") {
        // No original URI, filename, bytes or provider error is logged or returned.
        result.error((failure as? DocumentFailure)?.code ?: fallback, "StudyDesk could not complete the file action.", null)
    }

    companion object {
        private const val PICK_DOCUMENT = 0x5345
        private val io = Executors.newSingleThreadExecutor()
    }
}

/** Deliberately not exported; a viewer receives only a temporary read grant. */
class StudyDocumentProvider : FileProvider()
