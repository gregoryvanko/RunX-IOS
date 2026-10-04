import SwiftUI

// Ligne « libellé : valeur » d'une carte (tables responsives de la version web)
struct InfoRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.rxGrey)
                .frame(width: 78, alignment: .leading)
            value
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

struct RowCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { content }
            .font(.system(size: 14.5))
            .foregroundStyle(Color.rxInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: RX.radius))
            .overlay(RoundedRectangle(cornerRadius: RX.radius).stroke(Color.rxLine, lineWidth: 1))
    }
}

// ---------- Utilisateurs ----------
struct AdminUsersView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @State private var search = ""
    @State private var query = ""
    @State private var page = 1
    @State private var users: [User] = []
    @State private var total = 0
    @State private var reload = 0
    @State private var toDelete: User?
    private let limit = 20

    var body: some View {
        Screen(onRefresh: load) {
            PageHeader(title: "Utilisateurs", subtitle: "Gestion des comptes. La suppression efface l'utilisateur et toutes ses données.")
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 10) {
                    LabeledField(label: "Recherche") {
                        RXTextField(placeholder: "Identifiant ou nom", text: $search, keyboard: .username)
                            .onSubmit(filter)
                            .submitLabel(.search)
                    }
                    .frame(maxWidth: wide ? 360 : .infinity)
                    Button("Filtrer", action: filter).buttonStyle(.rxPrimary)
                    if wide { Spacer() }
                }
                .padding(.bottom, 6)

                if users.isEmpty {
                    Text("Aucun utilisateur").foregroundStyle(Color.rxGrey)
                }
                if wide && !users.isEmpty {
                    usersTable
                } else {
                    ForEach(users) { u in userCard(u) }
                }
                Pager(page: $page, total: total, limit: limit)
            }
            .card(padding: 10)
        }
        .task(id: "\(query)-\(page)-\(reload)") { await load() }
        .alert("Supprimer l'utilisateur", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
               presenting: toDelete) { u in
            Button("Supprimer", role: .destructive) { Task { await delete(u) } }
            Button("Annuler", role: .cancel) {}
        } message: { u in
            Text("Supprimer définitivement « \(u.username) » et toutes ses données ? Cette action est irréversible.")
        }
    }

    private func filter() {
        query = search
        page = 1
        reload += 1
    }

    // Le serveur indique les comptes protégés : le sien ("self") et l'admin principal ("main-admin")
    private func roleCell(_ u: User) -> some View {
        RXPicker(selection: Binding(get: { u.role }, set: { setRole(u, $0) }),
                 options: [("user", "Utilisateur"), ("admin", "Administrateur")],
                 height: 38, disabled: u.protected != nil)
    }

    @ViewBuilder private func actionCell(_ u: User) -> some View {
        if u.protected != nil {
            Badge(text: u.protected == "self" ? "Votre compte" : "Protégé")
        } else {
            Button("Supprimer") { toDelete = u }.buttonStyle(.rx(.danger, small: true))
        }
    }

    private func userCard(_ u: User) -> some View {
        RowCard {
            InfoRow(label: "Identifiant") { Text(u.username).bold() }
            InfoRow(label: "Nom") { Text(u.displayName) }
            InfoRow(label: "Rôle") { roleCell(u) }
            InfoRow(label: "Inscription") { Text(Fmt.dateTime(u.createdAt)) }
            InfoRow(label: "Connexion") { Text(Fmt.dateTime(u.lastLoginAt)) }
            HStack {
                Spacer()
                actionCell(u)
            }
            .padding(.top, 4)
        }
    }

    // Écran large : tableau comme sur la version web
    private var usersTable: some View {
        ProportionalTable(headers: ["Identifiant", "Nom", "Rôle", "Inscription", "Dernière connexion", ""],
                          fractions: [0.15, 0.17, 0.22, 0.17, 0.17, 0.12],
                          items: users) { u, w in
            Text(u.username).bold().cell(w[0])
            Text(u.displayName).cell(w[1])
            roleCell(u).padding(.horizontal, 10).padding(.vertical, 6).frame(width: w[2])
            Text(Fmt.dateTime(u.createdAt)).cell(w[3])
            Text(Fmt.dateTime(u.lastLoginAt)).cell(w[4])
            actionCell(u).padding(.horizontal, 10).padding(.vertical, 8).frame(width: w[5], alignment: .trailing)
        }
        .font(.system(size: 14.5))
        .foregroundStyle(Color.rxInk)
    }

    private func load() async {
        guard let api = session.api else { return }
        do {
            let data = try await api.listUsers(q: query, page: page, limit: limit)
            users = data.items
            total = data.total
        } catch { session.show(error) }
    }

    private func setRole(_ u: User, _ role: String) {
        guard role != u.role, let api = session.api else { return }
        if let i = users.firstIndex(where: { $0.id == u.id }) { users[i].role = role }
        Task {
            do {
                _ = try await api.setRole(userId: u.id, role: role)
                session.show("Rôle de \(u.username) mis à jour")
            } catch {
                session.show(error)
                await load()
            }
        }
    }

    private func delete(_ u: User) async {
        do {
            try await session.api?.deleteUser(id: u.id)
            session.show("\(u.username) supprimé")
            await load()
        } catch { session.show(error) }
    }
}

// ---------- Logs ----------
struct AdminLogsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @State private var type = ""
    @State private var level = ""
    @State private var username = ""
    @State private var text = ""
    @State private var applied = (type: "", level: "", username: "", q: "")
    @State private var page = 1
    @State private var reload = 0
    @State private var logs: [LogEntry] = []
    @State private var total = 0
    private let limit = 50

    private static let typeLabel = ["request": "Requête", "activity": "Activité", "error": "Erreur"]
    private static let levelLabel = ["info": "Info", "warn": "Warn", "error": "Erreur"]

    var body: some View {
        Screen(onRefresh: load) {
            PageHeader(title: "Logs de l'application")
            VStack(alignment: .leading, spacing: 8) {
                filters.padding(.bottom, 6)
                if logs.isEmpty {
                    Text("Aucune entrée").foregroundStyle(Color.rxGrey)
                }
                if wide && !logs.isEmpty {
                    logsTable
                } else {
                    ForEach(logs) { l in logCard(l) }
                }
                Pager(page: $page, total: total, limit: limit)
            }
            .card(padding: 10)
        }
        .task(id: "\(page)-\(reload)") { await load() }
    }

    private var typeField: some View {
        LabeledField(label: "Type") {
            RXPicker(selection: $type, options: [("", "Tous"), ("request", "Requêtes"), ("activity", "Activités"), ("error", "Erreurs")])
        }
    }
    private var levelField: some View {
        LabeledField(label: "Niveau") {
            RXPicker(selection: $level, options: [("", "Tous"), ("info", "Info"), ("warn", "Warn"), ("error", "Erreur")])
        }
    }
    private var userField: some View {
        LabeledField(label: "Utilisateur") {
            RXTextField(placeholder: "identifiant", text: $username, keyboard: .username)
        }
    }
    private var searchField: some View {
        LabeledField(label: "Recherche") {
            RXTextField(placeholder: "URL, message…", text: $text, keyboard: .username)
                .onSubmit(filter)
        }
    }
    @ViewBuilder private var filterButtons: some View {
        Button("Filtrer", action: filter).buttonStyle(.rxPrimary)
        Button("Rafraîchir") { reload += 1 }.buttonStyle(.rxGhost)
    }

    // Écran large : une seule barre de filtres ; téléphone : deux champs par ligne
    @ViewBuilder private var filters: some View {
        if wide {
            HStack(alignment: .bottom, spacing: 10) {
                typeField; levelField; userField; searchField
                filterButtons
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) { typeField; levelField }
                HStack(spacing: 10) { userField; searchField }
                HStack(spacing: 10) { filterButtons }
            }
        }
    }

    private func filter() {
        applied = (type, level, username, text)
        page = 1
        reload += 1
    }

    private func typeBadge(_ l: LogEntry) -> Badge {
        let (fg, bg): (Color, Color) = switch l.type {
        case "request": (.white, .rxBlack)
        case "activity": (.white, .rxBlue)
        case "error": (.rxDanger, .rxDangerSoft)
        default: (.rxBlueDark, .rxBlueSoft)
        }
        return Badge(text: Self.typeLabel[l.type] ?? l.type, fg: fg, bg: bg)
    }

    private func levelBadge(_ l: LogEntry) -> Badge {
        let (fg, bg): (Color, Color) = switch l.level {
        case "error": (.white, .rxDanger)
        case "warn": (.rxWarn, .rxWarnSoft)
        default: (.rxBlueDark, .rxBlueSoft)
        }
        return Badge(text: Self.levelLabel[l.level ?? ""] ?? (l.level ?? "—"), fg: fg, bg: bg)
    }

    private func detail(_ l: LogEntry) -> String {
        if l.type == "request" {
            "\(l.method ?? "") \(l.url ?? "") → \(l.status == 444 ? "444 sans réponse" : String(l.status ?? 0)) (\(Int(l.durationMs ?? 0)) ms)"
        } else {
            "\(l.action.map { "[\($0)] " } ?? "")\(l.message ?? "")"
        }
    }

    private static let mono = Font.system(size: 13, design: .monospaced)

    // IP et client sur deux lignes : une IPv6 peut se couper sans élargir le tableau
    private func caller(_ l: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l.ip ?? "?")
            Text(l.client ?? "?").foregroundStyle(Color.rxGrey)
        }
        .font(Self.mono)
    }

    private func logCard(_ l: LogEntry) -> some View {
        RowCard {
            InfoRow(label: "Date") {
                Text("\(Fmt.compactDay(l.createdAt)) \(Text(Fmt.timeSeconds(l.createdAt)).foregroundStyle(Color.rxGrey))")
            }
            InfoRow(label: "Type") { typeBadge(l) }
            InfoRow(label: "Niveau") { levelBadge(l) }
            InfoRow(label: "Utilisateur") { Text(l.username ?? "—") }
            InfoRow(label: "Détail") { Text(detail(l)).font(Self.mono).textSelection(.enabled) }
            InfoRow(label: "Appelant") { caller(l) }
        }
    }

    // Écran large : tableau ; la colonne Détail prend la plus grande part
    private var logsTable: some View {
        ProportionalTable(headers: ["Date", "Type", "Niveau", "Utilisateur", "Détail", "Appelant"],
                          fractions: [0.10, 0.11, 0.09, 0.12, 0.40, 0.18],
                          items: logs) { l, w in
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.compactDay(l.createdAt))
                Text(Fmt.timeSeconds(l.createdAt)).foregroundStyle(Color.rxGrey)
            }
            .font(.system(size: 13))
            .cell(w[0])
            typeBadge(l).lineLimit(1).minimumScaleFactor(0.7).cell(w[1])
            levelBadge(l).lineLimit(1).minimumScaleFactor(0.7).cell(w[2])
            Text(l.username ?? "—").cell(w[3])
            Text(detail(l)).font(Self.mono).textSelection(.enabled).cell(w[4])
            caller(l).cell(w[5])
        }
        .font(.system(size: 14.5))
        .foregroundStyle(Color.rxInk)
    }

    private func load() async {
        guard let api = session.api else { return }
        do {
            let data = try await api.listLogs(type: applied.type, level: applied.level, username: applied.username,
                                              q: applied.q, page: page, limit: limit)
            logs = data.items
            total = data.total
        } catch { session.show(error) }
    }
}
