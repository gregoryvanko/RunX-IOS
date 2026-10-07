import Foundation

struct APIError: LocalizedError {
    var status: Int
    var message: String
    var errorDescription: String? { message }
}

// Client de l'API RunX v1 (même API que l'application web)
final class APIClient {
    let baseURL: URL
    var token: String?
    // Appelé sur un 401 hors /auth/ : renvoie un nouveau jeton (reconnexion silencieuse) ou nil
    var reauthenticate: (() async -> String?)?
    // Appelé quand la session ne peut pas être rétablie
    var onUnauthorized: (() -> Void)?

    init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }

    // « localhost:3000 », « runx.vanko.be », « https://runx.vanko.be/ » → URL de base du serveur.
    // Sans schéma : http pour un serveur local (localhost, IP, .local), https sinon.
    static func normalizeServer(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") {
            let host = text.split(separator: "/").first.map(String.init) ?? text
            let hostname = (host.split(separator: ":").first.map(String.init) ?? host).lowercased()
            let isLocal = hostname == "localhost" || hostname.hasSuffix(".local") || !hostname.contains(".")
                || hostname.allSatisfy { $0.isNumber || $0 == "." }
            text = (isLocal ? "http://" : "https://") + text
        }
        while text.hasSuffix("/") { text.removeLast() }
        if text.hasSuffix("/api/v1") { text.removeLast("/api/v1".count) }
        guard let url = URL(string: text), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
            if let date = try? Date.ISO8601FormatStyle().parse(text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Date invalide : \(text)"))
        }
        return d
    }()

    private struct ErrorBody: Decodable { var error: String? }
    private struct Empty: Decodable {}

    private func send(_ method: String, _ path: String, query: [String: String] = [:], body: Encodable?, retry: Bool = true) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1" + path), resolvingAgainstBaseURL: false)!
        let items = query.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        if !items.isEmpty { components.queryItems = items }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError(status: 0, message: "Serveur injoignable")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401 && !path.hasPrefix("/auth/") {
                if retry, let reauthenticate, let newToken = await reauthenticate() {
                    token = newToken
                    return try await send(method, path, query: query, body: body, retry: false)
                }
                onUnauthorized?()
            }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "Erreur \(status)"
            throw APIError(status: status, message: message)
        }
        return data
    }

    private func request<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], body: Encodable? = nil) async throws -> T {
        let data = try await send(method, path, query: query, body: body)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError(status: 0, message: "Réponse inattendue du serveur")
        }
    }

    private func requestVoid(_ method: String, _ path: String, body: Encodable? = nil) async throws {
        _ = try await send(method, path, body: body)
    }

    // ---------- Authentification ----------
    func login(username: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { var username, password: String; var remember = true }
        return try await request("POST", "/auth/login", body: Body(username: username, password: password))
    }

    func register(username: String, displayName: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { var username, displayName, password: String }
        return try await request("POST", "/auth/register", body: Body(username: username, displayName: displayName, password: password))
    }

    func logout() async throws { try await requestVoid("POST", "/auth/logout") }

    // ---------- Profil ----------
    func me() async throws -> User { (try await request("GET", "/me") as UserResponse).user }

    func updateMe(displayName: String) async throws -> User {
        struct Body: Encodable { var displayName: String }
        return (try await request("PATCH", "/me", body: Body(displayName: displayName)) as UserResponse).user
    }

    func changePassword(current: String, new: String) async throws -> AuthResponse {
        struct Body: Encodable { var currentPassword, newPassword: String }
        return try await request("PUT", "/me/password", body: Body(currentPassword: current, newPassword: new))
    }

    // Suppression définitive de son propre compte et de toutes ses données
    func deleteAccount(password: String) async throws {
        struct Body: Encodable { var password: String }
        try await requestVoid("DELETE", "/me", body: Body(password: password))
    }

    func setTarget(_ target: RunInput) async throws -> User {
        (try await request("PUT", "/me/target", body: target) as UserResponse).user
    }

    func deleteTarget() async throws -> User { (try await request("DELETE", "/me/target") as UserResponse).user }

    // ---------- Courses ----------
    func listRuns(order: String? = nil, page: Int = 1, limit: Int = 20) async throws -> Page<Run> {
        try await request("GET", "/runs", query: ["order": order ?? "", "page": String(page), "limit": String(limit)])
    }

    func createRun(_ run: RunInput) async throws -> Run { (try await request("POST", "/runs", body: run) as RunResponse).run }

    func updateRun(id: String, _ run: RunInput) async throws -> Run {
        (try await request("PUT", "/runs/\(id)", body: run) as RunResponse).run
    }

    func deleteRun(id: String) async throws { try await requestVoid("DELETE", "/runs/\(id)") }

    func previewRun(_ run: RunInput) async throws -> Performance {
        (try await request("POST", "/runs/preview", body: run) as PerformanceResponse).performance
    }

    // ---------- Administration ----------
    func listUsers(q: String, page: Int, limit: Int = 20) async throws -> Page<User> {
        try await request("GET", "/admin/users", query: ["q": q, "page": String(page), "limit": String(limit)])
    }

    func setRole(userId: String, role: String) async throws -> User {
        struct Body: Encodable { var role: String }
        return (try await request("PATCH", "/admin/users/\(userId)/role", body: Body(role: role)) as UserResponse).user
    }

    func deleteUser(id: String) async throws { try await requestVoid("DELETE", "/admin/users/\(id)") }

    func listLogs(type: String, level: String, username: String, q: String, page: Int, limit: Int = 50) async throws -> Page<LogEntry> {
        try await request("GET", "/admin/logs", query: [
            "type": type, "level": level, "username": username, "q": q, "page": String(page), "limit": String(limit),
        ])
    }
}
