import Foundation
import Security

// Paramètres de connexion conservés sur l'appareil :
// serveur et identifiant dans UserDefaults, mot de passe et jeton dans le trousseau (Keychain).
enum CredentialStore {
    private static let serverKey = "runx.server"
    private static let usernameKey = "runx.username"
    private static let service = "be.vanko.runx"

    static var server: String? {
        get { UserDefaults.standard.string(forKey: serverKey) }
        set { UserDefaults.standard.set(newValue, forKey: serverKey) }
    }

    static var username: String? {
        get { UserDefaults.standard.string(forKey: usernameKey) }
        set { UserDefaults.standard.set(newValue, forKey: usernameKey) }
    }

    static var password: String? {
        get { read("password") }
        set { write("password", newValue) }
    }

    static var token: String? {
        get { read("token") }
        set { write("token", newValue) }
    }

    static func save(server: String, username: String, password: String, token: String) {
        self.server = server
        self.username = username
        self.password = password
        self.token = token
    }

    // Déconnexion : le serveur et l'identifiant restent pré-remplis, le secret est effacé
    static func clearSecrets() {
        password = nil
        token = nil
    }

    // ---------- Trousseau ----------
    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String?) {
        SecItemDelete(query(account) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var q = query(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
