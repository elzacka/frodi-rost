import CryptoKit
import Foundation
import LocalAuthentication
import Security
import os

/// Encrypts recordings with a key that never leaves this device.
/// On top of iOS file protection, as `isExcludedFromBackup` is only guidance: a leaked copy is unreadable without the Enclave key.
/// A P-256 Secure Enclave key wraps a random AES-256 key per recording (AES-GCM seal). Other devices cannot read recordings: see `RecordingExport`.
enum RecordingVault {
    // The prefix is `no.` while the bundle ID is `com.Tazk.Frodi`: not a mistake. The tag is the key's address in the Secure Enclave;
    // change it and the app cannot find the key, and every sealed recording becomes unreadable.
    private static let keyTag = "no.Tazk.Frodi.vault.v1".data(using: .utf8)!

    /// The public half of the Enclave key (X9.63 bytes), once read.
    /// Sealing needs only this; the private key is `WhenUnlocked`, refused on a locked device, yet a transcription can outlast the screen.
    /// That works because every path that seals has opened something first in this process, which is when this is kept.
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
                String(localized: "Fróði får ikke tak i nøkkelen. Lås opp enheten og prøv på nytt.")
            case .decryptionFailed:
                String(localized: "Fróði får ikke låst opp opptaket. Det ble kryptert på en annen enhet.")
            }
        }
    }

    /// False only when the device has no passcode: then file protection and the Enclave key guard nothing on a locked device.
    static var deviceHasPasscode: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            || error?.code != LAError.passcodeNotSet.rawValue
    }

    // MARK: - Encryption
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

    /// Fetches the key, or creates it the first time. Only a missing key is created; any other keychain refusal (e.g. locked) is an
    /// error: a second key under the same tag would make everything sealed under the first unreadable for good.
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
        // whenUnlockedThisDeviceOnly: the private key only opens, and every opening path runs unlocked (`.complete` audio;
        // `Transcription.run` waits for unlock). Sealing uses the public key. Looser afterFirstUnlock would let a seized, locked,
        // once-unlocked device use the key. Class fixed at creation, no rotation. ThisDeviceOnly keeps it out of backups.
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
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
