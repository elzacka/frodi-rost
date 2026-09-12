import CryptoKit
import Foundation
import Security

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

    enum VaultError: LocalizedError {
        case enclaveUnavailable
        case keyCreationFailed(String)
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .enclaveUnavailable:
                String(localized: "Denne enheten har ingen Secure Enclave.")
            case .keyCreationFailed(let message):
                message
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
        let length = Int(blob.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        guard blob.count > 2 + length else { throw VaultError.decryptionFailed }

        let wrappedKey = blob.subdata(in: 2..<(2 + length))
        let cipher = blob.subdata(in: (2 + length)..<blob.count)

        let dataKey = try unwrap(wrappedKey)
        let box = try AES.GCM.SealedBox(combined: cipher)
        return try AES.GCM.open(box, using: dataKey)
    }

    // MARK: - Key in the Secure Enclave
    private static func wrap(_ key: SymmetricKey) throws -> Data {
        let privateKey = try enclaveKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw VaultError.keyCreationFailed("Fant ingen offentlig nøkkel.")
        }
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

    /// Fetches the key, or creates it the first time.
    private static func enclaveKey() throws -> SecKey {
        if let existing = loadKey() { return existing }
        return try createKey()
    }

    private static func loadKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        guard let result = item else { return nil }
        return (result as! SecKey)
    }

    private static func createKey() throws -> SecKey {
        // afterFirstUnlockThisDeviceOnly, not whenUnlocked: the recording can be
        // stopped with the Action Button while the screen is locked, and the key has to
        // be available then. ThisDeviceOnly keeps it out of backups.
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
