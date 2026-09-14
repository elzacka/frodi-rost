# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last reviewed 14 September 2026.

## Reporting a vulnerability

Email **hei@tazk.no**, subject `[SECURITY] Fróði røst - <description>`.
Include reproduction steps and impact. Acknowledgement within 48 hours,
assessment within 7 days. Do not open public GitHub issues. No PGP key is
published.

## Supported versions

| Build | In scope |
|---|---|
| The latest TestFlight build | Yes |
| Earlier builds | Only if the finding still reproduces on the latest |

Nothing is on the App Store yet. Every uploaded build is listed in
[CHANGELOG.md](CHANGELOG.md), with what changed in it.

## Threat model

The app assumes a passcode is set and iOS is not compromised.

| | Adversary |
|---|---|
| Defended against | A locked device in someone else's hands, including forensic extraction of its storage after first unlock. A copy of a backup. Another app on the device. Anyone watching the screen over the air, or the app switcher, while a transcript is open |
| Not defended against | A compromised OS, or an exploit chain on an unlocked device. An unlocked device in someone else's hands. A screenshot. Whatever happens to a file after export |

Measured against [OWASP MASVS](https://mas.owasp.org/MASVS/) v2.1.0 on
14 September 2026, by reading the controls against the code, not by running
the MASTG tests. By OWASP's own examples the app is a MAS-L2+P profile: it
holds a key that encrypts user data, and the data is of the kind they list as
high risk. Every L2 and P control that applies is met, with one exception:
local authentication (MASVS-AUTH-2 and AUTH-3), under *Deliberate omissions*
below. MASVS-NETWORK does not apply; there is no transport. MAS-R is not
applied, on the reasoning MASVS itself gives for public-interest apps: the
source is open, and obfuscation or jailbreak detection would make the app
harder to audit without making the data safer.

## What happens in each scenario

| Scenario | Result |
|---|---|
| Device lost or stolen, locked, not rebooted | The sealed audio and the transcripts are ciphertext under a key the Secure Enclave will unwrap for the app's own code after the first unlock since boot. So the protection against this attacker is the app sandbox and the Enclave's refusal to hand the key to anyone but this app, not the lock screen. This is the class chosen on 14 September 2026 so that a transcription can run on the charger with the screen locked; from 13 to 14 September it was `WhenUnlocked`, which would have refused even the app. Dates, durations and file names in the database are not encrypted |
| Device lost or stolen, locked, rebooted | Unreadable until the passcode is entered. Both the files and the key require the first unlock |
| Device lost, wiped or replaced | Every recording and transcript is gone. The key exists only in that device's Secure Enclave and is in no backup. Export is the only way to keep a recording |
| Recording stopped while the device is locked | Saved as plaintext under `NSFileProtectionCompleteUnlessOpen`, which cannot be reopened until the device is unlocked. Sealed and transcribed at the next unlock or launch. Never deleted |
| Backup copied, or restored to another device | Unreadable. The key is device-bound |
| Another app reads the app container | Finds encrypted data it cannot decrypt |
| App killed during transcription or export | Plaintext left in the temporary folder is removed at the next launch |
| Network interception | Nothing to intercept. The app has no networking code |
| Screen recording or mirroring while a transcript is open | Text hidden until capture stops |
| App switcher, or any other time the app is not in front | Text hidden before iOS takes the snapshot |
| Screenshot | Captured. iOS offers no supported way to prevent one |
| Transcript copied with «Kopier» | Stays on this device. The pasteboard item is marked local-only, so Universal Clipboard does not carry it to a Mac or iPad, and it expires after five minutes |
| Recording exported | Every guarantee here ends. The files belong to the app you hand them to, with that app's storage, backup and sync behaviour |
| Device unlocked, app open, in someone else's hands | Readable, as with any app |

## What is in use

Every security technology and setting the app relies on, and where it lives.
The sections below explain the choices.

| Area | Technology or setting | Where |
|---|---|---|
| Isolation | iOS app sandbox. No app group, no shared container | System |
| Encryption at rest | AES-GCM, one random 256-bit key per recording and per transcript | `RecordingVault` |
| Key wrapping | P-256 key created in the Secure Enclave, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. The public key is kept in memory once read, so sealing does not touch the keychain | `RecordingVault` |
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
| Screen capture | Transcript and word list hidden while `UIScreen.isCaptured` is true, and while the scene is not active | `CaptureGuard` |
| Keyboard | The word list is the only text field. Autocorrection and predictive text are off, so the names typed there do not enter the keyboard's learned dictionary, which lives outside the sandbox and in backups | `InfoView` |
| Pasteboard | The transcript cannot be selected. One button copies it, with `localOnly` and a five minute expiry. A test fails if selection returns or the pasteboard is written from anywhere else | `RecordingDetailView`, `IsolationTests` |
| Export | Decrypted on demand to the temporary directory, handed to the system share sheet, removed when the sheet closes | `RecordingExport`, `ShareSheet` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave | `project.yml` |
| Compiler | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_APPROACHABLE_CONCURRENCY: true`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true` | `project.yml` |
| Build integrity | WhisperKit pinned to an exact version, `Package.resolved` committed, model files fetched at a fixed revision and checked against a committed checksum list | `project.yml`, `Scripts/fetch-model.sh`, `Scripts/model-checksums.txt` |
| Attack surface kept closed | No URL schemes, no document types, no `NSUserActivity` (Handoff), no Spotlight indexing, no extensions, no app group. One App Intent, `ToggleRecordingIntent`, which any Shortcut or automation can run without confirmation once microphone access is granted; that is what the Action Button uses, and it is deliberate. The compensating control is the system's: iOS shows the orange microphone indicator whenever the app holds the microphone, in the foreground or not, so a recording started by an automation is visible whenever the screen is on | `Info.plist`, `ToggleRecordingIntent` |

## Encryption

Each recording and transcript is sealed with AES-GCM under a per-item 256-bit key.
That key is wrapped by a P-256 key created inside the Secure Enclave. The private
key cannot be extracted. That stops the key from being copied; it does not stop
code running on this device in the app's context from asking the Enclave to use
it. What limits that is the access class.

GCM authenticates as well as encrypts: a sealed file altered by so much as one
byte fails to open, so the app never plays modified audio or shows a modified
transcript as if it were the original. `VaultTests` covers it. That is integrity
against a third party, not non-repudiation: nothing stops the user of an unlocked
device from deleting a recording, and no hash kept beside it would.

Access control is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

- **AfterFirstUnlock**: the key can be used by this app once the device has
  been unlocked once since boot, including while it is locked again. That is
  what lets a transcription run while the device sits locked on the charger,
  see *Background transcription* below. The stricter WhenUnlocked was the
  class from 13 to 14 September 2026, and would have let a locked device
  refuse even the app. Decided by the app's owner on 14 September 2026: an
  hour of interview transcribed overnight is worth that margin, and what
  remains between the two classes is the sandbox and the Enclave's binding of
  the key to this app's code. A key created by a build in between keeps the
  stricter class: the class is fixed at creation, and the app does not rotate
  keys. On such a device the background run finds nothing it can open and
  ends; transcription then runs when the app is open.
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

A transcription in progress writes what it has so far to a `.tekst` file beside
the recording after every piece, sealed through the same vault as the text.
Sealing needs only the public key, so this works whatever the lock state; the
file is deleted when the transcript is saved. It is what lets an hour of audio
be transcribed across suspensions without starting over.

### Background transcription

With the app open, a transcription runs with the screen kept awake. With the
device on a charger, iOS runs the app's `BGProcessingTask`
(`com.Tazk.Frodi.transcribe`) while the device is idle, screen locked, and the
task picks up whatever is waiting from where it left off. It ends at the next
piece when iOS calls time. For that to work the sealed audio, the progress
file and the key all have to be usable after the first unlock, which is the
reason for the classes above. The plaintext copy the model reads is opened
once, while it can be, and held open across the pieces; a fresh open of a
`.completeUnlessOpen` file on a locked device would fail.

In memory, the text exists while the detail screen shows it and is cleared when
the screen closes; the export holds it until the files are written. Nothing pins
or wipes memory beyond that, and iOS offers no supported way to.

## File protection

| State | Class | Reason |
|---|---|---|
| Recording in progress | `.completeUnlessOpen` | `.complete` blocks writes when the screen locks, which is when recordings run. The file is linear PCM in a CAF container: an AAC file killed mid-write cannot be opened, and a recording must survive a crash |
| Stopped, awaiting seal | `.completeUnlessOpen`, closed | Cannot be reopened until the device is unlocked, which is also when the seal happens |
| Sealed recording | `.completeUntilFirstUserAuthentication` | Ciphertext under a key of the same class. Readable by the app on the charger with the screen locked, which is what background transcription needs; unreadable from boot until the first unlock. The seal encodes the PCM to AAC through a scratch copy, which is temporary plaintext as below |
| Transcription progress | `.completeUntilFirstUserAuthentication` | Ciphertext already; read back by the background run |
| Temporary plaintext | `.completeUnlessOpen` | Held open for the length of the job, so the lock does not stop it; cannot be reopened once closed. Removed in a `defer`; the folder is emptied at launch |

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

WhisperKit and seven transitive packages. All permissively licensed, listed
with versions and links in [TREDJEPART.md](TREDJEPART.md), which a test keeps
level with `Package.resolved` and the app's own licence list. None performs
network access as configured.

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
  nb-whisper-small, not a file published by the National Library. The checksums
  guarantee that every clone builds the files measured on 7 September 2026, not
  that those files are benign: a CoreML weights file cannot be read for intent.
  Since the model never touches the network, what could be wrong inside it is
  transcription quality and bias, not exfiltration.

## Where the guarantees end

| Boundary | What follows |
|---|---|
| Export | The files are decrypted for the app you choose in the share sheet, and from then on they are that app's. Files and AirDrop keep them on the device; Mail, Messages and iCloud Drive do not. The app has no say after the hand-over |
| Device lost, wiped or replaced | Permanent loss of every recording and transcript. This is the cost of a key that exists nowhere else, and it is deliberate. PERSONVERN.md tells the user to export before changing device |
| An unlocked device | Everything is readable, as in any app. There is no lock of the app's own; see below |

## Deliberate omissions

- **No biometric lock.** The app is used hands-busy while driving. A Face ID gate
  at the moment of recording would defeat its purpose.
- **No certificate pinning.** There is no transport.
- **No jailbreak detection.** The threat model assumes iOS is not compromised,
  and a check that a compromised OS can lie to adds nothing. The source is
  public so that the app can be audited instead.
- **No forced update.** The app cannot check for a newer version without a
  network request. TestFlight expires builds on its own; on the App Store, an
  organisation that needs a minimum version enforces it through its MDM.
- **No advisory feed.** Dependencies are pinned to exact versions, so a fix
  upstream reaches the app only when a person bumps the version. Nothing
  watches for advisories on WhisperKit or its seven packages.
- **No overwrite on delete.** Deleting a recording removes the file and nothing
  else, because there is nothing an overwrite would add. The file is ciphertext,
  and the only copy of its key is wrapped inside it, so the deleted blocks are
  noise. iOS deletes by discarding the per-file key, and APFS is copy-on-write,
  so an overwrite would land on other blocks and leave the old ones as they were.
- **No screenshot blocking.** `userDidTakeScreenshotNotification` fires after the
  image exists. The hidden `isSecureTextEntry` trick is undocumented and can break
  without warning. The app does not offer what it cannot deliver.
