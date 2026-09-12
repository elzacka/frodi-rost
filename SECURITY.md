# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last reviewed 12.09.26.

## Reporting a vulnerability

Email **hei@tazk.no**, subject `[SECURITY] Fróði røst - <description>`.
Include reproduction steps and impact. Acknowledgement within 48 hours,
assessment within 7 days. Do not open public GitHub issues.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Device lost or stolen, locked | Audio and transcripts unreadable |
| Backup copied, or restored to another device | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while a transcript is open | Text hidden until capture stops |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Device unlocked, app open, in someone else's hands | Readable, as with any app |

## What is in use

Every security technology and setting the app relies on, and where it lives.
The sections below explain the choices.

| Area | Technology or setting | Where |
|---|---|---|
| Isolation | iOS app sandbox. No app group, no shared container | System |
| Encryption at rest | AES-GCM, one random 256-bit key per recording and per transcript | `RecordingVault` |
| Key wrapping | P-256 key created in the Secure Enclave, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | `RecordingVault` |
| File protection, recording in progress | `NSFileProtectionCompleteUnlessOpen` | `AudioStorage` |
| File protection, finished recording | `NSFileProtectionComplete` | `AudioStorage` |
| File protection, temporary plaintext | `NSFileProtectionCompleteUnlessOpen`, removed in a `defer` | `AudioStorage`, `RecordingExport` |
| Backup | `isExcludedFromBackup` on the recordings folder, on every finished file, and on the SwiftData store (`.store`, `-wal`, `-shm`). Re-applied on every launch and folder access | `AudioStorage` |
| Transport | None. No `URLSession`, no `NSAppTransportSecurity` exceptions | `Info.plist`, `IsolationTests` |
| Background | `UIBackgroundModes` is `audio` alone | `Info.plist`, `IsolationTests` |
| Permissions | `NSMicrophoneUsageDescription` only. `NSSpeechRecognitionUsageDescription` is absent and tested absent | `Info.plist`, `PrivacyTests` |
| Speech to text | nb-whisper bundled in the app, loaded through WhisperKit with `download: false` and explicit local paths. Apple's on-device `DictationTranscriber` as fallback when the model is missing | `Transcription`, `WhisperTranscriber`, `SpeechEngine` |
| Privacy manifest | No tracking, no tracking domains, no collected data. One accessed API: file timestamps, C617.1 | `PrivacyInfo.xcprivacy`, `IsolationTests` |
| Screen capture | Transcript hidden while `UIScreen.isCaptured` is true | `CaptureGuard` |
| Export | Decrypted on demand to the temporary directory, handed to the system share sheet, removed when the sheet closes | `RecordingExport`, `ShareSheet` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave | `project.yml` |
| Compiler | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true` | `project.yml` |
| Attack surface kept closed | No URL schemes, no document types, no `NSUserActivity` (Handoff), no Spotlight indexing, no extensions, no app group | `Info.plist` |

## Encryption

Each recording and transcript is sealed with AES-GCM under a per-item 256-bit key.
That key is wrapped by a P-256 key created inside the Secure Enclave. The private
key cannot be extracted.

Access control is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

- **AfterFirstUnlock**, not WhenUnlocked: the Action Button stops recordings while
  the screen is locked, and sealing must succeed then.
- **ThisDeviceOnly**: the key is excluded from backups and device migration.

Plaintext exists only while a job runs: during transcription, during export, and
while a detail screen is open. It is removed afterwards.

## File protection

| State | Class | Reason |
|---|---|---|
| Recording in progress | `.completeUnlessOpen` | `.complete` blocks writes when the screen locks, which is when recordings run |
| Finished recording | `.complete` | Unreadable while locked |
| Temporary plaintext | `.completeUnlessOpen` | Removed in a `defer` |

Files are also marked `isExcludedFromBackup`, re-applied on every folder access
because Apple documents the flag as resettable guidance. The SwiftData store is
marked the same way at every launch: its transcripts are ciphertext, but the
dates, durations and file names beside them are not, and none of that belongs
in a backup. Encryption is what carries the guarantee.

## No network

The app makes no network requests and sends no telemetry. Tests fail if an ATS
exception appears, if a background mode other than `audio` is declared, or if the
privacy manifest declares collected data.

The speech model is bundled. WhisperKit is configured with `download: false` and
explicit local paths, so a missing file fails rather than fetching.

**One honest qualification.** WhisperKit depends on `swift-transformers`, whose
`Hub` target contains an HTTP client. That code is linked into the binary even
though nothing here calls it — the model and tokenizer are read from the bundle.
The precise claim is "this app makes no network requests", not "this binary
contains no networking code". The second would be stronger and is not true.

`PrivacyInfo.xcprivacy` declares no tracking, no tracking domains, no collected
data types. The only accessed-API declaration is file timestamps (C617.1).

## Permissions

Microphone only.

Transcription runs in-process against a bundled CoreML model. It uses no iOS
speech service, so `NSSpeechRecognitionUsageDescription` is absent. A test fails
if the key appears.

## Dependencies

WhisperKit and seven transitive packages. All permissively licensed, listed in
[TREDJEPART.md](TREDJEPART.md). None performs network access as configured.

WhisperKit 0.18 is not annotated for Swift 6 and is given a retroactive unchecked
`Sendable` conformance. That is an assertion, not a compiler-verified fact. It
holds because calls reach it from the main actor, one recording at a time. Remove
it when WhisperKit annotates its own types.

## Deliberate omissions

- **No biometric lock.** The app is used hands-busy while driving. A Face ID gate
  at the moment of recording would defeat its purpose.
- **No certificate pinning.** There is no transport.
- **No screenshot blocking.** `userDidTakeScreenshotNotification` fires after the
  image exists. The hidden `isSecureTextEntry` trick is undocumented and can break
  without warning. The app does not offer what it cannot deliver.
