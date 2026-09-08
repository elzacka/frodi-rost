# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last reviewed 07.09.26.

## Reporting a vulnerability

Email **hei@tazk.no**, subject `[SECURITY] Frodi røst - <description>`.
Include reproduction steps and impact. Acknowledgement within 48 hours,
assessment within 7 days. Do not open public GitHub issues.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Phone lost or stolen, locked | Audio and transcripts unreadable |
| Backup copied, or restored to another phone | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while a transcript is open | Text hidden until capture stops |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Phone unlocked, app open, in someone else's hands | Readable, as with any app |

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
because Apple documents the flag as resettable guidance. Encryption is what
carries the guarantee.

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
