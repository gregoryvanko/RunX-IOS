import Foundation

// Objets renvoyés par l'API v1 (voir README du serveur RunX)

nonisolated struct Target: Codable, Equatable {
    var distanceKm: Double
    var durationSec: Double
    var avgHeartRate: Double
    var temperatureC: Double
    var elevationGainM: Double
    var avgPaceSecPerKm: Double?
    var performanceIndex: Double
}

nonisolated struct User: Codable, Equatable, Identifiable {
    var id: String
    var username: String
    var displayName: String
    var role: String
    // Administrateur principal (ADMIN_LOGIN) : son compte ne peut pas être supprimé
    var isMainAdmin: Bool?
    var lastLoginAt: Date?
    var target: Target?
    var createdAt: Date?
    var updatedAt: Date?
    // Uniquement dans les réponses admin : "self", "main-admin" ou null
    var `protected`: String?

    var isAdmin: Bool { role == "admin" }
}

nonisolated struct Run: Codable, Equatable, Identifiable {
    var id: String
    var date: Date
    var distanceKm: Double
    var durationSec: Double
    var avgHeartRate: Double
    var temperatureC: Double
    var elevationGainM: Double
    var notes: String?
    var avgPaceSecPerKm: Double
    var avgSpeedKmh: Double?
    var effortKm: Double?
    var gradeAdjustedPaceSecPerKm: Double?
    var temperatureFactor: Double?
    var performanceIndex: Double
    var formulaVersion: Int?
    var createdAt: Date?
    var updatedAt: Date?
}

nonisolated struct Performance: Codable {
    var avgPaceSecPerKm: Double
    var performanceIndex: Double
}

nonisolated struct LogEntry: Codable, Identifiable {
    var _id: String
    var type: String
    var level: String?
    var message: String?
    var action: String?
    var method: String?
    var url: String?
    var status: Int?
    var durationMs: Double?
    var ip: String?
    var client: String?
    var username: String?
    var createdAt: Date

    var id: String { _id }
}

nonisolated struct Page<Item: Codable>: Codable {
    var items: [Item]
    var total: Int
    var page: Int
    var limit: Int
}

// Données saisies pour une course (ou un objectif : sans date ni notes)
nonisolated struct RunInput: Encodable {
    var date: String?
    // Valeur absente (champ vide) : clé omise, le serveur renvoie « … est obligatoire »
    var distanceKm: Double?
    var durationSec: Double
    var avgHeartRate: Double?
    var temperatureC: Double?
    var elevationGainM: Double?
    var notes: String?
}

// Réponses
nonisolated struct AuthResponse: Decodable { var token: String; var user: User }
nonisolated struct UserResponse: Decodable { var user: User }
nonisolated struct RunResponse: Decodable { var run: Run }
nonisolated struct PerformanceResponse: Decodable { var performance: Performance }
