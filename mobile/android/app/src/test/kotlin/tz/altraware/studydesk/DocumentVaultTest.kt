package tz.altraware.studydesk

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DocumentVaultTest {
    private val pdfBytes = "%PDF-1.4\n% Test fixture\n".toByteArray()

    private fun withDirectory(block: (File) -> Unit) {
        val root = Files.createTempDirectory("studydesk-doc-test").toFile()
        try { block(root) } finally { root.deleteRecursively() }
    }

    private fun zipped(entry: String): ByteArray {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            for (name in listOf("[Content_Types].xml", entry)) {
                zip.putNextEntry(ZipEntry(name))
                zip.write("<dummy/>".toByteArray())
                zip.closeEntry()
            }
        }
        return bytes.toByteArray()
    }

    @Test
    fun importsPrivateCopiesWithSafeNamesAndDurableIndependentIds() = withDirectory { dir ->
        val root = File(dir, "vault")
        val original = File(dir, "Original.PDF").apply { writeBytes(pdfBytes) }
        val vault = DocumentVault(root)
        val first = vault.add("../My\u202eNotes / week.pdf") { original.inputStream() }
        val second = vault.add("../My\u202eNotes / week.pdf") { original.inputStream() }
        assertFalse(first.id == second.id)
        assertEquals(first.file.name, second.file.name)
        assertFalse(first.file.name.contains('/'))
        assertFalse(first.file.name.contains('\u202e'))
        assertTrue(first.file.canonicalPath.startsWith(root.canonicalPath + File.separator))
        assertEquals(
            mapOf("id" to first.id, "name" to first.file.name, "mime" to "application/pdf", "size" to pdfBytes.size.toLong()),
            first.summary(),
        )
        val reopened = DocumentVault(root)
        assertEquals(setOf(first.id, second.id), reopened.list().map { it.id }.toSet())
        reopened.remove(first.id)
        assertTrue(original.exists())
        assertEquals(second.id, reopened.list().single().id)
        assertThrows(DocumentFailure::class.java) { reopened.find("../Original.PDF") }
    }

    @Test
    fun validatesWordAndPowerPointWithoutExtractingArchives() = withDirectory { dir ->
        val vault = DocumentVault(dir)
        val docx = zipped("word/document.xml")
        val pptx = zipped("ppt/presentation.xml")
        val legacy = byteArrayOf(0xd0.toByte(), 0xcf.toByte(), 0x11, 0xe0.toByte(), 0xa1.toByte(), 0xb1.toByte(), 0x1a, 0xe1.toByte())
        assertEquals(DocumentFormat.DOCX, vault.add("Lesson.DOCX") { docx.inputStream() }.format)
        assertEquals(DocumentFormat.PPTX, vault.add("Slides.pptx") { pptx.inputStream() }.format)
        assertEquals(DocumentFormat.DOC, vault.add("Old notes.doc") { legacy.inputStream() }.format)
        assertEquals(DocumentFormat.PPT, vault.add("Old slides.ppt") { legacy.inputStream() }.format)
        val conflict = assertThrows(DocumentFailure::class.java) { vault.add("Wrong.pptx") { docx.inputStream() } }
        assertEquals("document_invalid", conflict.code)
        assertEquals(4, vault.list().size)
    }

    @Test
    fun enforcesCountAndActualByteLimitsWithoutLeavingPartialCopies() = withDirectory { dir ->
        val small = DocumentVault(dir, fileLimit = pdfBytes.size.toLong(), libraryLimit = pdfBytes.size + 5L, countLimit = 2)
        val large = assertThrows(DocumentFailure::class.java) {
            small.add("Too big.pdf") { ByteArrayInputStream(ByteArray(pdfBytes.size + 1)) }
        }
        assertEquals("document_too_large", large.code)
        small.add("Notes.pdf") { pdfBytes.inputStream() }
        val full = assertThrows(DocumentFailure::class.java) { small.add("Extra.pdf") { pdfBytes.inputStream() } }
        assertEquals("document_capacity", full.code)
        val count = DocumentVault(dir, fileLimit = 1024, libraryLimit = 2048, countLimit = 1)
        val tooMany = assertThrows(DocumentFailure::class.java) { count.add("Extra.pdf") { error("should not read") } }
        assertEquals("document_capacity", tooMany.code)
        assertEquals(1, dir.listFiles()!!.size)
    }

    @Test
    fun rejectsUnsupportedOrUnreadableContentAndRecoversInterruptedStaging() = withDirectory { dir ->
        val vault = DocumentVault(dir)
        val file = assertThrows(DocumentFailure::class.java) { vault.add("Notes.exe") { error("should not read") } }
        assertEquals("document_type", file.code)
        val header = assertThrows(DocumentFailure::class.java) { vault.add("Empty.pdf") { ByteArray(0).inputStream() } }
        assertEquals("document_invalid", header.code)
        assertThrows(IOException::class.java) { vault.add("Unreadable.pdf") { throw IOException("test file vanished") } }
        assertTrue(dir.listFiles()!!.isEmpty())
        val staging = File(dir, ".stage-0123456789abcdef0123456789abcdef").apply { mkdir() }
        File(staging, "Interrupted.pdf").writeBytes(pdfBytes)
        assertTrue(vault.list().isEmpty())
        assertFalse(staging.exists())
    }
}
