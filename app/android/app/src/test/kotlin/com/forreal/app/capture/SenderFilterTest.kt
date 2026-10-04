package com.forreal.app.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SenderFilterTest {
    private val allowed = SenderFilter.normalizeCodes(listOf("HDFCBK", " sbiupi "))

    @Test
    fun plainHeaderMatches() {
        assertEquals("HDFCBK", SenderFilter.matchingCode("HDFCBK", allowed))
    }

    @Test
    fun operatorPrefixIsIgnored() {
        assertEquals("HDFCBK", SenderFilter.matchingCode("AD-HDFCBK", allowed))
        assertEquals("HDFCBK", SenderFilter.matchingCode("VM-HDFCBK", allowed))
        assertEquals("SBIUPI", SenderFilter.matchingCode("JK-SBIUPI", allowed))
    }

    @Test
    fun regulatorySuffixIsIgnored() {
        assertEquals("HDFCBK", SenderFilter.matchingCode("VM-HDFCBK-S", allowed))
        assertEquals("HDFCBK", SenderFilter.matchingCode("JD-HDFCBK-T", allowed))
        assertEquals("HDFCBK", SenderFilter.matchingCode("HDFCBK-S", allowed))
    }

    @Test
    fun caseAndWhitespaceDoNotMatter() {
        assertEquals("HDFCBK", SenderFilter.matchingCode(" ad-hdfcbk ", allowed))
        assertEquals("SBIUPI", SenderFilter.matchingCode("sbiupi", allowed))
    }

    @Test
    fun gluedOperatorPrefixMatches() {
        assertEquals("HDFCBK", SenderFilter.matchingCode("ADHDFCBK", allowed))
    }

    @Test
    fun codeMustBeTheWholeHeader() {
        assertNull(SenderFilter.matchingCode("AD-HDFCBKX", allowed))
        assertNull(SenderFilter.matchingCode("AD-XHDFCBK", allowed))
        assertNull(SenderFilter.matchingCode("AD-MYHDFCBK-S", allowed))
        assertNull(SenderFilter.matchingCode("HDFCBK-OFFERS", allowed))
        assertNull(SenderFilter.matchingCode("AD-HDFCBK-S-X", allowed))
        assertNull(SenderFilter.matchingCode("12HDFCBK", allowed))
    }

    @Test
    fun otherSendersAreDropped() {
        assertNull(SenderFilter.matchingCode("AD-ICICIB", allowed))
        assertNull(SenderFilter.matchingCode("+919876543210", allowed))
        assertNull(SenderFilter.matchingCode("9876543210", allowed))
        assertNull(SenderFilter.matchingCode("AD", allowed))
        assertNull(SenderFilter.matchingCode("", allowed))
        assertNull(SenderFilter.matchingCode(null, allowed))
    }

    @Test
    fun nothingMatchesBeforeTemplatesAreDownloaded() {
        assertNull(SenderFilter.matchingCode("AD-HDFCBK", emptySet()))
    }

    @Test
    fun aTwoLetterCodeCannotMatchEveryOperatorPrefix() {
        val risky = SenderFilter.normalizeCodes(listOf("AD"))
        assertNull(SenderFilter.matchingCode("AD-HDFCBK", risky))
    }
}
