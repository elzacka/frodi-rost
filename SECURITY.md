# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last reviewed 15 September 2026.

## Reporting a vulnerability

Email **hei@tazk.no** with the subject `[SECURITY] Fróði røst - <description>`.
Include reproduction steps and impact. You will get an acknowledgement within
48 hours and an assessment within 7 days. Do not open a public GitHub issue.
No PGP key is published.

## Supported versions

| Build | In scope |
|---|---|
| The latest TestFlight build | Yes |
| Earlier builds | Only if the finding still reproduces on the latest |

Nothing is on the App Store yet. Every uploaded build is listed in
[CHANGELOG.md](CHANGELOG.md) with what changed in it.

## Threat model

The app assumes a passcode is set and iOS is not compromised.

| | Adversary |
|---|---|
| Defended against | A locked device in someone else's hands, including forensic extraction after first unlock. A copy of a backup. Another app on the device. Anyone watching the screen, or the app switcher, while a transcript is open |
| Not defended against | A compromised OS, or an exploit chain on an unlocked device. An unlocked device in someone else's hands. A screenshot. Whatever happens to a file after export |

Measured against [OWASP MASVS](https://mas.owasp.org/MASVS/) v2.1.0 on
14 September 2026, by reading the controls against the code rather than by
running MASTG. The profile is MAS-L2+P: the app holds a key that encrypts
user data of a kind OWASP lists as high risk. Every applicable L2 and P
control is met, with two exceptions: local authentication (AUTH-2, AUTH-3)
and MAS-R, both under *Deliberate omissions*. MASVS-NETWORK does not apply;
there is no transport.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Device lost or stolen, locked, not rebooted | The files are ciphertext. The Secure Enclave unwraps the key for this app only, and only after the first unlock since boot. The barrier is therefore the sandbox and the Enclave binding, not the lock screen; see *Encryption*. Dates, durations and file names in the database are not encrypted |
| Device lost or stolen, locked, rebooted | Unreadable until the passcode is entered. Both the file class and the key class require the first unlock |
| Device lost, wiped or replaced | Every recording and transcript is gone, by design. The key exists only in that device's Secure Enclave and is never backed up. Export before changing device; see [PERSONVERN.md](PERSONVERN.md) |
| Recording stopped while the device is locked | Saved as plaintext under `.completeUnlessOpen`, which cannot be reopened until the device is unlocked. Sealed and transcribed at the next unlock or launch. Never deleted |
| Backup copied, or restored to another device | Unreadable. The key is bound to the device |
| Another app reads the app container | Finds ciphertext it cannot decrypt |
| App killed during transcription or export | Plaintext left in the temporary folder is removed at the next launch |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while a transcript is open | The text is hidden until capture stops |
| App switcher, or any other time the app is not in front | The text is hidden before iOS takes the snapshot |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Transcript copied with «Kopier» | Stays on this device. The pasteboard item is `localOnly`, so Universal Clipboard does not carry it to a Mac or iPad, and it expires after five minutes. Once pasted into another app it is that app's data, as with export |
| Recording exported | Every guarantee here ends. Files and AirDrop keep the decrypted copy on the device; Mail, Messages and iCloud Drive do not. From the hand-over on, the file belongs to the app that received it |
| Device unlocked, app open, in someone else's hands | Readable, as with any app. There is no app-level lock; see *Deliberate omissions* |

## What is in use

Every security technology and setting the app relies on, and where it lives.
The sections below explain the choices.

| Area | Technology or setting | Where |
|---|---|---|
| Isolation | iOS app sandbox. No app group, no shared container | System |
| Encryption at rest | AES-GCM with a random 256-bit key per item: recording, transcript and word list | `RecordingVault` |
| Key wrapping | P-256 key created in the Secure Enclave, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. The public key is cached in memory after the first read, so sealing never touches the keychain | `RecordingVault` |
| File protection | `.completeUnlessOpen` while recording and while awaiting the seal; `.completeUntilFirstUserAuthentication` once sealed. Full table under *File protection* | `AudioStorage` |
| Backup | `isExcludedFromBackup` on the recordings folder, on every sealed file, on the word list and on the SwiftData store (`.store`, `-wal`, `-shm`). Re-applied at launch, on every folder access and after the first save | `AudioStorage`, `RecordingController`, `WordList` |
| Transport | None. No `URLSession`, no ATS exceptions. A test scans the sources for networking APIs | `Info.plist`, `IsolationTests` |
| Background | `UIBackgroundModes` is `audio` and `processing`. The `BGProcessingTask` `com.Tazk.Frodi.transcribe` resumes transcription while the device charges, locked. Detail under *Background transcription* | `Info.plist`, `IsolationTests`, `BackgroundTranscription` |
| Permissions | `NSMicrophoneUsageDescription` only. `NSSpeechRecognitionUsageDescription` is absent, and tested absent | `Info.plist`, `PrivacyTests` |
| Speech to text | nb-whisper, bundled, run by WhisperKit inside the app's own process. There is no other engine. The tokenizer's network fallback and its mitigation are under *No network* | `Transcription`, `WhisperTranscriber` |
| Logging | WhisperKit runs with `verbose: false` and `logLevel: .none`. The app writes recording events to the unified log — start, stop and its length, interruptions, a deferred seal, a refused background task — and never content: no audio, no text, no word list. File names are UUIDs. The log stays on the device and is read only with it connected to a Mac | `AudioRecorder.log`, `BackgroundTranscription.log`, `WhisperTranscriber` |
| Privacy manifest | No tracking, no tracking domains, no collected data. One accessed API: file timestamps, reason C617.1 | `PrivacyInfo.xcprivacy`, `IsolationTests` |
| Screen capture | Transcript and word list are hidden while `UIScreen.isCaptured` is true and while the scene is not active | `CaptureGuard` |
| Keyboard | The word list is the only text field. Autocorrection and predictive text are off, so the names typed there do not enter the keyboard's learned dictionary, which lives outside the sandbox and in backups | `SettingsView` |
| Pasteboard | Copy is how a dictated note reaches another app on this device. It is a button, not text selection: selection brings the system copy menu, which writes to the general pasteboard, and Universal Clipboard carries that to every Mac and iPad on the same Apple Account. The one «Kopier» button writes with `localOnly` and a five-minute expiry instead. A test fails if selection returns or the pasteboard is written from anywhere else | `RecordingDetailView`, `IsolationTests` |
| Export | Decrypted on demand into the temporary directory, handed to the system share sheet, removed when the sheet closes | `RecordingExport`, `ShareSheet` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave | `project.yml` |
| Compiler | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_APPROACHABLE_CONCURRENCY: true`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true` | `project.yml` |
| Build integrity | WhisperKit pinned to an exact version, `Package.resolved` committed, model files fetched at a fixed revision and checked against a committed checksum list | `project.yml`, `Scripts/fetch-model.sh`, `Scripts/model-checksums.txt` |
| Attack surface kept closed | No URL schemes, document types, Handoff, Spotlight indexing, extensions or app group. One App Intent, `ToggleRecordingIntent` («Start eller stopp opptak»), published as an App Shortcut so the Action Button can run it. The same publication makes it reachable from the Shortcuts app, automations and Siri; iOS offers no way to admit the button and refuse the rest. It runs without confirmation once microphone access is granted, because a confirmation would defeat the button while driving. The compensating control is the system's: the orange microphone indicator shows whenever the app holds the microphone, in the foreground or not | `Info.plist`, `ToggleRecordingIntent` |

## Encryption

GCM authenticates as well as encrypts. A sealed file altered by a single byte
fails to open, so the app never plays modified audio or shows a modified
transcript as if it were the original. `VaultTests` covers it. That is
integrity against a third party, not non-repudiation: the user of an unlocked
device can still delete a recording, and no hash kept beside it would stop
that.

The wrapping key cannot be extracted from the Secure Enclave. That stops the
key from being copied; it does not stop code running in this app's context
from asking the Enclave to use it. What limits that is the access class,
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:

| Part | Meaning |
|---|---|
| `AfterFirstUnlock` | Usable once the device has been unlocked since boot, including while it is locked again. This is what lets transcription run on the charger with the screen locked; see *Background transcription*. Builds 5 and 6 created the key under the stricter `WhenUnlocked`. Keys are not rotated, so a device that ran those builds gets no background runs until the app is reinstalled |
| `ThisDeviceOnly` | Excluded from backups and from device migration |

In memory, the transcript exists only while the detail screen or an export
needs it. Nothing pins or wipes it beyond that; iOS offers no supported way to.

### Background transcription

A running transcription writes its progress to a sealed `.tekst` file after
every piece. Sealing needs only the public key, so it works in any lock
state. In the foreground the screen stays awake. On a charger, the
`BGProcessingTask` `com.Tazk.Frodi.transcribe` runs while the device is idle
and locked, resumes from the last piece, and stops when iOS ends the task.
The plaintext copy the model reads is opened once and held across the pieces,
because a fresh open would fail on a locked device.

This has not yet run on a device. The simulator cannot execute a
`BGProcessingTask`.

## File protection

| State | Class | Reason |
|---|---|---|
| Recording in progress | `.completeUnlessOpen` | `.complete` would block writes when the screen locks, which is exactly when recordings run. The file is linear PCM in a CAF container: an AAC file killed mid-write cannot be opened, and a recording must survive a crash |
| Stopped, awaiting seal | `.completeUnlessOpen`, closed | Cannot be reopened until unlock, which is also when the seal happens |
| Sealed recording, word list | `.completeUntilFirstUserAuthentication` | Ciphertext under a key of the same class: readable on the charger with the screen locked, which background transcription needs, and unreadable before the first unlock since boot. Sealing re-encodes PCM to AAC through a scratch copy; see the last row |
| Transcription progress | `.completeUntilFirstUserAuthentication` | Already ciphertext. Read back by the background run |
| Temporary plaintext | `.completeUnlessOpen` | Held open for the length of the job so a lock does not stop it; cannot be reopened once closed. Removed in a `defer`, and the folder is emptied at launch |

The backup flag is re-applied rather than trusted. Apple documents it as
resettable by file operations, and SQLite creates `-wal` and `-shm` only on
the first write. Encryption carries the guarantee; the flag keeps the
unencrypted dates, durations and file names out of backups on a best-effort
basis.

## No network

The app makes no network requests and sends no telemetry. `IsolationTests`
fails the build on an ATS exception, an undeclared background mode, a privacy
manifest that declares collected data, or `URLSession`, `URLRequest`,
`NWConnection` or `import Network` anywhere in the sources.

The model is bundled and loaded with `download: false` and explicit local
paths, so a missing model fails rather than fetches. That flag does not cover
the tokenizer: WhisperKit 0.18 falls back to Hugging Face when it cannot read
the tokenizer locally. The app therefore checks that both tokenizer files
exist before it creates WhisperKit, and reports the model as missing if
either is absent. A build phase fails the build itself when the model is not
in it, so such a build cannot be archived.

**One qualification.** WhisperKit depends on `swift-transformers`, whose
`Hub` target contains an HTTP client. It is linked into the binary, and
nothing in the app calls it: the model and the tokenizer are read from the
bundle, never fetched. The claim is «this app makes no network requests», not
«this binary contains no networking code». The second would be stronger, and
it would be false.

## Dependencies

Versions and licences are in [TREDJEPART.md](TREDJEPART.md), which a test
keeps in step with `Package.resolved` and the in-app licence screen.

WhisperKit 0.18 is not annotated for Swift 6. The app gives it a retroactive
`@unchecked Sendable` conformance. That is an assertion, not something the
compiler verifies, and it holds only because every call comes from the main
actor, one recording at a time. Remove it when WhisperKit annotates its own
types.

## Build integrity

What a fresh clone builds is what was reviewed, not what the upstream
repositories serve on the day. The model is a third-party CoreML conversion
of nb-whisper-small, not published by the National Library. The checksums
guarantee that the files are the ones measured on 7 September 2026; they do
not guarantee that the files are benign, since a weights file cannot be read
for intent. Because the model never touches the network, what could be wrong
with it is transcription quality and bias, not exfiltration.

## Deliberate omissions

| Omission | Reason |
|---|---|
| No biometric lock | The app is used with hands busy, while driving. A Face ID gate at the moment of recording would defeat its purpose |
| No certificate pinning | There is no transport |
| No jailbreak detection (MAS-R) | The threat model assumes iOS is not compromised, and a check that a compromised OS can lie to adds nothing. The source is public instead, for audit |
| No forced update | Checking would need a network request. TestFlight expires builds on its own; an organisation that needs a minimum version enforces it through MDM |
| No advisory feed | Dependencies are pinned, so an upstream fix reaches the app only when someone bumps the version. Nothing watches WhisperKit or its seven packages for advisories |
| No overwrite on delete | The file is already ciphertext, with its only key wrapped inside it, so deleted blocks are noise. iOS deletes by discarding the per-file key, and APFS is copy-on-write, so an overwrite would land on different blocks anyway |
| No screenshot blocking | `userDidTakeScreenshotNotification` fires after the image exists, and the undocumented `isSecureTextEntry` trick can break without warning. The app does not offer what it cannot deliver |
