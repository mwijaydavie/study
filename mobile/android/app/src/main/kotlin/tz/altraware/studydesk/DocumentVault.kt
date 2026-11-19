package tz.altraware.studydesk

import java.io.DataInputStream
import java.io.EOFException
import java.io.File
import java.io.InputStream
import java.util.Locale
import java.util.UUID
import java.util.zip.ZipException
import java.util.zip.ZipFile

internal enum class DocumentFormat(val extension: String, val mime: String) {
    PDF("pdf", "application/pdf"),
    DOC("doc", "application/msword"),
    DOCX("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
    PPT("ppt", "application/vnd.ms-powerpoint"),
    PPTX("pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation");

    /** A basic type check, not a malware scanner. Never extract the archive. */
    fun matches(file: File): Boolean = when (this) {
        PDF -> hasHeader(file, "%PDF-".toByteArray(Charsets.US_ASCII))
        DOC, PPT -> hasHeader(file, byteArrayOf(0xd0.toByte(), 0xcf.toByte(), 0x11, 0xe0.toByte(), 0xa1.toByte(), 0xb1.toByte(), 0x1a, 0xe1.toByte()))
        DOCX -> hasOfficeEntries(file, "word/document.xml")
        PPTX -> hasOfficeEntries(file, "ppt/presentation.xml")
    }

    private fun hasHeader(file: File, prefix: ByteArray): Boolean = try {
        DataInputStream(file.inputStream()).use { input ->
            ByteArray(prefix.size).also { input.readFully(it) }.contentEquals(prefix)
        }
    } catch (_: EOFException) {
        false
    }

    private fun hasOfficeEntries(file: File, main: String): Boolean = try {
        ZipFile(file).use { zip ->
            zip.getEntry("[Content_Types].xml")?.isDirectory == false && zip.getEntry(main)?.isDirectory == false
        }
    } catch (_: ZipException) {
        false
    }

    companion object {
        fun of(name: String): DocumentFormat? {
            val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
            return entries.firstOrNull { it.extension == ext }
        }
    }
}

internal class DocumentFailure(val code: String) : Exception()

internal data class LocalDocument(val id: String, val file: File, val format: DocumentFormat) {
    fun summary() = mapOf(
        "id" to id,
        "name" to file.name,
        "mime" to format.mime,
        "size" to file.length(),
    )
}

/** One private copy per ID. Calls from Android are serialized on a single I/O worker. */
internal class DocumentVault(
    private val root: File,
    private val fileLimit: Long = 20L * 1024 * 1024,
    private val libraryLimit: Long = 200L * 1024 * 1024,
    private val countLimit: Int = 50,
) {
    private val idPattern = Regex("[a-f0-9]{32}")
    private val stagingPattern = Regex("\\.stage-[a-f0-9]{32}")
    private val unsafeName = Regex("[\\\\/\\p{Cc}\\p{Cf}]")

    private fun directories(): Array<File> {
        if (!root.exists() && !root.mkdirs()) throw DocumentFailure("document_storage")
        return root.listFiles() ?: throw DocumentFailure("document_storage")
    }

    fun list(): List<LocalDocument> = directories().mapNotNull { directory ->
        when {
            stagingPattern.matches(directory.name) -> {
                // Reclaim an incomplete copy if Android killed the app mid-import.
                directory.deleteRecursively()
                null
            }
            idPattern.matches(directory.name) -> stored(directory)
            else -> null
        }
    }.sortedWith(compareByDescending<LocalDocument> { it.file.lastModified() }.thenBy { it.id })

    private fun stored(dir: File): LocalDocument? {
        val file = dir.listFiles()?.singleOrNull() ?: return null
        if (!file.isFile || file.length() <= 0) return null
        val format = DocumentFormat.of(file.name) ?: return null
        return LocalDocument(dir.name, file, format)
    }

    fun find(id: String): LocalDocument {
        if (!idPattern.matches(id)) throw DocumentFailure("document_missing")
        return stored(File(root, id)) ?: throw DocumentFailure("document_missing")
    }

    fun add(name: String, source: () -> InputStream): LocalDocument {
        val original = name.trim()
        val format = DocumentFormat.of(original) ?: throw DocumentFailure("document_type")
        val saved = list()
        val remaining = libraryLimit - saved.sumOf { it.file.length() }
        if (saved.size >= countLimit || remaining <= 0) throw DocumentFailure("document_capacity")

        // Limit UTF-8 filename bytes, drop separators/control characters, and do not use
        // a path or URI supplied by the picker. Identical names get independent IDs.
        val stem = original.substringBeforeLast('.').replace(unsafeName, "_").trim().trim('.')
            .take(70).trimEnd { Character.isHighSurrogate(it) }.ifBlank { "Study document" }
        val safeName = "$stem.${format.extension}"
        val id = UUID.randomUUID().toString().replace("-", "")
        val staging = File(root, ".stage-$id")
        val destination = File(root, id)
        if (destination.exists() || !staging.mkdir()) throw DocumentFailure("document_storage")
        val temp = File(staging, safeName)
        try {
            source().use { input ->
                temp.outputStream().use { output ->
                    var size = 0L
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        size += count
                        if (size > fileLimit) throw DocumentFailure("document_too_large")
                        if (size > remaining) throw DocumentFailure("document_capacity")
                        output.write(buffer, 0, count)
                    }
                    output.fd.sync()
                }
            }
            if (!format.matches(temp)) throw DocumentFailure("document_invalid")
            if (!staging.renameTo(destination)) throw DocumentFailure("document_storage")
            return LocalDocument(id, File(destination, safeName), format)
        } finally {
            if (staging.exists()) staging.deleteRecursively()
        }
    }

    fun remove(id: String) {
        val document = find(id)
        if (!document.file.delete()) throw DocumentFailure("document_storage")
        document.file.parentFile?.delete()
    }

    companion object {
        const val DIRECTORY = "study_documents_v1"
    }
}
