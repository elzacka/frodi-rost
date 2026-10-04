# Security Policy

Fróði røst records audio and transcribes it on the device. Nothing is transmitted.

Last updated 2026-10-04.

**Contents**

- [Reporting a vulnerability](#reporting-a-vulnerability)
- [Supported versions](#supported-versions)
- [Threat model](#threat-model)
- [What happens in each scenario](#what-happens-in-each-scenario)
- [Controls](#controls)
- [File protection](#file-protection)
- [Origin](#origin)
- [No network](#no-network)
- [Privacy](#privacy)
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

| Build | In&nbsp;scope |
| --- | --- |
| The latest App Store build | Yes |
| Earlier builds | Only if the finding still reproduces on the latest |

Every App Store build is listed in [CHANGELOG.md](CHANGELOG.md).

## Threat model

The app assumes a passcode is set and iOS is not compromised.

| | Adversary |
| --- | --- |
| Defended against | A locked device in someone else's hands, including forensic extraction after first unlock. A copy of a backup. Another app on the device. Anyone watching the screen, or the app switcher, while a transcript is open |
| Not defended against | A compromised OS, or an exploit chain on an unlocked device. An unlocked device in someone else's hands. A screenshot. Whatever happens to a file after export |

Measured against [OWASP MASVS](https://mas.owasp.org/MASVS/) v2.1.0, the latest release as of 2026-09-28, at MAS-L2 and MAS-P: the app holds a key that encrypts user data OWASP lists as high risk. The storage, crypto, authentication, platform and code controls were read against the code on 2026-09-27, not tested with MASTG. The privacy controls were tested; see *Privacy*.

Every applicable control is met except local authentication (AUTH-2, AUTH-3), enforced updates (CODE-2), reproducible builds (MASWE-0075) and MAS-R; see *Deliberate omissions*. MASVS-NETWORK does not apply.

## What happens in each scenario

| Scenario | Result |
| --- | --- |
| Device lost or stolen, locked | Unreadable: sealed files are `.complete` and the key is `WhenUnlocked`, rebooted or not. Dates, durations and file names in the database are not encrypted |
| Device lost, wiped or replaced | Every recording and transcript is gone, by design: the key exists only in that device's Secure Enclave. Export before changing device |
| Backup copied, or restored to another device | Unreadable. The key is bound to the device |
| App deleted | The container goes with it. The Secure Enclave key may outlive the app as a keychain item and opens nothing. Log lines, which hold no content, stay until iOS rotates the log |
| Recording stopped while the device is locked | Kept as plaintext under `.completeUnlessOpen`, unreadable until unlock. Sealed and transcribed at the unlock if the app runs, otherwise when it next comes to the front. Never deleted |
| A call, Siri or another app takes the microphone | The file so far is closed. The recording goes on in a new file when the microphone returns; the seal joins them. Nothing is written over |
| Audio file imported | The system file picker gives the app that file only. Converted and sealed in the temporary folder, then moved in sealed with its row. The original is not written to. A file Core Audio cannot read is refused |
| Database or recordings altered outside the app | Checked against the recording's origin. On a mismatch the recording page and an RTF export say the details cannot be confirmed. See *Origin* |
| Another app reads the container | Finds ciphertext |
| App killed during transcription or export | Plaintext left in the temporary folder is removed at the next launch |
| Screen recorded or mirrored, or the app not in front | Text, word list and origin are hidden, a name gives way to the date and the rename field closes, before iOS takes the app switcher snapshot. A failed import is reported by count, not by file name |
| Lock Screen while recording | The Live Activity shows «Tar opp» or «På pause», the time and a stop button anyone holding the device can press. Nothing from the recording. A stopped recording is saved |
| Screenshot | Captured; see *Deliberate omissions* |
| Transcript copied with «Kopier» | Stays on this device and expires after five minutes. Once pasted, it is the other app's data |
| Recording exported | Every guarantee here ends. Files and AirDrop keep the decrypted copy on the device; Mail, Messages and iCloud Drive do not |
| Device unlocked, app open, in someone else's hands | Readable, as with any app; see *Deliberate omissions* |

## Controls

| Area | Control | Where |
| --- | --- | --- |
| Isolation | iOS sandbox, no app group or shared container. The widget extension has its own sandbox and gets only the Live Activity's state: start time, recorded time, paused or not. It links no networking | System |
| Attack surface | No URL schemes, document types, Handoff or Spotlight indexing. Files enter only through the system file picker, limited to audio. One extension and one App Intent, `ToggleRecordingIntent`. The control, the Live Activity's stop button and the Shortcuts app run it without confirmation once microphone access is granted, since a confirmation would defeat the button while driving. The orange microphone indicator and the Live Activity, which iOS requires while recording, compensate. No App Shortcut and no Siri phrase | `Info.plist`, `ToggleRecordingIntent`, `IsolationTests` |
| Encryption at rest | AES-GCM with a random 256-bit key per item: recording, transcript, name, origin and word list. A sealed file altered by one byte fails to open (`VaultTests`). Decrypted text lives in memory only while a screen or an export needs it | `RecordingVault` |
| Key wrapping | P-256 key in the Secure Enclave, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: usable only while unlocked, never backed up or migrated. Sealing needs only the public key, cached in memory; every open starts on an unlocked device. The key cannot be extracted, but code in the app's context can ask the Enclave to use it, and the access class is what limits that | `RecordingVault` |
| File protection | `.complete` once sealed; `.completeUnlessOpen` only while a file is being written or awaits the seal. See *File protection* | `AudioStorage` |
| Backup | `isExcludedFromBackup` on the recordings folder, each sealed file, the word list and the SwiftData store with `-wal` and `-shm`. Re-applied at launch and on every folder access, since file operations can reset it. Encryption carries the guarantee; the flag keeps unencrypted metadata out of backups | `AudioStorage`, `RecordingController`, `WordList` |
| Background | `UIBackgroundModes` is `audio`: a recording continues after the lock, and the control can start one with the app in the background. A stop on an unlocked device starts transcription until iOS suspends the app; after a stop on a locked device it waits | `Info.plist`, `IsolationTests` |
| Permissions | `NSMicrophoneUsageDescription` only. `NSSpeechRecognitionUsageDescription` is tested absent | `Info.plist`, `PrivacyTests` |
| Speech to text | nb-whisper, bundled, run by WhisperKit in the app's process. No other engine | `Transcription`, `WhisperTranscriber` |
| Logging | WhisperKit runs with `verbose: false` and `logLevel: .none`. The app logs recording events: start, stop and length, interruptions, deferred seals, failed imports by error code. Never content, a name or an imported file's name. File names are UUIDs | `AudioRecorder`, `WhisperTranscriber` |
| Privacy manifest | No tracking, no tracking domains, no collected data. Accessed APIs: file timestamps (C617.1) and `UserDefaults` (CA92.1). A test asserts that set | `PrivacyInfo.xcprivacy`, `IsolationTests` |
| Screen capture | What is hidden is read once, at the app's root, so every view follows one reading | `CaptureGuard`, `ConcealmentReader` |
| Keyboard | Autocorrection and predictive text are off in both text fields, so typed names stay out of the keyboard's learned dictionary, which lives outside the sandbox. The rename is the app's own field, since the system's ignores the setting | `SettingsView`, `RecordingDetailView` |
| Pasteboard | «Kopier» writes `localOnly` with a five-minute expiry, so Universal Clipboard does not carry it. No text selection, which would write to the general pasteboard; a test fails if it returns | `RecordingDetailView`, `IsolationTests` |
| Export | Decrypted into the temporary directory, handed to the share sheet, removed when it closes. «Eksporter alle opptak» zips every recording with the system's `NSFileCoordinator` (`.forUploading`), removes the plaintext once zipped, and stops and cleans up if Innstillinger closes first | `RecordingExport`, `ShareSheet` |
| Memory safety | Enhanced Security entitlements: hardware memory tagging without soft mode, guard objects on freed memory, read-only platform memory, restricted library loading and Mach messages. Tagging needs an A19 chip or later. A test reads the entitlements from the signed binary; on an iPhone 17 Pro an out-of-bounds read and a use-after-free both stop the app | `project.yml`, `Frodi.entitlements`, `IsolationTests` |

## File protection

| State | Class | Reason |
| --- | --- | --- |
| Recording in progress | `.completeUnlessOpen` | `.complete` would block writes at the lock, exactly when recordings run. Linear PCM in CAF, so a file cut off by a crash still opens |
| Stopped, awaiting seal | `.completeUnlessOpen`, closed | Unreadable until unlock. Sealed then if the app runs, otherwise when it next comes to the front |
| Sealed recording, word list | `.complete` | Everything that opens them runs on an unlocked device |
| Transcription progress | `.completeUnlessOpen` | Already ciphertext, and written after each piece, possibly after the lock |
| Plaintext for transcription, import or export | `.completeUnlessOpen` | Created on an unlocked device and used in the same session. Removed in a `defer` or when the share sheet closes; the folder is emptied at launch |
| Database | `.completeUntilFirstUserAuthentication` | iOS' default. Holds dates, durations, file names and sealed content; no plaintext content |

## Origin

Every recording gets an origin when it comes in: a sealed, write-once record of what it was. `Recording.recordOrigin` is the only writer and refuses a second write. A name is a separate field and leaves the origin alone.

| Recording | The origin holds |
| --- | --- |
| Made in the app | File stem, date, length, and the SHA-256 of the sealed audio: the bytes an export hands over as `.m4a` |
| Imported | The same, the time of the import, and the picked file's name, size, codec, sample rate, channels, creation date, common metadata and SHA-256. Never a location |

A changed byte fails AES-GCM. The file stem stops an origin moved onto another row. Date and length are compared with the row each time the recording page opens; the audio checksum when «Om opptaket» opens, since that reads the whole file. `OriginTests` covers each case.

| Claim | Holds? |
| --- | --- |
| A change made outside the app shows | Partly. A changed or moved origin, date, length or audio shows. The transcript and the name are sealed but not bound to their recording, so one moved from another row opens without warning. A removed origin looks like a recording without one. Each needs write access to the container |
| The date is when the recording was made | As far as the device clock is right; there is no trusted timestamp |
| An imported file is the one that came in | The original's SHA-256 identifies the file, not who made it or when |
| Exported audio is the audio that was locked | The RTF gives the audio's SHA-256; anyone holding both can check with `shasum -a 256` |

No origin is written after the fact, since it would vouch for a past it never saw. A recording has none if the app died between the seal and the row update, or an import between moving its file in and saving its row.

## No network

The app makes no network requests and sends no telemetry. `IsolationTests` fails on an ATS exception, an undeclared background mode, declared collected data, or `URLSession`, `URLRequest`, `NWConnection` or `import Network` in the sources.

The model loads with `download: false` and explicit local paths. That flag does not cover the tokenizer, which WhisperKit fetches from Hugging Face when it cannot read it locally; the app therefore checks both tokenizer files before creating WhisperKit, and a build phase fails a build without the model.

The speaker model (SpeakerKit, speaker diarization) has one configuration, `Speakers.config`: the bundled folder and `download: false`. With a local folder SpeakerKit never calls its downloader. `BundledModelTests` runs that configuration with Hugging Face replaced by a closed port, so a configuration that would fetch fails the test; `IsolationTests` fails if SpeakerKit is created anywhere else.

Two requests happen because the user asked for them: iOS downloads a picked file that lives only in iCloud Drive, and Safari opens the three document links in Innstillinger.

> [!NOTE]
> WhisperKit carries a copy of `swift-transformers`' `Hub` module, which
> links the Network framework. Each model load creates Hub clients whose
> constructors start `NWPathMonitor`s: they ask iOS whether the device is
> online and send nothing. The claim is «this app makes no network requests»,
> not «this binary contains no networking code», which would be false.

## Privacy

The four MASVS-PRIVACY controls were tested on 2026-09-28 with the MASTG's static iOS privacy tests against build 1.0 (9) and read against the code. The table describes the code. Build 1.0 (9) keeps the location an imported file states in its origin, and its purpose string says «det du sier», not that conversations with others are recorded; both are fixed from build 1.1.0 (10) (CHANGELOG.md).

| Control | How the app meets it | Checked by |
| --- | --- | --- |
| PRIVACY-1 Minimal access | One protected resource, the microphone, asked for at the first recording; iOS also asks once whether the Live Activity may run. The file picker gives only the picked file. WhisperKit gets the audio and the word list, in the app's process; in Avansert SpeakerKit gets the audio too | MASTG-TEST-0360, -0362: one purpose string, and no protected-resource API the app calls besides the microphone. WhisperKit's own microphone request sits in its live-streaming class, which the app does not use |
| PRIVACY-2 No identification | No account, user ID, device or advertising identifier, or analytics. Recordings are named by UUID, exports by date. An import is converted to PCM, so none of its metadata reaches an exported `.m4a`. The `.rtf` carries the user's name for the recording and an import's original file name | The binary references no `identifierForVendor`, `advertisingIdentifier`, App Attest or DeviceCheck. An import with a title and a location exported with neither |
| PRIVACY-3 Transparency | [PERSONVERN.md](PERSONVERN.md), linked in the app and the App Store listing. The privacy manifests declare no collected data | MASTG-TEST-0281: the binary names github.com, huggingface.co and tazk.no, none on DuckDuckGo's tracker list |
| PRIVACY-4 User control | See, rename, export and delete each recording; edit the word list; withdraw microphone access; delete the app. Nothing is collected, so there is no consent to withdraw | PERSONVERN.md *Rettighetene dine*, read against the app |

Not tested: MASTG-TEST-0361 and -0363, which hook the running app on a device. The App Store privacy label cannot be read through the App Store Connect API.

## Build integrity

What a fresh clone builds is what was reviewed. WhisperKit and SpeakerKit, two products of `argmax-oss-swift`, are pinned to one version and bring one package, `swift-argument-parser`, plus its own copy of `swift-transformers`' Hub and Tokenizers sources. `Package.resolved` is committed; versions and licences are in [TREDJEPART.md](TREDJEPART.md), which a test keeps in step.

The model is a third-party CoreML conversion of nb-whisper-small, fetched at a fixed revision and checked against `Scripts/model-checksums.txt`. The speaker model, Argmax's CoreML conversion of pyannote community-1, is fetched and checked the same way. The checksums prove the files are the ones measured on 2026-09-07 (nb-whisper, tokenizer) and 2026-10-03 (speaker model), not that they are benign. Since the model never touches the network, what could be wrong with it is transcription quality and bias, not exfiltration.

## Deliberate omissions

| Omission | Reason |
| --- | --- |
| No app-level lock | The device lock already applies. A second lock would be one more obstacle in the car |
| No auto-lock while transcribing | The screen stays awake during a run, three to five minutes for an hour of speech on an iPhone 17 Pro. A lock suspends the run; it resumes when the app is next in front |
| No certificate pinning | No transport |
| No jailbreak detection (MAS-R) | A compromised OS can lie to the check, and the threat model excludes it. The source is public for audit instead |
| No forced update | It would need a network request. An organisation that needs a minimum version enforces it through MDM |
| No advisory feed | Dependencies are pinned, and advisories for `argmax-oss-swift` and `swift-argument-parser` are checked by hand before a release |
| No overwrite on delete | The file is ciphertext with its key wrapped inside it, and iOS deletes by discarding the per-file key |
| No trusted timestamp | A timestamp authority needs a network request. The origin's date is the device clock's |
| No reproducible build | The App Store encrypts and re-signs what it serves, so a build from source cannot be compared with it. Public source, pinned dependencies and model checksums stand in its place |
| Imported originals not kept | The converted copy and the original's SHA-256 are kept; anyone holding the original can match it |
| No screenshot blocking | iOS reports a screenshot only after it exists, and the `isSecureTextEntry` trick is undocumented. The app does not offer what it cannot deliver |
| No pointer authentication | Enhanced Security's arm64e build setting cannot import WhisperKit, which builds as arm64 only. The same blocks CPA2. Memory tagging does not depend on arm64e and is on |
| No Enhanced Security in the widget | It draws the control and the Live Activity from state the app wrote, in its own process, with no access to the app's container or keys |
