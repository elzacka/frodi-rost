# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last reviewed 2026-09-28.

**Contents**

- [Reporting a vulnerability](#reporting-a-vulnerability)
- [Supported versions](#supported-versions)
- [Threat model](#threat-model)
- [What happens in each scenario](#what-happens-in-each-scenario)
- [What is in use](#what-is-in-use)
- [Encryption](#encryption)
- [Origin](#origin)
- [File protection](#file-protection)
- [No network](#no-network)
- [Privacy](#privacy)
- [Dependencies](#dependencies)
- [Build integrity](#build-integrity)
- [Deliberate omissions](#deliberate-omissions)

---

## Reporting a vulnerability

Email **hei@tazk.no** with the subject `[SECURITY] Fróði røst - <description>`.
Include reproduction steps and impact. You will get an acknowledgement within
48 hours and an assessment within 7 days. No PGP key is published.

> [!IMPORTANT]
> Do not open a public GitHub issue.

## Supported versions

| Build                       | In&nbsp;scope                                      |
| --------------------------- | -------------------------------------------------- |
| The latest TestFlight build | Yes                                                |
| Earlier builds              | Only if the finding still reproduces on the latest |

Nothing is on the App Store yet. Every uploaded build is listed in
[CHANGELOG.md](CHANGELOG.md) with what changed in it.

## Threat model

The app assumes a passcode is set and iOS is not compromised.

|                      | Adversary                                                                                                                                                                                                             |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Defended against     | A locked device in someone else's hands, including forensic extraction after first unlock. A copy of a backup. Another app on the device. Anyone watching the screen, or the app switcher, while a transcript is open |
| Not defended against | A compromised OS, or an exploit chain on an unlocked device. An unlocked device in someone else's hands. A screenshot. Whatever happens to a file after export                                                        |

Measured against [OWASP MASVS](https://mas.owasp.org/MASVS/) v2.1.0, the
latest release as of 2026-09-28, at the profiles MAS-L2 and MAS-P: the app
holds a key that encrypts user data of a kind OWASP lists as high risk. The
storage, crypto, authentication, platform and code controls were read
against the code on 2026-09-27, not tested with MASTG. The four privacy
controls were tested on 2026-09-28; see *Privacy*. Every applicable control
is met except these, all under *Deliberate omissions*: local authentication
(AUTH-2, AUTH-3), enforced updates (CODE-2), reproducible builds
(MASWE-0075, under PRIVACY-3) and MAS-R. MASVS-NETWORK does not apply; there
is no transport.

## What happens in each scenario

| Scenario                                                 | Result                                                                                                                                                                                                                                                                                             |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Device lost or stolen, locked                            | Unreadable. The sealed files are `.complete` and the key is `WhenUnlocked`: neither is available while the device is locked, rebooted or not. Dates, durations and file names in the database are not encrypted; see *File protection*                                                              |
| Device lost, wiped or replaced                           | Every recording and transcript is gone, by design. The key exists only in that device's Secure Enclave and is never backed up. Export before changing device; see [PERSONVERN.md](PERSONVERN.md)                                                                                                   |
| App deleted                                              | The container goes with it: recordings, texts, names, origins, the word list, the database and the two settings in `UserDefaults`. The Secure Enclave key is a keychain item, which iOS may keep after the app is gone; it opens nothing, since everything it wrapped went with the container. The app's log lines, which hold no content, stay in the system log until iOS rotates it |
| Recording stopped while the device is locked             | Saved as plaintext under `.completeUnlessOpen`, which cannot be reopened until the device is unlocked. Sealed and transcribed at the unlock if the app is running then, otherwise when the app next comes to the front or launches. Never deleted                                                                                                                          |
| A call, Siri or another app takes the microphone         | The file recorded so far is closed as it is. When iOS hands the microphone back, the recording goes on in a new file beside it; when it does not, what is on disk is saved. The seal joins the files into one recording. Nothing recorded before the call is written over                             |
| Audio file imported                                      | Picked by the user in the system file picker, which gives the app that file and no other. Hashed and converted inside one coordinated read, as two passes over the file, and its metadata read afterwards; a file that lives only in iCloud Drive is downloaded by iOS' file provider first, not by the app. Converted and sealed in the temporary folder, and moved into the recordings folder sealed, together with its row: nothing of it is stored there unsealed. The original is not written to. A file Core Audio cannot read as audio is refused |
| Database or recordings altered outside the app          | A recording that has an origin is checked against it. A changed byte in the origin fails to open; an origin moved to another row names another recording; a changed date or length in the row, or other audio under the recording's name, disagrees with it. The recording page then says the details cannot be confirmed, and shows what was locked when the origin itself opens; an RTF export says the same. The transcript and the name are not covered, and a row whose origin is removed reads as one from an earlier build. See *Origin* |
| Backup copied, or restored to another device             | Unreadable. The key is bound to the device                                                                                                                                                                                                                                                         |
| Another app reads the app container                      | Finds ciphertext it cannot decrypt                                                                                                                                                                                                                                                                 |
| App killed during transcription or export                | Plaintext left in the temporary folder is removed at the next launch                                                                                                                                                                                                                               |
| Network interception                                     | Nothing to intercept. The app has no networking code                                                                                                                                                                                                                                               |
| Screen recording or mirroring while a transcript is open | The text and the recording's origin are hidden, and a recording's name gives way to its date, until capture stops                                                                                                                                                                                                                                                             |
| App switcher, or any other time the app is not in front  | The text and the origin are hidden, a name gives way to the date, and the rename field closes, before iOS takes the snapshot. A failed import is reported by count, not by file name                                                                                                                                                                                                                                                   |
| Lock Screen while a recording runs                       | The Live Activity shows «Tar opp», or «På pause» while the microphone is held elsewhere, the recorded time, and a stop button anyone holding the device can press. No title, no text, nothing from the recording. The recording that was stopped is saved, not lost                                                                          |
| Screenshot                                               | Captured. iOS offers no supported way to prevent one                                                                                                                                                                                                                                               |
| Transcript copied with «Kopier»                          | Stays on this device. The pasteboard item is `localOnly`, so Universal Clipboard does not carry it to a Mac or iPad, and it expires after five minutes. Once pasted into another app it is that app's data, as with export                                                                         |
| Recording exported                                       | Every guarantee here ends. Files and AirDrop keep the decrypted copy on the device; Mail, Messages and iCloud Drive do not. From the hand-over on, the file belongs to the app that received it                                                                                                    |
| Device unlocked, app open, in someone else's hands       | Readable, as with any app. There is no app-level lock; see *Deliberate omissions*                                                                                                                                                                                                                  |

## What is in use

Every security technology and setting the app relies on, and where it lives.
The sections below explain the choices.

| Area                       | Technology&nbsp;or&nbsp;setting                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Where                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Isolation                  | iOS app sandbox. No app group, no shared container. The widget extension runs in its own sandbox and gets nothing from the app but the Live Activity's state: a start time, the recorded time so far and whether the recording is paused                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | System                                                                   |
| Encryption at rest         | AES-GCM with a random 256-bit key per item: recording, transcript, a recording's name and origin, and the word list                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `RecordingVault`                                                         |
| Key wrapping               | P-256 key created in the Secure Enclave, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. The public key is cached in memory after the first read, so sealing never touches the keychain                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `RecordingVault`                                                         |
| File protection            | `.completeUnlessOpen` while recording and while awaiting the seal; `.complete` once sealed. Full table under *File protection*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `AudioStorage`                                                           |
| Backup                     | `isExcludedFromBackup` on the recordings folder, on every sealed file, on the word list and on the SwiftData store (`.store`, `-wal`, `-shm`). Re-applied at launch, on every folder access and after the first save                                                                                                                                                                                                                                                                                                                                                                                                                                     | `AudioStorage`, `RecordingController`, `WordList`                        |
| Transport                  | None. No `URLSession`, no ATS exceptions. A test scans the sources for networking APIs                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `Info.plist`, `IsolationTests`                                           |
| Background                 | `UIBackgroundModes` is `audio`, so a recording goes on after the screen locks. The control can start a recording without the app in front: the system launches the app in the background to perform `ToggleRecordingIntent`, and the recording then runs as any other. Transcription needs the key, and the key needs an unlocked device: a stop from the control on an unlocked device starts it in the background, and it runs until iOS suspends the app. After a stop on a locked device it waits                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `Info.plist`, `IsolationTests`                                           |
| Permissions                | `NSMicrophoneUsageDescription` only. `NSSpeechRecognitionUsageDescription` is absent, and tested absent                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `Info.plist`, `PrivacyTests`                                             |
| Speech to text             | nb-whisper, bundled, run by WhisperKit inside the app's own process. There is no other engine. The tokenizer's network fallback and its mitigation are under *No network*                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `Transcription`, `WhisperTranscriber`                                    |
| Logging                    | WhisperKit runs with `verbose: false` and `logLevel: .none`. The app writes recording events to the unified log — start and whether it came from the background, stop and its length, interruptions, a deferred seal and whether the device was locked at the time, an empty file removed, a Live Activity that did not start, a recording with no database to save to, an import that failed, by error type and code — and never content: no audio, no text, no word list, no name, and not the name of an imported file. File names are UUIDs. The log stays on the device and is read only with it connected to a Mac                                                                                                                                                                                                                                                                                              | `AudioRecorder.log`, `WhisperTranscriber` |
| Privacy manifest           | No tracking, no tracking domains, no collected data. Two accessed APIs: file timestamps, reason C617.1, and `UserDefaults`, reason CA92.1, for the export format and the word list field's height. A test asserts that set exactly                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `PrivacyInfo.xcprivacy`, `IsolationTests`                                |
| Screen capture             | Transcript, word list and a recording's origin are hidden, and a recording's name gives way to its date, while `UIScreen.isCaptured` is true and while the scene is not active. The state is read once, at the app's root, and handed down, so all of them follow one reading                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `CaptureGuard`, `ConcealmentReader`                                      |
| Keyboard                   | Two text fields: the word list and the field that renames a recording. Autocorrection and predictive text are off in both, so the names typed there do not enter the keyboard's learned dictionary, which lives outside the sandbox and in backups. The rename is the app's own field, not the system's title editor, whose field keeps autocorrection on whatever the view asks. The dictation key belongs to the system keyboard and cannot be removed by an app; what is dictated is handled as the device's dictation settings say                                                                                                                                                                                                                                                                                                                                                                                                                                                | `SettingsView`, `RecordingDetailView`                                    |
| Pasteboard                 | Copy is how a dictated note reaches another app on this device. It is a button, not text selection: selection brings the system copy menu, which writes to the general pasteboard, and Universal Clipboard carries that to every Mac and iPad on the same Apple Account. The one «Kopier» button writes with `localOnly` and a five-minute expiry instead. A test fails if selection returns or the pasteboard is written from anywhere else                                                                                                                                                                                                             | `RecordingDetailView`, `IsolationTests`                                  |
| Export                     | Decrypted on demand into the temporary directory, handed to the system share sheet, removed when the sheet closes. The RTF names the audio file with its SHA-256, and an imported recording's original with its own, and says so in the document when the origin cannot be confirmed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | `RecordingExport`, `ShareSheet`                                          |
| Export compliance          | `ITSAppUsesNonExemptEncryption` is `false`. The only cryptography is Apple's CryptoKit and the Secure Enclave                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `project.yml`                                                            |
| Compiler                   | `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_APPROACHABLE_CONCURRENCY: true`, `SWIFT_VERSION: 6`, `ENABLE_USER_SCRIPT_SANDBOXING: true`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `project.yml`                                                            |
| Memory safety              | Enhanced Security entitlements on the app: hardware memory tagging (`checked-allocations`) without soft mode, so a tag mismatch ends the process instead of being logged; guard objects on freed memory (`enhanced-security-version-string` 2); read-only platform memory (`dyld-ro`); runtime restrictions on loaded libraries and Mach messages (`platform-restrictions-string` 2). Memory tagging needs an A19 chip or later, iPhone 17 and iPhone Air onward; older devices get the rest. A test reads the entitlements from the signed executable. In the app's process on an iPhone 17 Pro, a read one byte past an allocation and a read after free both stop with `EXC_ARM_MTE_TAG_FAULT` | `project.yml`, `Frodi.entitlements`, `IsolationTests`                  |
| Build integrity            | WhisperKit pinned to an exact version, `Package.resolved` committed, model files fetched at a fixed revision and checked against a committed checksum list                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `project.yml`, `Scripts/fetch-model.sh`, `Scripts/model-checksums.txt`   |
| Attack surface kept closed | No URL schemes, document types, Handoff, Spotlight indexing or app group. No other app can open a file in Fróði; files come in only through the system file picker, limited to audio types, which gives the app a security-scoped URL to each picked file for the length of the import and nothing else. One extension, `FrodiWidgets`, which draws the control and the Live Activity: it runs in its own process, has no access to the app's container or keys, links no networking and declares no accessed API, and a test checks it is the only extension. One App Intent, `ToggleRecordingIntent`, an `AudioRecordingIntent`. The control the Action Button is set to, the Live Activity's stop button and the Shortcuts app run it, in the app's process, without confirmation once microphone access is granted, because a confirmation would defeat the button while driving. The compensating controls are the system's orange microphone indicator and the Live Activity, which iOS requires for as long as the recording runs and stops the recording without. Nothing is published as an App Shortcut, so Siri has no phrase for it | `Info.plist`, `ToggleRecordingIntent`, `IsolationTests` |

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
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:

| Part               | Meaning                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `WhenUnlocked`     | Usable only while the device is unlocked. The private key is needed only to open, and every open starts on an unlocked device: a transcription does not begin while the device is locked, and a run the user locks the screen on reads a plaintext copy it already holds. Sealing needs only the public key, which is kept in memory once read |
| `ThisDeviceOnly`   | Excluded from backups and from device migration                                                                                                                                                                                                                                                                                                 |

In memory, the transcript exists only while the detail screen or an export
needs it. Nothing pins or wipes it beyond that; iOS offers no supported way to.

A running transcription writes its progress to a sealed `.tekst` file after
every piece. Sealing needs only the public key, so it works in any lock
state. The run itself happens with the app in front and the screen kept
awake; there is no background task, so nothing ever asks for the key on a
locked device.

## Origin

Every recording that comes in gets an origin: a record of what it was at that
moment, sealed through the vault like the transcript and written once.

| Recording          | The origin holds                                                                                                                                                                          |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Made in the app    | Its file stem, its date and length, and the SHA-256 of the audio as sealed: the bytes an export hands over as `.m4a`                                                                      |
| Imported           | The same, the time of the import, and the file as it was picked: its name, size, codec, sample rate, channels, the creation date and common metadata it stated, a location left out, and the SHA-256 of its bytes |

It is written at the seal for a recording made here, from the bytes on their
way into the vault, and at the import for a file brought in, before the file
enters the recordings folder. `Recording.recordOrigin` is the only writer and
refuses a second write; nothing a user does reaches it. A name can be given
and changed; it is a separate field and leaves the origin alone.

It is checked three ways. A changed byte fails AES-GCM, so the origin does
not open. It names its recording's file stem, so an origin moved onto
another row does not match there. And its date, length and audio checksum
are compared with the row and the audio on disk: the date and length every
time the recording page opens, the audio when «Om opptaket» is opened, since
that reads the whole file. On any mismatch the page says the details cannot
be confirmed, and shows what was locked when the origin itself opened. An RTF
export says the same in the document. `OriginTests` covers each case, and a
row's date changed with `sqlite3` in the store was caught on the simulator.

What it does and does not prove:

| Claim                                                        | Holds? |
| ------------------------------------------------------------ | ------ |
| A change to the stored data made outside the app shows       | Partly. A changed or moved origin, and a changed date, length or audio, show for anyone who cannot run code as the app. The transcript and the name are sealed but not bound to their recording: one moved from another row opens without a warning. An origin removed from its row makes the recording look like one from an earlier build, with nothing left to compare. Sealing needs only the public key, so code running in this app's context on an unlocked device could seal a new origin. The threat model already excludes a compromised OS, and each of these needs write access to the app's container |
| The date is when the recording was made                      | As far as the device's clock is right. The user can set the clock, and there is no trusted timestamp; see *Deliberate omissions* |
| An imported file is the one that came in                     | The SHA-256 of the original identifies the file. It says nothing about who made it, or when |
| Exported audio is the audio that was locked                  | The RTF gives the audio file's SHA-256; a reader holding both can check it with `shasum -a 256`. It shows the two files match, not who handed them over |

A recording sealed by an earlier build has no origin, and none is written
after the fact: an origin written later would vouch for a past it never saw.
For the same reason, a crash in the one moment after the seal has removed the
plaintext and before the row takes the sealed name leaves that recording
without an origin: `reconcile` points the row at the sealed file, and nothing
seals it again. An import has the same window between moving its sealed file
in and saving its row: if the app dies there, or the save fails, `reconcile`
gives the file a row with no origin and no name.

## File protection

| State                       | Class                                   | Reason                                                                                                                                                                                                                                                    |
| --------------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recording in progress       | `.completeUnlessOpen`                   | `.complete` would block writes when the screen locks, which is exactly when recordings run. The file is linear PCM in a CAF container: an AAC file killed mid-write cannot be opened, and a recording must survive a crash. A call closes the file, and the recording goes on in a new one of the same class beside it (`X.1.caf` after `X.caf`); the seal joins them |
| Stopped, awaiting seal      | `.completeUnlessOpen`, closed           | Cannot be reopened until unlock, which is also when the seal happens                                                                                                                                                                                      |
| Sealed recording, word list | `.complete`                             | Ciphertext, and unreadable while the device is locked on top of that. Everything that opens either runs on an unlocked device. Sealing re-encodes PCM to AAC through a scratch copy; see the last row                                                     |
| Transcription progress      | `.completeUnlessOpen`                   | Already ciphertext. Written after every piece, which can be after the user has locked the screen; this class lets a new file be created then. Read back on an unlocked device                                                                             |
| Database                    | `.completeUntilFirstUserAuthentication` | iOS' default for the container. Holds dates, durations, file names and the sealed transcripts, names and origins; nothing in it is plaintext content                                                                                                                         |
| Plaintext for transcription | `.completeUnlessOpen`                   | Written and closed by the decrypt, then opened by the engine on the unlocked device the run starts on and held across the pieces; a held-open file of this class stays readable if the screen locks meanwhile. Removed in a `defer`, and the folder is emptied at launch                            |
| Import, while it is converted and sealed | `.completeUnlessOpen` for the converted PCM, `.complete` for the sealed copy | Both in the temporary folder. The sealed copy is moved into the recordings folder with its row and gets `.complete` and the backup flag there. Removed in a `defer`, and the folder is emptied at launch |
| Plaintext for export        | `.completeUnlessOpen`                   | Created and handed to the share sheet in one unlocked session. Removed when the sheet closes, and the folder is emptied at launch                                                                                                                         |

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
the tokenizer: WhisperKit falls back to Hugging Face when it cannot read
the tokenizer locally. The app therefore checks that both tokenizer files
exist before it creates WhisperKit, and reports the model as missing if
either is absent. A build phase fails the build itself when the model is not
in it, so such a build cannot be archived.

Picking a file that lives only in iCloud Drive makes iOS download it before
the app reads it. That request is the file provider's, made because the user
picked the file; the app's own code makes none. The same holds for the three
document links under «Mer om appen» in Innstillinger: they open GitHub in
Safari, which makes the request because the user tapped the link.

> [!NOTE]
> One qualification. WhisperKit ships with a copy of `swift-transformers`'
> `Hub` module, which contains an HTTP client and links the Network
> framework. Every time the model loads, WhisperKit's tokenizer loader
> creates a Hub client, and its constructor starts `NWPathMonitor`s: they
> ask iOS whether the device is online and send nothing. The client's
> requests are never made: the model and the tokenizer are read from the
> bundle, never fetched. The claim is «this app makes no network requests»,
> not «this binary contains no networking code». The second would be
> stronger, and it would be false.

## Privacy

MASVS 2.1.0 added four privacy controls, MASVS-PRIVACY. They were tested on
2026-09-28 with the MASTG's static iOS privacy tests against the uploaded
build 1.0 (9), and read against the code. Two findings are fixed in the
source since that build: an import keeps no location from the file (see
*Origin*), and the microphone's purpose string names notes and
conversations.

| Control                  | How the app meets it | Checked by |
| ------------------------ | -------------------- | ---------- |
| PRIVACY-1 Minimal access | One protected resource, the microphone, asked for at the first recording; iOS also asks once whether the Live Activity may run. Files come in through the system file picker, which gives the app each picked file and nothing else. WhisperKit, the one third-party library the app uses, runs in the app's process and gets the audio and the word list. An import keeps no location the file states | MASTG-TEST-0360 and -0362: one purpose string, and one protected resource in the binary, the microphone: the app's `requestRecordPermission`, and WhisperKit's `AVCaptureDevice` request for iOS before 17, in a live-streaming class the app does not use. No other protected-resource API. The app's only capability entitlements are Enhanced Security's; the widget has none |
| PRIVACY-2 No identification | No account, user ID, device identifier, advertising identifier or analytics. Recordings are named by random UUIDs, exported files by their date. An imported file is converted to PCM, so none of its metadata reaches an exported `.m4a`. The `.rtf` carries the name the user gave and, for an import, the original's file name; the guide says so | The binary references no `identifierForVendor`, `advertisingIdentifier`, App Attest or DeviceCheck. The import-to-AAC chain run on a file with a title and a location: the `.m4a` holds only the encoder's gapless-playback tag |
| PRIVACY-3 Transparency   | [PERSONVERN.md](PERSONVERN.md), linked in the app and in the App Store listing. The privacy manifest declares no tracking, no tracking domains and no collected data, and two accessed APIs with their reasons; the widget's declares nothing. The purpose string says what is recorded and that it stays on the device | MASTG-TEST-0281: the binary names three domains, github.com for the document links, huggingface.co in the Hub client and tazk.no in the contact address, and none is on DuckDuckGo's tracker list. The required-reason APIs the binary imports are file timestamps and `UserDefaults`, as declared. Reproducible builds (MASWE-0075): not met, see *Deliberate omissions* |
| PRIVACY-4 User control   | See, rename, export and delete each recording; edit the word list; withdraw microphone access in iOS Settings; delete the app. Nothing is collected, so there is no consent to withdraw. An imported file's name and tags belong to its origin: a rename changes the list and the `.rtf` heading, while «Om opptaket» keeps both and the `.rtf` names the original. A `.txt` export carries neither, and deleting the recording removes them | PERSONVERN.md *Rettighetene dine*, read against the app |

Not tested: MASTG-TEST-0361 and -0363 hook the running app, which needs an
instrumented build on a device; the static tests cover the same APIs. The
App Store privacy label cannot be read through the App Store Connect API and
was not checked.

## Dependencies

Versions and licences are in [TREDJEPART.md](TREDJEPART.md), which a test
keeps in step with `Package.resolved` and the in-app licence screen.

WhisperKit is the `WhisperKit` product of `argmax-oss-swift`, pinned to one
version. It brings one package with it, `swift-argument-parser`, and carries
its own copy of `swift-transformers`' Hub and Tokenizers sources; nothing
else is resolved. The package is annotated for Swift 6, and the app makes no
`Sendable` assertion on its behalf.

## Build integrity

What a fresh clone builds is what was reviewed, not what the upstream
repositories serve on the day. The model is a third-party CoreML conversion
of nb-whisper-small, not published by the National Library. The checksums
guarantee that the files are the ones measured on 2026-09-07; they do
not guarantee that the files are benign, since a weights file cannot be read
for intent. Because the model never touches the network, what could be wrong
with it is transcription quality and bias, not exfiltration.

## Deliberate omissions

| Omission                       | Reason                                                                                                                                                                                                                         |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| No app-level lock              | The device lock already applies: a locked device must be unlocked before anything recorded can be played or read. A second lock, inside the app, would be one more obstacle in the car                                         |
| No auto-lock while transcribing | A transcription keeps the screen awake, so the device does not lock itself for as long as it runs: about four minutes for an hour of interview on an iPhone 17 Pro. Locking would suspend the run; what is done is saved, and it goes on when the app is next in front |
| No certificate pinning         | There is no transport                                                                                                                                                                                                          |
| No jailbreak detection (MAS-R) | The threat model assumes iOS is not compromised, and a check that a compromised OS can lie to adds nothing. The source is public instead, for audit                                                                            |
| No forced update               | Checking would need a network request. TestFlight expires builds on its own; an organisation that needs a minimum version enforces it through MDM                                                                              |
| No advisory feed               | Dependencies are pinned, so an upstream fix reaches the app only when someone bumps the version. Nothing watches `argmax-oss-swift` or `swift-argument-parser` for advisories; the check is done by hand before a release             |
| No overwrite on delete         | The file is already ciphertext, with its only key wrapped inside it, so deleted blocks are noise. iOS deletes by discarding the per-file key, and APFS is copy-on-write, so an overwrite would land on different blocks anyway |
| No trusted timestamp           | Proving to someone else when a recording was made needs a timestamp authority, which is a network request. The origin's date is the device clock's |
| No reproducible build          | MASWE-0075 asks that anyone can rebuild the app from source and get the published binary bit for bit. The App Store encrypts and re-signs what it serves, so a build from source cannot be compared with it. What stands in its place: the source is public, the dependencies are pinned and the model files are checked against committed checksums; see *Build integrity* |
| Imported originals not kept    | The app keeps its converted copy and the original's SHA-256. Keeping the original as well would double the storage and the plaintext to handle; the checksum lets anyone holding the original match it |
| No screenshot blocking         | `userDidTakeScreenshotNotification` fires after the image exists, and the undocumented `isSecureTextEntry` trick can break without warning. The app does not offer what it cannot deliver                                      |
| No pointer authentication, no CPA2 | Enhanced Security's build setting compiles the app as arm64e, and WhisperKit builds as arm64 only, so the app cannot import it. The system frameworks the app calls are arm64e; the app's own code and WhisperKit are not. CPA2, the stronger memory tagging iOS 27 offers on A20 Pro and later, needs the arm64e.x1 architecture and is out of reach for the same reason. Memory tagging itself does not depend on arm64e and is on |
| No Enhanced Security in the widget | The extension draws the control and the Live Activity and reads nothing but the activity's state, which the app wrote. It runs in its own process, with no access to the app's container or keys |

---

[Back to top](#security-policy)
