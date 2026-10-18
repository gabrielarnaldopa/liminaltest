import Foundation
import CryptoKit
import Observation
import Security

struct Session: Codable, Equatable {
    let email: String
    let name: String
    let role: String
    let start: Date
    let expires: Date

    var isAdmin: Bool { role == "admin" }
}

/// Sign-in for the prototype.
///
/// The admin password is stored only as a SHA-256 hash. This is enough for a demo, not for production:
/// before launch, move sign-in to your server, hash passwords there with Argon2 or bcrypt, and keep
/// only a session token on the device.
@MainActor
@Observable
final class AuthService {
    static let adminEmail = "gabrielarnaldopa@gmail.com"
    static let adminName = "Gabriel"
    /// SHA-256 of the admin password. To change the password, put the hash of the new one here:
    /// in Terminal, run  echo -n "nueva-clave" | shasum -a 256
    static let adminPasswordHash = "9f41dc2ca1666a8a3c7efa27913d93659897dc842c61716ae03e540ac68e2c27"
    static let maxAttempts = 5
    static let lockDuration: TimeInterval = 30

    enum Field { case email, password }

    enum LoginError: Equatable {
        case emptyEmail
        case invalidEmail
        case emptyPassword
        case wrongCredentials(remaining: Int)
        case locked(seconds: Int)

        var message: String {
            switch self {
            case .emptyEmail:
                return "Escribe tu correo."
            case .invalidEmail:
                return "Ese correo no parece válido. Revisa que tenga @ y un dominio."
            case .emptyPassword:
                return "Escribe tu contraseña."
            case .wrongCredentials(let remaining):
                let attempts = remaining == 1 ? "queda 1 intento" : "quedan \(remaining) intentos"
                return "Correo o contraseña incorrectos. Te \(attempts) antes de una pausa de 30 segundos."
            case .locked(let seconds):
                return "Demasiados intentos fallidos. Espera \(seconds) segundos y vuelve a probar."
            }
        }

        var field: Field? {
            switch self {
            case .emptyEmail, .invalidEmail: return .email
            case .emptyPassword, .wrongCredentials: return .password
            case .locked: return nil
            }
        }
    }

    private(set) var session: Session?
    private(set) var lockedUntil: Date?
    private var failures: Int

    init() {
        let defaults = UserDefaults.standard
        failures = defaults.integer(forKey: "auth.failures")
        let lockTime = defaults.double(forKey: "auth.lockedUntil")
        lockedUntil = lockTime > 0 ? Date(timeIntervalSince1970: lockTime) : nil
        if let saved = Keychain.loadSession(), saved.expires > Date() {
            session = saved
        } else {
            session = nil
            Keychain.deleteSession()
        }
    }

    var isLocked: Bool {
        guard let lockedUntil else { return false }
        return lockedUntil > Date()
    }

    /// Returns nil when sign-in succeeds.
    func signIn(email rawEmail: String, password: String, remember: Bool) -> LoginError? {
        if let lockedUntil, lockedUntil > Date() {
            return .locked(seconds: max(1, Int(lockedUntil.timeIntervalSinceNow.rounded(.up))))
        }
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if email.isEmpty { return .emptyEmail }
        if !Self.looksLikeEmail(email) { return .invalidEmail }
        if password.isEmpty { return .emptyPassword }

        if email == Self.adminEmail && Self.sha256(password) == Self.adminPasswordHash {
            failures = 0
            lockedUntil = nil
            persistGuard()
            let now = Date()
            let newSession = Session(email: Self.adminEmail, name: Self.adminName, role: "admin", start: now,
                                     expires: now.addingTimeInterval(remember ? 30 * 86400 : 12 * 3600))
            session = newSession
            if remember {
                Keychain.save(newSession)
            } else {
                Keychain.deleteSession()
            }
            return nil
        }

        failures += 1
        if failures >= Self.maxAttempts {
            failures = 0
            lockedUntil = Date().addingTimeInterval(Self.lockDuration)
            persistGuard()
            return .locked(seconds: Int(Self.lockDuration))
        }
        persistGuard()
        return .wrongCredentials(remaining: Self.maxAttempts - failures)
    }

    func signOut() {
        session = nil
        Keychain.deleteSession()
    }

    /// Signs out when the session has expired. Call when the app comes back to the foreground.
    func refreshSession() {
        if let session, session.expires <= Date() {
            signOut()
        }
    }

    private func persistGuard() {
        let defaults = UserDefaults.standard
        defaults.set(failures, forKey: "auth.failures")
        defaults.set(lockedUntil?.timeIntervalSince1970 ?? 0, forKey: "auth.lockedUntil")
    }

    nonisolated static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func looksLikeEmail(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !text.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}

/// Keeps the session in the iOS Keychain when the person chooses "Recordarme".
enum Keychain {
    private static let service = "app.liminal.session"
    private static let account = "session"

    static func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        deleteSession()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadSession() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    static func deleteSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: This device in the account's device list

    private static let deviceAccount = "device"

    static func saveDevice(_ record: DeviceRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        deleteDevice()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadDevice() -> DeviceRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(DeviceRecord.self, from: data)
    }

    static func deleteDevice() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
