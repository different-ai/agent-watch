import CryptoKit
import Foundation

public enum ScreenTextHasher {
    public static func sha256(_ value: String) -> String {
        sha256(data: Data(value.utf8))
    }

    public static func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
