//
//  BackupCrypto.swift
//  Phbank
//
//  Password protection for backup files: PBKDF2-SHA256 (600,000 rounds)
//  turns the password into a 256-bit key, AES-GCM encrypts and
//  authenticates the backup. A wrong password or a changed byte is detected.
//
//  File layout: "PHINANZ-ENC1" | salt (16) | rounds (UInt32, big endian) | nonce + ciphertext + tag
//

import Foundation
import CryptoKit
import CommonCrypto
import Security

nonisolated enum BackupCrypto {
    static let magic = Data("PHINANZ-ENC1".utf8)
    static let defaultRounds: UInt32 = 600_000
    static let minimumPasswordLength = 8
    private static let saltLength = 16
    private static let headerLength = magic.count + saltLength + 4

    enum CryptoError: LocalizedError, Equatable {
        case weakPassword
        case wrongPassword
        case damaged

        var errorDescription: String? {
            switch self {
            case .weakPassword: String(localized: "Use a password with at least 8 characters.")
            case .wrongPassword: String(localized: "The password is wrong, or the file was changed.")
            case .damaged: String(localized: "This backup file is damaged.")
            }
        }
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.count > magic.count && data.prefix(magic.count) == magic
    }

    static func encrypt(_ plaintext: Data, password: String, rounds: UInt32 = defaultRounds) throws -> Data {
        guard password.count >= minimumPasswordLength else { throw CryptoError.weakPassword }
        var salt = Data(count: saltLength)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!) }
        guard status == errSecSuccess else { throw CryptoError.damaged }

        var header = magic + salt
        withUnsafeBytes(of: rounds.bigEndian) { header.append(contentsOf: $0) }

        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        // The header is authenticated too, so nobody can lower the rounds unnoticed.
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: header)
        guard let combined = box.combined else { throw CryptoError.damaged }
        return header + combined
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        // header + 12-byte nonce + 16-byte tag at least
        guard isEncrypted(data), data.count >= headerLength + 12 + 16 else { throw CryptoError.damaged }
        let bytes = Data(data) // re-base indices at 0
        let header = bytes.prefix(headerLength)
        let salt = bytes.subdata(in: magic.count ..< magic.count + saltLength)
        let rounds = bytes.subdata(in: magic.count + saltLength ..< headerLength)
            .reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        // Refuse absurd values instead of hanging the app.
        guard (1_000...10_000_000).contains(rounds) else { throw CryptoError.damaged }

        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        do {
            let box = try AES.GCM.SealedBox(combined: bytes.suffix(from: headerLength))
            return try AES.GCM.open(box, using: key, authenticating: header)
        } catch {
            throw CryptoError.wrongPassword
        }
    }

    static func deriveKey(password: String, salt: Data, rounds: UInt32) throws -> SymmetricKey {
        // Same password typed on another keyboard must give the same key.
        let passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        guard !passwordBytes.isEmpty, !salt.isEmpty else { throw CryptoError.wrongPassword }
        var derived = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordBuffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: passwordBytes.count) { passwordPointer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer, passwordBytes.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        &derived, derived.count
                    )
                }
            }
        }
        guard status == Int32(kCCSuccess) else { throw CryptoError.damaged }
        return SymmetricKey(data: derived)
    }
}
