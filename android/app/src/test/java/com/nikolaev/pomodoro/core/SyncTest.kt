package com.nikolaev.pomodoro.core

import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.security.interfaces.ECPublicKey

/** docs/sync-vectors.json: the same file the Swift tests read. Gradle runs tests from android/app. */
private val vectors = JSONObject(File("../../docs/sync-vectors.json").readText())

private fun JSONObject.bytes(key: String): ByteArray = fromBase64Url(getString(key))!!

class SyncCryptoTest {
    private val c = vectors.getJSONObject("crypto")

    @Test
    fun bothSidesDeriveTheDeviceKey() {
        val onPhone = SyncCrypto.deviceKey(SyncCrypto.privateKey(c.bytes("phonePrivate")), c.bytes("macPublic"), c.bytes("token"))
        val onMac = SyncCrypto.deviceKey(SyncCrypto.privateKey(c.bytes("macPrivate")), c.bytes("phonePublic"), c.bytes("token"))
        assertArrayEquals(c.bytes("deviceKey"), onPhone)
        assertArrayEquals(c.bytes("deviceKey"), onMac)
    }

    @Test
    fun publicKeysRoundTripIncludingALeadingZero() {
        // The phone's X starts with a zero byte, which BigInteger drops.
        for (name in listOf("macPublic", "phonePublic")) {
            assertArrayEquals(c.bytes(name), SyncCrypto.encode(SyncCrypto.publicKeyFrom(c.bytes(name))))
        }
        val fresh = SyncCrypto.newKeyPair()
        assertEquals(65, SyncCrypto.encode(fresh.public as ECPublicKey).size)
    }

    @Test
    fun aPointOffTheCurveIsRefused() {
        val bad = c.bytes("macPublic").also { it[64] = (it[64] + 1).toByte() }
        assertThrows(Exception::class.java) {
            SyncCrypto.deviceKey(SyncCrypto.privateKey(c.bytes("phonePrivate")), bad, c.bytes("token"))
        }
    }

    @Test
    fun theProofMatches() {
        assertArrayEquals(c.bytes("proof"), SyncCrypto.proof(c.bytes("token"), c.bytes("phonePublic"), c.bytes("macPublic")))
    }

    @Test
    fun sessionKeysAndFramesMatchInBothDirections() {
        val (c2s, s2c) = SyncCrypto.sessionKeys(c.bytes("deviceKey"), c.bytes("nonceClient"), c.bytes("nonceServer"))
        assertArrayEquals(c.bytes("c2s"), c2s)
        assertArrayEquals(c.bytes("s2c"), s2c)
        val phone = SessionCipher(sendKey = c2s, receiveKey = s2c)
        val mac = SessionCipher(sendKey = s2c, receiveKey = c2s)
        val frames = c.getJSONArray("frames")
        for (i in 0 until frames.length()) {
            val f = frames.getJSONObject(i)
            val text = f.getString("plaintext").toByteArray()
            val payload = f.bytes("payload")
            val (sender, receiver) = if (f.getString("key") == "c2s") phone to mac else mac to phone
            assertArrayEquals(payload, sender.seal(text))
            assertArrayEquals(text, receiver.open(payload))
        }
    }

    @Test
    fun aReplayedOrAlteredFrameDoesNotOpen() {
        val key = c.bytes("c2s")
        val first = SessionCipher(key, key).seal("one".toByteArray())
        val receiver = SessionCipher(key, key)
        receiver.open(first)
        assertThrows(Exception::class.java) { receiver.open(first) }
        val altered = first.copyOf().also { it[0] = (it[0].toInt() xor 1).toByte() }
        assertThrows(Exception::class.java) { SessionCipher(key, key).open(altered) }
    }
}

class SyncWireTest {
    @Test
    fun thePairingLinkParsesAndRejectsAnythingElse() {
        val v = vectors.getJSONObject("pairLink")
        val valid = v.getJSONObject("valid")
        val link = PairLink.parse(valid.getString("link"))!!
        assertEquals(valid.getString("id"), link.macId)
        assertArrayEquals(valid.bytes("publicKey"), link.publicKey)
        assertArrayEquals(valid.bytes("token"), link.token)
        assertEquals(listOf("192.168.1.5", "10.0.0.7"), link.addresses)
        assertEquals(52025, link.port)
        val invalid = v.getJSONArray("invalid")
        for (i in 0 until invalid.length()) assertNull(invalid.getString(i), PairLink.parse(invalid.getString(i)))
    }

    @Test
    fun aStateReadsFromTheWireAndRoundTrips() {
        val v = vectors.getJSONObject("state")
        val s = EngineState.fromWire(JSONObject(v.getString("json")))!!
        assertEquals(Phase.SHORT_BREAK, s.phase)
        assertEquals(RunState.RUNNING, s.runState)
        assertEquals(300.0, s.phaseDuration, 0.0)
        assertEquals(1792761800.5, s.endsAt!!, 0.0)
        assertEquals(3, s.completedToday)
        assertEquals(3, s.sinceLongBreak)
        assertEquals("2026-10-23", s.toWire().getString("day"))
        assertEquals(1792761500.5, s.changedAt, 0.0)

        val back = SyncMessage.decode(SyncMessage.State(s, 1000.0).encode()) as SyncMessage.State
        assertEquals(s, back.state)
        assertEquals(1000.0, back.sentAt, 0.0)
    }

    @Test
    fun remoteTimesMoveOntoTheLocalClock() {
        val v = vectors.getJSONObject("shift")
        val remote = v.getJSONObject("remote")
        val local = v.getJSONObject("local")
        val s = EngineState.initial(IntervalSettings(), 0)
            .copy(runState = RunState.RUNNING, endsAt = remote.getDouble("endsAt"), changedAt = remote.getDouble("changedAt"))
        val shifted = s.shifted(v.getDouble("receivedAt") - v.getDouble("sentAt"))
        assertEquals(local.getDouble("endsAt"), shifted.endsAt!!, 0.0)
        assertEquals(local.getDouble("changedAt"), shifted.changedAt, 0.0)

        val untouched = vectors.getJSONObject("shiftUntouched")
        val offset = untouched.getDouble("receivedAt") - untouched.getDouble("sentAt")
        assertEquals(0.0, s.copy(changedAt = 0.0).shifted(offset).changedAt, 0.0)
        assertEquals(0.0, SyncRules.shifted(0.0, offset), 0.0)
    }

    @Test
    fun theLaterChangeWinsAndTheMacWithinASecond() {
        val cases = vectors.getJSONArray("merge")
        for (i in 0 until cases.length()) {
            val m = cases.getJSONObject(i)
            val adopt = SyncRules.shouldAdopt(m.getDouble("local"), m.getDouble("remote"), m.getString("receiver") == "mac")
            assertEquals(m.getString("why"), m.getBoolean("adopt"), adopt)
        }
    }

    @Test
    fun intervalSettingsTravelAndDefaultsNeverWin() {
        val v = vectors.getJSONObject("intervals")
        val m = SyncMessage.decode(v.getString("json").toByteArray()) as SyncMessage.Intervals
        assertEquals(IntervalSettings(60.0, 5.0, 15.0, 4), m.intervals)
        assertEquals(900.25, m.changedAt, 0.0)
        assertEquals(1000.5, m.sentAt, 0.0)
        assertEquals(m, SyncMessage.decode(m.encode()))
        val zero = """{"type":"intervals","sentAt":1,"changedAt":1,"intervals":{"workMinutes":0}}"""
        assertNull(SyncMessage.decode(zero.toByteArray()))

        val cases = vectors.getJSONArray("mergeIntervals")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val adopt = SyncRules.shouldAdoptIntervals(c.getDouble("local"), c.getDouble("remote"), c.getString("receiver") == "mac")
            assertEquals(c.getString("why"), c.getBoolean("adopt"), adopt)
        }
    }

    @Test
    fun handshakeMessagesRoundTrip() {
        val nonce = ByteArray(16) { it.toByte() }
        val hello = SyncMessage.decode(SyncMessage.Hello("a", nonce).encode()) as SyncMessage.Hello
        assertEquals("a", hello.id)
        assertArrayEquals(nonce, hello.nonce)
        val pair = SyncMessage.decode(SyncMessage.Pair("a", "phone", ByteArray(65), nonce, ByteArray(32)).encode())
        assertTrue(pair is SyncMessage.Pair)
        assertEquals(SyncMessage.Error("unknown-device"), SyncMessage.decode(SyncMessage.Error("unknown-device").encode()))
        assertEquals(SyncMessage.Unpair, SyncMessage.decode(SyncMessage.Unpair.encode()))
        assertEquals(SyncMessage.UnsupportedVersion, SyncMessage.decode("""{"type":"hello","v":2,"id":"a"}""".toByteArray()))
        assertEquals(SyncMessage.Unknown, SyncMessage.decode("""{"type":"later"}""".toByteArray()))
        assertNull(SyncMessage.decode("not json".toByteArray()))
    }

    @Test
    fun aSwiftStateMessageDecodes() {
        // JSONSerialization writes whole numbers without a fraction and the keys sorted.
        val swift = """{"sentAt":1000.5,"state":{"changedAt":900,"completedToday":0,"day":"2026-10-23","endsAt":null,""" +
            """"phase":"work","phaseDuration":1500,"remaining":1500,"runState":"idle","sinceLongBreak":0},"type":"state"}"""
        val m = SyncMessage.decode(swift.toByteArray()) as SyncMessage.State
        assertNotNull(m.state)
        assertEquals(1500.0, m.state.remaining, 0.0)
        assertEquals(900.0, m.state.changedAt, 0.0)
    }
}

class ChangeTimeTest {
    @Test
    fun buttonsStampTheMomentAnIntervalRunningOutStampsItsEnd() {
        val t0 = 1_000_000.0
        val e = PomodoroEngine()
        e.start(t0)
        assertEquals(t0, e.state.changedAt, 0.0)
        e.update(t0 + 25 * 60 + 0.3)
        assertEquals(t0 + 25 * 60, e.state.changedAt, 0.0)
        e.applySettings(IntervalSettings(shortBreakMinutes = 7.0), t0 + 3000)
        assertEquals(t0 + 3000, e.state.changedAt, 0.0)
        e.rollOverDay(5)
        assertEquals(t0 + 3000, e.state.changedAt, 0.0)
    }
}
