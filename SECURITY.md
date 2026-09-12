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
| Device lost or stolen, locked | Audio unreadable: the files are `NSFileProtectionComplete`. Transcripts are ciphertext in the database, whose own protection class is weaker; what keeps them unreadable is that the wrapping key is in the Secure Enclave under `AfterFirstUnlock` access control. Dates, durations and file names in the database are not encrypted |
| Recording stopped while the device is locked | Saved as plaintext under `NSFileProtectionCompleteUnlessOpen`, which cannot be reopened until the device is unlocked. Sealed and transcribed at the next unlock or launch. Never deleted |
| Backup copied, or restored to another device | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| App killed during transcription or export | Plaintext left in the temporary folder is removed at the next launch |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while a transcript is open | Text hidden until capture stops |
| App switcher, or any other time the app is not in front | Text hidden before iOS takes the snapshot |
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
| File protection, recording in progress and awaiting seal | `NSFileProtectionCompleteUnlessOpen` | `AudioStorage` |
| File protection, sealed recording | `NSFileProtectionComplete` | `AudioStorage` |
| File protection, temporary plaintext | `NSFileProtectionCompleteUnlessOpen`, in one folder, removed in a `defer` and emptied at launch | `AudioStorage`, `RecordingExport`, `RecordingController` |
| Backup | `isExcludedFromBackup` on the recordings folder, on every sealed file, and on the SwiftData store (`.store`, `-wal`, `-shm`). Re-applied on every launch, on every folder access, and after the first save | `AudioStorage`, `RecordingController` |
| Transport | None. No `URLSession`, no `NSAppTransportSecurity` exceptions. A test scans the sources for networking APIs | `Info.plist`, `IsolationTests` |
| Background | `UIBackgroundModes` is `audio` alone | `Info.plist`, `IsolationTests` |
| Permissions | `NSMicrophoneUsageDescription` only. `NSSpeechRecognitionUsageDescription` is absent and tested absent | `Info.plist`, `PrivacyTests` |
| Speech to text | nb-whisper bundled in the app, loaded through WhisperKit with `download: false` and explicit local paths. The app checks that both tokenizer files are present before WhisperKit is created. Apple's on-device `DictationTranscriber` as fallback when the model is missing | `Transcription`, `WhisperTranscriber`, `SpeechEngine` |
| Logging | WhisperKit runs with `verbose: false` and `logLevel: .none`. The app itself writes nothing to the unified log | `WhisperTranscriber` |
| Privacy manifest | No tracking, no tracking domains, no collected data. One accessed API: file timestamps, C617.1 | `PrivacyInfo.xcprivacy`, `IsolationTests` |
| Screen capture | Transcript hidden while `UIScreen.isCaptured` is true, and while the scene is not active | `CaptureGuard` |
| Export | Decrypted on demand to the temporary directory, handed to the system share sheet, removed when the sheet closes | `RecordingExport`, `ShareSheet` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave | `project.yml` |
| Compiler | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true` | `project.yml` |
| Build integrity | WhisperKit pinned to an exact version, `Package.resolved` committed, model files fetched at a fixed revision and checked against a committed checksum list | `project.yml`, `Scripts/fetch-model.sh`, `Scripts/model-checksums.txt` |
| Attack surface kept closed | No URL schemes, no document types, no `NSUserActivity` (Handoff), no Spotlight indexing, no extensions, no app group. One App Intent, `ToggleRecordingIntent`, which any Shortcut or automation can run without confirmation once microphone access is granted; that is what the Action Button uses, and it is deliberate | `Info.plist`, `ToggleRecordingIntent` |

## Encryption

Each recording and transcript is sealed with AES-GCM under a per-item 256-bit key.
That key is wrapped by a P-256 key created inside the Secure Enclave. The private
key cannot be extracted.

Access control is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

- **AfterFirstUnlock**, not WhenUnlocked: the transcript's key must be usable
  without the screen being unlocked at that moment.
- **ThisDeviceOnly**: the key is excluded from backups and device migration.

**Sealing waits for the device to be unlocked.** The Action Button can stop a
recording while the screen is locked. The key would be available then, but the
file is not: a `.completeUnlessOpen` file cannot be reopened once closed until the
device is unlocked, and a `.complete` file cannot be created at all. The
recording is therefore left as it is, unreadable under `.completeUnlessOpen`, and
sealed the moment protected data becomes available, or at the next launch. An
earlier version tried to seal at once and deleted the recording when that failed.

Plaintext exists only while a job runs: during transcription, during export, and
while a detail screen is open. It is removed afterwards, and anything a crash
leaves behind is removed at the next launch.

## File protection

| State | Class | Reason |
|---|---|---|
| Recording in progress | `.completeUnlessOpen` | `.complete` blocks writes when the screen locks, which is when recordings run |
| Stopped, awaiting seal | `.completeUnlessOpen`, closed | Cannot be reopened until the device is unlocked, which is also when the seal happens |
| Sealed recording | `.complete` | Unreadable while locked |
| Temporary plaintext | `.completeUnlessOpen` | Removed in a `defer`; the folder is emptied at launch |

Files are also marked `isExcludedFromBackup`, re-applied on every folder access
because Apple documents the flag as resettable guidance. The SwiftData store is
marked the same way at every launch and again after the first save, because
SQLite creates its `-wal` and `-shm` files on the first write: its transcripts
are ciphertext, but the dates, durations and file names beside them are not, and
none of that belongs in a backup. Encryption is what carries the guarantee.

## No network

The app makes no network requests and sends no telemetry. Tests fail if an ATS
exception appears, if a background mode other than `audio` is declared, if the
privacy manifest declares collected data, or if `URLSession`, `URLRequest`,
`NWConnection` or `import Network` appears anywhere in the app's sources.

The speech model is bundled. WhisperKit is configured with `download: false` and
explicit local paths, so a missing model file fails rather than fetching. That
flag does not cover the tokenizer: WhisperKit 0.18 falls back to Hugging Face
when the tokenizer cannot be read locally. The app therefore checks for both
tokenizer files itself before WhisperKit is created, and a build missing either
uses Apple's on-device engine instead.

**One honest qualification.** WhisperKit depends on `swift-transformers`, whose
`Hub` target contains an HTTP client. That code is linked into the binary even
though nothing here calls it — the model and tokenizer are read from the bundle.
The precise claim is "this app makes no network requests", not "this binary
contains no networking code". The second would be stronger and is not true.

`PrivacyInfo.xcprivacy` declares no tracking, no tracking domains, no collected
data types. The only accessed-API declaration is file timestamps (C617.1).

## Permissions

Microphone only.

With the model in the bundle, transcription runs in-process against it and uses
no iOS speech service. Without it, the app falls back to Apple's on-device
`DictationTranscriber`, which runs in a system process on the device and needs no
speech authorization either. `NSSpeechRecognitionUsageDescription` is absent in
both cases, and a test fails if the key appears.

## Dependencies

WhisperKit and seven transitive packages. All permissively licensed, listed in
[TREDJEPART.md](TREDJEPART.md). None performs network access as configured.

WhisperKit 0.18 is not annotated for Swift 6 and is given a retroactive unchecked
`Sendable` conformance. That is an assertion, not a compiler-verified fact. It
holds because calls reach it from the main actor, one recording at a time. Remove
it when WhisperKit annotates its own types.

## Build integrity

What a fresh clone builds is what was reviewed, not what the upstream
repositories serve on the day.

- **WhisperKit** is declared with `exactVersion` in `project.yml`, and
  `Package.resolved` is committed, so the seven transitive packages resolve to
  the same revisions on every machine.
- **The model and tokenizer** are fetched by `Scripts/fetch-model.sh` from fixed
  commit ids on Hugging Face, and every file is checked against
  `Scripts/model-checksums.txt` before the script reports success. A mismatch
  fails the script. The model is a third-party CoreML conversion of
  nb-whisper-small, not a file published by the National Library; the checksums
  pin the conversion that was reviewed.

## Deliberate omissions

- **No biometric lock.** The app is used hands-busy while driving. A Face ID gate
  at the moment of recording would defeat its purpose.
- **No certificate pinning.** There is no transport.
- **No screenshot blocking.** `userDidTakeScreenshotNotification` fires after the
  image exists. The hidden `isSecureTextEntry` trick is undocumented and can break
  without warning. The app does not offer what it cannot deliver.
