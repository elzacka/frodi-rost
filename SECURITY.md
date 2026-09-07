# Security Policy

Fróði is a dictaphone whose central claim is that recordings and transcripts
never leave the phone. This document describes how that is enforced, where the
limits are, and how to report a vulnerability.

Last reviewed 7 September 2026.

## Reporting a vulnerability

Email **hei@tazk.no** with subject `[SECURITY] Frodi iOS - <brief description>`.
Include reproduction steps, potential impact, and a suggested fix if you have
one. Acknowledgement within 48 hours, initial assessment within 7 days. Do not
open public GitHub issues.

## Threat model

| In scope | Out of scope |
|---|---|
| Recovering audio or transcripts from a lost or stolen phone | An unlocked phone in the attacker's hands |
| Recovering them from an iCloud or local backup | A jailbroken device |
| Data reaching a network, deliberately or by accident | Malicious code inside iOS itself |
| Another app on the device reading the data | The user deliberately exporting and then mishandling a file |

The app is a single-user, single-device tool. There is no account, no server and
no multi-user surface.

## No network

The app contains no networking code: no `URLSession`, no sockets, no
third-party telemetry. This is not a policy but an absence, and it is enforced
by tests that fail if an ATS exception appears, if any background mode other
than `audio` is declared, or if the privacy manifest starts declaring collected
data.

The speech model is bundled in the app. Nothing is fetched at runtime.
WhisperKit is configured with `download: false` and explicit local paths, so a
missing file fails rather than triggering a download.

`PrivacyInfo.xcprivacy` declares `NSPrivacyTracking false`, no tracking domains
and no collected data types. The only accessed-API declaration is file
timestamps (C617.1).

## Data protection

### Encryption at rest

Each finished recording is sealed with AES-GCM under a per-recording 256-bit
key. That key is wrapped with a P-256 key created inside the Secure Enclave via
`SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`. The private key
cannot be extracted; wrapping and unwrapping happen inside the Enclave.

The Enclave key uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:

- **AfterFirstUnlock** rather than **WhenUnlocked** because the Action Button
  can stop a recording while the screen is locked, and sealing has to succeed
  at that moment.
- **ThisDeviceOnly** keeps the key out of every backup and out of device
  migration.

Consequence: a backup or a copied file is unreadable anywhere else. This is
deliberate. Export is the supported way out.

### File protection

| State | Class | Why |
|---|---|---|
| Recording in progress | `.completeUnlessOpen` | `.complete` makes the file unwritable the moment the screen locks, which is exactly when a recording runs in a car |
| Finished recording | `.complete` | Unreadable while the device is locked |
| Decrypted during transcription or export | `.completeUnlessOpen`, in the temporary directory, removed in a `defer` | Plaintext exists only for the duration of the job |

Recordings are also marked `isExcludedFromBackup`, re-applied on every folder
access because Apple documents the flag as guidance that file operations can
reset. The encryption above is what actually carries the guarantee.

### Known gap

Transcripts are stored as plain text in the SwiftData store. The store is
covered by the app sandbox and file protection, but is not sealed by the vault
the way audio is. An attacker with the device unlocked, or with a way past file
protection, would read transcripts but not audio.

## Speech processing

Transcription runs inside the app process using a CoreML model, not through any
system or network service.

The app previously used iOS `SFSpeechRecognizer`. It was removed because its
authorization dialog carries Apple's own text stating that speech data is sent
to Apple. That text is system-owned and cannot be changed, and it contradicted
the app's central claim regardless of `requiresOnDeviceRecognition`. The app now
declares no `NSSpeechRecognitionUsageDescription`, and a test fails if the key
returns.

## Dependencies

WhisperKit and seven transitive packages are linked. All are permissively
licensed and listed in [TREDJEPART.md](TREDJEPART.md). None performs network
access in the configuration used here.

WhisperKit 0.18 is not annotated for Swift 6, and the project builds with
`SWIFT_STRICT_CONCURRENCY = complete`. It is given a retroactive unchecked
`Sendable` conformance. **That is an assertion, not a compiler-verified fact.**
It holds because every call reaches it from the main actor, one recording at a
time. It should be removed when WhisperKit annotates its own types.

## What the app does not attempt

- **No biometric lock on the app.** The primary use is hands-busy capture while
  driving, and a Face ID gate at the moment of recording would defeat it.
- **No certificate pinning, no transport hardening.** There is no transport.
- **No screenshot or screen-recording blocking.** It would not stop a determined
  reader and would break legitimate use.
