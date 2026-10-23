# Mac ↔ phone sync, protocol v1

The Mac and the phone show and control one timer over the home Wi-Fi. No
servers, no accounts. Each device keeps working on its own when the other is
away, and they catch up when they meet again.

The Mac is the server, the phone the client. A Mac can have several phones; a
phone has one Mac.

[`sync-vectors.json`](sync-vectors.json) holds test vectors for every step
below; the Swift and the Kotlin tests both check them.

## Encodings

- Binary values in JSON and in the QR link: base64url without padding.
- Public keys: P-256, uncompressed X9.63 (65 bytes, `04 ‖ X ‖ Y`).
- Times: seconds since 1970-01-01 UTC, as a JSON number with a fraction.
- Device ids: 16 random bytes, made once per installation. Not secret.

## Pairing QR

The Mac shows it under Settings → Devices → Pair a phone. The phone reads it
with the scanner inside the app; the link is never opened by the system.

```
pomodoro://pair?v=1&id=<mac id>&k=<mac public key>&t=<token>&a=<ip>,<ip>&p=<port>
```

- `k`: a key pair made for this QR only.
- `t`: 16 random bytes, the one-time pass.
- `a`, `p`: the Mac's IPv4 addresses and port, so pairing needs no discovery.

The QR is valid for 2 minutes and for one pairing. Closing the window or a
new QR invalidates it.

## Frames

TCP. Every frame is a 4-byte big-endian length, 1…16384, then that many
bytes. A longer or empty frame closes the connection.

The two hello frames are plain JSON. Every frame after them is encrypted.

## Handshake

The client sends one of:

```json
{"type": "hello", "v": 1, "id": "<phone id>", "nonce": "<16 bytes>"}
{"type": "pair", "v": 1, "id": "<phone id>", "name": "motorola edge 50",
 "pub": "<phone public key>", "nonce": "<16 bytes>", "proof": "<32 bytes>"}
```

`pair` is sent once, right after scanning:

- `pub`: the phone's key pair, made for this pairing only.
- `proof = HMAC-SHA256(key: t, "pomodoro-pair-v1" ‖ phone pub ‖ mac pub)`.

The Mac checks that the QR is still valid and the proof matches (in constant
time), then derives the device key and stores it with the phone's id and
name.

The server answers with:

```json
{"type": "hello", "v": 1, "id": "<mac id>", "nonce": "<16 bytes>"}
```

or with an error and closes the connection:

```json
{"type": "error", "reason": "unknown-device"}
```

`reason` is `unknown-device`, `pairing-expired` or `version`. The phone shows
it but never forgets the Mac because of it: the error is unauthenticated.

## Keys

```
Z      = ECDH(phone private, mac public) = ECDH(mac private, phone public)   32 bytes
K      = HKDF-SHA256(ikm: Z, salt: t, info: "pomodoro-key-v1", 32 bytes)      device key
c2s    = HKDF-SHA256(ikm: K, salt: nonce_c ‖ nonce_s, info: "pomodoro-c2s-v1", 32 bytes)
s2c    = HKDF-SHA256(ikm: K, salt: nonce_c ‖ nonce_s, info: "pomodoro-s2c-v1", 32 bytes)
```

`K` is stored in the Keychain on the Mac and under an Android Keystore key on
the phone. The phone stores it only after the first frame from the Mac
decrypts: that proves the Mac holds the private key from the QR.

Encrypted frames are AES-256-GCM: the payload is the ciphertext followed by
the 16-byte tag, no associated data. The nonce is 4 zero bytes and then a
64-bit big-endian counter. Each direction has its own key and counter,
starting at 0 for every connection. A frame that does not decrypt with the
next counter closes the connection.

## Messages

Encrypted frames carry JSON.

```json
{"type": "state", "sentAt": 1792761500.25, "state": {
  "phase": "work", "runState": "running",
  "phaseDuration": 1500, "remaining": 1500, "endsAt": 1792763000.25,
  "completedToday": 3, "sinceLongBreak": 3, "day": "2026-10-23",
  "changedAt": 1792761500.25}}
{"type": "unpair"}
{"type": "ping"}
```

- `state`: sent by both sides right after the handshake, and then after
  every change. `endsAt` is `null` unless running. `day` is the local date
  the count belongs to.
- `unpair`: the sender has forgotten the receiver. The receiver forgets it
  too, then the connection closes.
- `ping`: sent after 20 seconds without other frames. 60 seconds of silence
  closes the connection.
- Unknown types are ignored.

## Merging

`changedAt` is when the state last changed:

- a button, a new duration, or a settings change to the current idle
  interval: that moment;
- an interval running out: its `endsAt`, so both devices give the same time.

The receiver moves the remote times onto its own clock first:
`offset = received at − sentAt`, added to `endsAt` and `changedAt`. The error
is the network delay, milliseconds at home.

Then the later change wins. Within 1 second the Mac wins: when an interval
runs out on both devices, the phone takes the Mac's next interval.

- The phone takes the remote state if `remote.changedAt ≥ local.changedAt − 1`.
- The Mac takes it if `remote.changedAt > local.changedAt + 1`.

Taking a state plays no sound and posts no notification. A device sends its
state whenever its `changedAt` differs from the last one it sent or took.
The Mac sends to every connected phone, the phone to the Mac.

Settings are not synced. Each device uses its own durations for the next
interval until the states meet.

## Discovery

The Mac listens on TCP port 52025, or any free port if that one is taken, and
advertises `_pomodoro._tcp` with TXT `id=<mac id>`. It listens only while it
has a paired phone or the pairing QR is on screen.

The phone looks for the service whose `id` is its Mac's, and falls back to
the last address that worked.
