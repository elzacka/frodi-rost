import CryptoKit
import Foundation
import Security
import os

/// Encrypts recordings with a key that never leaves this device.
///
/// Why this on top of iOS' own file protection: Apple describes
/// `isExcludedFromBackup` as guidance to the system, not a guarantee. If a copy
/// gets out anyway, it is unreadable without the key, and the key exists only
/// inside the Secure Enclave on this device.
///
/// Structure:
/// - A P-256 key is created in the Secure Enclave and never leaves it.
/// - Every recording gets its own random AES-256 key.
/// - The audio is sealed with AES-GCM, and the AES key is wrapped by the Enclave key.
///
/// The price is that recordings cannot be read by another device. That is what
/// export is for: see `RecordingExport`.
enum RecordingVault {
    // The prefix is `no.` while the bundle ID is `com.Tazk.Frodi`. That is not a
    // mistake to fix: the tag is the address of the key in the Secure Enclave, not
    // an identifier iOS cares about. Change it and the app cannot find the key
    // again, and every recording already sealed on the device becomes unreadable.
    // It is private and shown nowhere.
    private static let keyTag = "no.Tazk.Frodi.vault.v1".data(using: .utf8)!

    /// The public half of the Enclave key, as X9.63 bytes, once it has been read.
    ///
    /// Sealing needs only the public key, and the public key is not secret. The
    /// private key, by contrast, lives in the keychain under an access class that
    /// can refuse it: `AfterFirstUnlock` before the first unlock since boot, and
    /// `WhenUnlocked` on a device whose key was made by build 5 or 6. A
    /// transcription can outlast the screen, and its text is sealed the moment it
    /// finishes, so the seal must not depend on the lock state. It does not: every
    /// path that seals has opened something first in the same process, and that is
    /// when the public key is kept.
    private static let publicKeyBytes = OSAllocatedUnfairLock<Data?>(initialState: nil)

    enum VaultError: LocalizedError {
        case enclaveUnavailable
        case keyCreationFailed(String)
        case keyUnavailable(OSStatus)
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .enclaveUnavailable:
                String(localized: "Denne enheten har ingen Secure Enclave.")
            case .keyCreationFailed(let message):
                message
            case .keyUnavailable:
                String(localized: "Fróði får ikke tak i nøkkelen. Lås opp enheten og prøv igjen.")
            case .decryptionFailed:
                String(localized: "Fróði får ikke låst opp opptaket. Det ble kryptert på en annen enhet.")
            }
        }
    }

    // MARK: - Encryption
    static func seal(fileAt url: URL) throws -> Data {
        try seal(try Data(contentsOf: url))
    }

    /// Seals text. Used for transcripts, which are often more exposing than the
    /// audio file: the text is searchable and readable at a glance.
    static func seal(_ text: String) throws -> Data {
        try seal(Data(text.utf8))
    }

    static func openText(_ blob: Data) throws -> String {
        guard let text = String(data: try open(blob), encoding: .utf8) else {
            throw VaultError.decryptionFailed
        }
        return text
    }

    static func seal(_ plaintext: Data) throws -> Data {
        let dataKey = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(plaintext, using: dataKey)

        guard let combined = sealed.combined else { throw VaultError.decryptionFailed }
        let wrappedKey = try wrap(dataKey)

        // Format: 2 bytes of wrapped-key length, the key, then the ciphertext.
        var out = Data()
        var length = UInt16(wrappedKey.count).bigEndian
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(wrappedKey)
        out.append(combined)
        return out
    }

    static func open(_ blob: Data) throws -> Data {
        guard blob.count > 2 else { throw VaultError.decryptionFailed }
        let length = Int(blob.prefix(2).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).bigEndian })
        guard blob.count > 2 + length else { throw VaultError.decryptionFailed }

        let wrappedKey = blob.subdata(in: 2..<(2 + length))
        let cipher = blob.subdata(in: (2 + length)..<blob.count)

        let dataKey = try unwrap(wrappedKey)
        let box = try AES.GCM.SealedBox(combined: cipher)
        return try AES.GCM.open(box, using: dataKey)
    }

    // MARK: - Key in the Secure Enclave
    private static func wrap(_ key: SymmetricKey) throws -> Data {
        let publicKey = try self.publicKey()
        let raw = key.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(
            publicKey, .eciesEncryptionCofactorX963SHA256AESGCM, raw as CFData, &error
        ) else {
            throw VaultError.keyCreationFailed(describe(error))
        }
        return wrapped as Data
    }

    private static func unwrap(_ wrapped: Data) throws -> SymmetricKey {
        let privateKey = try enclaveKey()
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCreateDecryptedData(
            privateKey, .eciesEncryptionCofactorX963SHA256AESGCM, wrapped as CFData, &error
        ) else {
            throw VaultError.decryptionFailed
        }
        return SymmetricKey(data: raw as Data)
    }

    /// The public key: from memory if it has been seen in this process, otherwise
    /// derived from the private key, which needs the device to be unlocked.
    private static func publicKey() throws -> SecKey {
        if let bytes = publicKeyBytes.withLock({ $0 }) {
            var error: Unmanaged<CFError>?
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic
            ]
            guard let key = SecKeyCreateWithData(bytes as CFData, attributes as CFDictionary, &error) else {
                throw VaultError.keyCreationFailed(describe(error))
            }
            return key
        }

        guard let key = SecKeyCopyPublicKey(try enclaveKey()) else {
            throw VaultError.keyCreationFailed("Fant ingen offentlig nøkkel.")
        }
        var error: Unmanaged<CFError>?
        guard let bytes = SecKeyCopyExternalRepresentation(key, &error) else {
            throw VaultError.keyCreationFailed(describe(error))
        }
        let data = bytes as Data
        publicKeyBytes.withLock { $0 = data }
        return key
    }

    /// Fetches the key, or creates it the first time.
    ///
    /// Only a key that does not exist is created. Any other refusal from the
    /// keychain, such as the device being locked, is an error: creating a second
    /// key under the same tag would leave everything sealed under the first one
    /// unreadable for good.
    private static func enclaveKey() throws -> SecKey {
        if let existing = try loadKey() { return existing }
        return try createKey()
    }

    private static func loadKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let result = item else { return nil }
            return (result as! SecKey)
        case errSecItemNotFound:
            return nil
        case let status:
            throw VaultError.keyUnavailable(status)
        }
    }

    private static func createKey() throws -> SecKey {
        // afterFirstUnlockThisDeviceOnly, so a transcription can open a recording
        // while the device sits locked on the charger; see BackgroundTranscription.
        // The stricter whenUnlocked was the class from 2026-09-13 to 2026-09-14,
        // and would have kept a seized, locked, once-unlocked device from
        // using the key. Decided by elzacka on 2026-09-14: an hour of
        // interview transcribed overnight is worth that margin. A key created by a
        // build in between keeps whenUnlocked, and on that device the transcription
        // runs only while unlocked; the class is fixed at creation and the app does
        // not rotate keys. ThisDeviceOnly keeps it out of backups.
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            .privateKeyUsage,
            &accessError
        ) else {
            throw VaultError.keyCreationFailed(describe(accessError))
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: access
            ]
        ]

        // The simulator has no Secure Enclave. The key is then created in the keychain
        // instead, so tests and development work. On a device it is in the Enclave.
        #if !targetEnvironment(simulator)
        attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        #endif

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw VaultError.keyCreationFailed(describe(error))
        }
        return key
    }

    private static func describe(_ error: Unmanaged<CFError>?) -> String {
        guard let error else { return "Ukjent feil." }
        return (error.takeRetainedValue() as Error).localizedDescription
    }
}
