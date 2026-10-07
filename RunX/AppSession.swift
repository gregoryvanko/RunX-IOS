import SwiftUI

enum Route: String, CaseIterable, Identifiable {
    case home, runs, explication, account, adminUsers, adminLogs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Performance"
        case .runs: "Mes courses"
        case .explication: "Explication"
        case .account: "Mon compte"
        case .adminUsers: "Utilisateurs"
        case .adminLogs: "Logs"
        }
    }

    var adminOnly: Bool { self == .adminUsers || self == .adminLogs }
}

// Fenêtre de saisie d'une course : nouvelle ou modification
enum RunEditor: Identifiable {
    case new
    case edit(Run)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let run): run.id
        }
    }
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let isError: Bool
}

@Observable
final class AppSession {
    enum Phase { case starting, loggedOut, loggedIn }

    var phase: Phase = .starting
    var user: User?
    var route: Route = .home
    var runEditor: RunEditor?
    var toast: Toast?
    // Incrémenté après l'ajout / la modification d'une course : les écrans concernés se rechargent
    var reloadToken = 0
    // Message affiché sur l'écran de connexion (ex. reconnexion automatique impossible)
    var loginError = ""
    private(set) var api: APIClient?

    var isAdmin: Bool { user?.isAdmin ?? false }
    var isMainAdmin: Bool { user?.isMainAdmin ?? false }
    var serverDisplay: String { api?.baseURL.absoluteString ?? CredentialStore.server ?? "" }

    // ---------- Démarrage : reconnexion avec les valeurs enregistrées ----------
    func start() async {
        guard let server = CredentialStore.server, let url = APIClient.normalizeServer(server),
              CredentialStore.username != nil, CredentialStore.token != nil || CredentialStore.password != nil else {
            phase = .loggedOut
            return
        }
        let api = makeClient(url, token: CredentialStore.token)
        do {
            if api.token == nil, let token = await reauthenticate(api) {
                api.token = token
            }
            guard api.token != nil else { throw APIError(status: 401, message: "Identifiant ou mot de passe incorrect") }
            // Jeton expiré ou révoqué : reconnexion silencieuse avec l'identifiant et le mot de passe enregistrés
            user = try await api.me()
            self.api = api
            route = .home
            phase = .loggedIn
        } catch {
            loginError = error.localizedDescription
            phase = .loggedOut
        }
    }

    // ---------- Connexion / inscription depuis l'écran de connexion ----------
    func connect(server: String, username: String, password: String, register: Bool, displayName: String) async throws {
        guard let url = APIClient.normalizeServer(server) else {
            throw APIError(status: 0, message: "Adresse du serveur invalide")
        }
        let api = makeClient(url, token: nil)
        let username = username.trimmingCharacters(in: .whitespaces).lowercased()
        let res = register
            ? try await api.register(username: username, displayName: displayName, password: password)
            : try await api.login(username: username, password: password)
        api.token = res.token
        CredentialStore.save(server: url.absoluteString, username: username, password: password, token: res.token)
        self.api = api
        user = res.user
        loginError = ""
        route = .home
        phase = .loggedIn
    }

    func logout() async {
        try? await api?.logout()
        endSession()
    }

    // Retour à l'écran de connexion (serveur et identifiant conservés)
    private func endSession(message: String = "") {
        CredentialStore.clearSecrets()
        api = nil
        user = nil
        runEditor = nil
        loginError = message
        phase = .loggedOut
    }

    private func makeClient(_ url: URL, token: String?) -> APIClient {
        let api = APIClient(baseURL: url, token: token)
        api.reauthenticate = { [weak self, weak api] in
            guard let self, let api else { return nil }
            return await self.reauthenticate(api)
        }
        api.onUnauthorized = { [weak self] in
            guard let self, self.phase == .loggedIn else { return }
            self.endSession()
            self.show("Session expirée, veuillez vous reconnecter", error: true)
        }
        return api
    }

    private func reauthenticate(_ api: APIClient) async -> String? {
        guard let username = CredentialStore.username, let password = CredentialStore.password,
              let res = try? await api.login(username: username, password: password) else { return nil }
        CredentialStore.token = res.token
        user = res.user
        return res.token
    }

    // ---------- Profil ----------
    func updateUser(_ user: User) { self.user = user }

    func passwordChanged(_ res: AuthResponse, newPassword: String) {
        api?.token = res.token
        CredentialStore.token = res.token
        CredentialStore.password = newPassword
        user = res.user
    }

    // Compte supprimé : plus rien à pré-remplir sur l'écran de connexion
    func accountDeleted() {
        CredentialStore.username = nil
        endSession()
        show("Compte supprimé")
    }

    // ---------- Navigation ----------
    func navigate(_ route: Route) {
        self.route = route.adminOnly && !isAdmin ? .home : route
    }

    func runSaved(_ run: Run, isNew: Bool) {
        show(isNew ? "Course ajoutée · indice \(Fmt.num(run.performanceIndex))" : "Course modifiée · indice \(Fmt.num(run.performanceIndex))")
        if isNew && route != .home && route != .runs { route = .home }
        reloadToken += 1
    }

    // ---------- Messages ----------
    func show(_ message: String, error: Bool = false) {
        let toast = Toast(message: message, isError: error)
        withAnimation(.easeOut(duration: 0.2)) { self.toast = toast }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            if self.toast?.id == toast.id {
                withAnimation(.easeIn(duration: 0.2)) { self.toast = nil }
            }
        }
    }

    func show(_ error: Error) {
        if error is CancellationError { return }
        if let e = error as? APIError, e.status == 401 { return }
        show(error.localizedDescription, error: true)
    }
}
