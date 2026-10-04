import SwiftUI

// Liste des courses : modification et suppression
struct RunsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @State private var runs: [Run] = []
    @State private var total = 0
    @State private var page = 1
    @State private var loaded = false
    @State private var toDelete: Run?
    private let limit = 20

    var body: some View {
        Screen(onRefresh: load) {
            HStack(alignment: .bottom, spacing: 12) {
                PageHeader(title: "Mes courses", subtitle: "Toutes vos courses enregistrées, de la plus récente à la plus ancienne.")
                // Sur téléphone, doublon du bouton flottant : masqué comme sur le web
                if wide {
                    Button("+ Nouvelle course") { session.runEditor = .new }
                        .buttonStyle(.rxPrimary)
                        .fixedSize()
                }
            }
            .padding(.bottom, 2)
            VStack(spacing: 8) {
                if !loaded {
                    ProgressView().padding(30)
                } else if runs.isEmpty {
                    Text("Aucune course enregistrée")
                        .foregroundStyle(Color.rxGrey)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if wide {
                    RunsTable(runs: runs,
                              onEdit: { session.runEditor = .edit($0) },
                              onDelete: { toDelete = $0 })
                } else {
                    ForEach(runs) { run in
                        RunRow(run: run,
                               onEdit: { session.runEditor = .edit(run) },
                               onDelete: { toDelete = run })
                    }
                }
                if total > limit {
                    Pager(page: $page, total: total, limit: limit)
                }
            }
            .card(padding: 10)
        }
        .task(id: "\(session.reloadToken)-\(page)") { await load() }
        .alert("Supprimer la course", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
               presenting: toDelete) { run in
            Button("Supprimer", role: .destructive) { Task { await delete(run) } }
            Button("Annuler", role: .cancel) {}
        } message: { run in
            Text("Supprimer la course du \(Fmt.day(run.date)) (\(Fmt.num(run.distanceKm, digits: 2)) km) ? Cette action est irréversible.")
        }
    }

    private func load() async {
        guard let api = session.api else { return }
        do {
            let data = try await api.listRuns(page: page, limit: limit)
            // Page vidée par une suppression : retour à la précédente
            if data.items.isEmpty && page > 1 { page -= 1; return }
            runs = data.items
            total = data.total
            loaded = true
        } catch {
            session.show(error)
        }
    }

    private func delete(_ run: Run) async {
        do {
            try await session.api?.deleteRun(id: run.id)
            session.show("Course supprimée")
            await load()
        } catch {
            session.show(error)
        }
    }
}

// Course en carte : informations sur deux colonnes, libellé et valeur sur la même ligne
struct RunRow: View {
    let run: Run
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    cell("Date") {
                        Text("\(Fmt.day(run.date)) \(Text(Fmt.time(run.date)).foregroundStyle(Color.rxGrey))")
                    }
                    cell("Distance") { Text("\(Fmt.num(run.distanceKm, digits: 2)) km") }
                }
                GridRow {
                    cell("Durée") { Text(Fmt.duration(run.durationSec)) }
                    cell("Allure") { Text(Fmt.pace(run.avgPaceSecPerKm)) }
                }
                GridRow {
                    cell("FC moy.") { Text("\(Int(run.avgHeartRate)) bpm") }
                    cell("Temp.") { Text("\(Fmt.num(run.temperatureC)) °C") }
                }
                GridRow {
                    cell("D+") { Text("\(Int(run.elevationGainM)) m") }
                    cell("Indice") { Text(Fmt.num(run.performanceIndex)).bold() }
                }
            }
            if let notes = run.notes, !notes.isEmpty {
                Text(notes).font(.system(size: 13)).foregroundStyle(Color.rxGrey)
            }
            HStack(spacing: 12) {
                Button(action: onEdit) { Image(systemName: "pencil").frame(maxWidth: .infinity) }
                    .buttonStyle(.rx(.ghost, small: true))
                    .accessibilityLabel("Modifier la course du \(Fmt.day(run.date))")
                Button(action: onDelete) { Image(systemName: "trash").frame(maxWidth: .infinity) }
                    .buttonStyle(.rx(.danger, small: true))
                    .accessibilityLabel("Supprimer la course du \(Fmt.day(run.date))")
            }
            .padding(.top, 2)
        }
        .font(.system(size: 14.5))
        .foregroundStyle(Color.rxInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: RX.radius))
        .overlay(RoundedRectangle(cornerRadius: RX.radius).stroke(Color.rxLine, lineWidth: 1))
    }

    @ViewBuilder
    private func cell(_ label: String, @ViewBuilder value: () -> Text) -> some View {
        Text(label)
            .font(.system(size: 13))
            .foregroundStyle(Color.rxGrey)
            .frame(width: 58, alignment: .leading)
        value()
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Écran large (iPad, paysage) : tableau comme sur la version web
struct RunsTable: View {
    let runs: [Run]
    let onEdit: (Run) -> Void
    let onDelete: (Run) -> Void

    var body: some View {
        ProportionalTable(headers: ["Date", "Distance", "Durée", "Allure", "FC moy.", "Temp.", "D+", "Indice", ""],
                          fractions: [0.13, 0.12, 0.11, 0.11, 0.105, 0.105, 0.085, 0.09, 0.145],
                          items: runs) { run, w in
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.day(run.date))
                Text(Fmt.time(run.date)).foregroundStyle(Color.rxGrey)
            }
            .font(.system(size: 13))
            .cell(w[0])
            Text("\(Fmt.num(run.distanceKm, digits: 2)) km").cell(w[1])
            Text(Fmt.duration(run.durationSec)).cell(w[2])
            Text(Fmt.pace(run.avgPaceSecPerKm)).cell(w[3])
            Text("\(Int(run.avgHeartRate)) bpm").cell(w[4])
            Text("\(Fmt.num(run.temperatureC)) °C").cell(w[5])
            Text("\(Int(run.elevationGainM)) m").cell(w[6])
            Text(Fmt.num(run.performanceIndex)).bold().cell(w[7])
            HStack(spacing: 6) {
                Button { onEdit(run) } label: { Image(systemName: "pencil").frame(width: 36, height: 36) }
                    .buttonStyle(IconButtonStyle(kind: .ghost))
                    .accessibilityLabel("Modifier la course du \(Fmt.day(run.date))")
                Button { onDelete(run) } label: { Image(systemName: "trash").frame(width: 36, height: 36) }
                    .buttonStyle(IconButtonStyle(kind: .danger))
                    .accessibilityLabel("Supprimer la course du \(Fmt.day(run.date))")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: w[8], alignment: .trailing)
        }
        .font(.system(size: 14.5))
        .monospacedDigit()
        // Valeurs sur une ligne, réduites si la colonne est étroite (iPad en portrait)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .foregroundStyle(Color.rxInk)
    }
}

// Bouton icône 36 × 36 (zone de toucher de la version web)
struct IconButtonStyle: ButtonStyle {
    var kind: RXButtonKind

    func makeBody(configuration: Configuration) -> some View {
        let danger = kind == .danger
        return configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(danger ? Color.rxDanger : Color.rxBlue)
            .background(configuration.isPressed ? (danger ? Color.rxDangerSoft : Color.rxBlueSoft) : .white,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(danger ? Color.rxDanger : Color.rxBlue, lineWidth: 1))
            .contentShape(Rectangle())
    }
}
