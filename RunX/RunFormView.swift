import SwiftUI

// Champs communs à une course et à un objectif d'indice
@Observable
final class RunFields {
    var date = Date()
    var distance = ""
    var hours = ""
    var minutes = ""
    var seconds = ""
    var heartRate = ""
    var temperature = ""
    var elevation = ""
    var notes = ""

    init() {}

    init(distanceKm: Double, durationSec: Double, avgHeartRate: Double, temperatureC: Double, elevationGainM: Double) {
        let dur = Int(durationSec.rounded())
        distance = Fmt.input(distanceKm)
        hours = String(dur / 3600)
        minutes = String((dur % 3600) / 60)
        seconds = String(dur % 60)
        heartRate = Fmt.input(avgHeartRate)
        temperature = Fmt.input(temperatureC)
        elevation = Fmt.input(elevationGainM)
    }

    var durationSec: Double {
        (Fmt.parse(hours) ?? 0) * 3600 + (Fmt.parse(minutes) ?? 0) * 60 + (Fmt.parse(seconds) ?? 0)
    }

    // Dénivelé vide = 0, comme sur le web ; les autres champs vides sont signalés par le serveur
    func input(withDate: Bool) -> RunInput {
        RunInput(
            date: withDate ? date.ISO8601Format() : nil,
            distanceKm: Fmt.parse(distance),
            durationSec: durationSec,
            avgHeartRate: Fmt.parse(heartRate),
            temperatureC: Fmt.parse(temperature),
            elevationGainM: elevation.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : Fmt.parse(elevation),
            notes: withDate ? notes : nil)
    }

    // Clé de l'aperçu : il est recalculé quand elle change
    var previewKey: String { [distance, hours, minutes, seconds, heartRate, temperature, elevation].joined(separator: "|") }
}

// Aperçu « allure / indice » calculé par l'API (même formule que l'enregistrement)
struct RunPreview: View {
    @Environment(AppSession.self) private var session
    let fields: RunFields
    var paceLabel = "Allure moyenne"
    var indexLabel = "Indice de performance"
    @State private var pace = "—"
    @State private var index = "—"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(paceLabel).font(.system(size: 12.5)).foregroundStyle(Color.rxGrey)
                Text(pace).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.rxBlueDark).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(indexLabel).font(.system(size: 12.5)).foregroundStyle(Color.rxGrey)
                Text(index).font(.system(size: 24, weight: .bold)).foregroundStyle(Color.rxBlueDark).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.rxBlueSoft, in: RoundedRectangle(cornerRadius: 8))
        .task(id: fields.previewKey) { await refresh() }
    }

    private func refresh() async {
        try? await Task.sleep(for: .milliseconds(250))
        if Task.isCancelled { return }
        let p = fields.input(withDate: false)
        guard let distance = Fmt.parse(fields.distance), distance > 0, p.durationSec > 0 else {
            pace = "—"; index = "—"; return
        }
        pace = Fmt.pace(p.durationSec / distance)
        guard Fmt.parse(fields.heartRate) != nil, Fmt.parse(fields.temperature) != nil, let api = session.api else {
            index = "—"; return
        }
        do {
            let perf = try await api.previewRun(p)
            index = Fmt.num(perf.performanceIndex)
        } catch {
            if !Task.isCancelled { index = "—" }
        }
    }
}

struct RunFieldsForm: View {
    @Bindable var fields: RunFields
    // Course : le champ Notes complète la dernière ligne ; objectif : pas de notes
    var withNotes = false
    @Environment(\.layoutWidth) private var width

    var body: some View {
        let distance = LabeledField(label: "Distance (km)") {
            RXTextField(placeholder: "10,0", text: $fields.distance, keyboard: .decimal)
        }
        let duration = LabeledField(label: "Durée (h : min : s)") {
            HStack(spacing: 6) {
                RXTextField(placeholder: "h", text: $fields.hours, keyboard: .number).multilineTextAlignment(.center)
                    .accessibilityLabel("Heures")
                RXTextField(placeholder: "min", text: $fields.minutes, keyboard: .number).multilineTextAlignment(.center)
                    .accessibilityLabel("Minutes")
                RXTextField(placeholder: "s", text: $fields.seconds, keyboard: .number).multilineTextAlignment(.center)
                    .accessibilityLabel("Secondes")
            }
        }
        let heartRate = LabeledField(label: "FC moyenne (bpm)") {
            RXTextField(placeholder: "150", text: $fields.heartRate, keyboard: .number)
        }
        let temperature = LabeledField(label: "Température (°C)") {
            RXTextField(placeholder: "15", text: $fields.temperature, keyboard: .signedDecimal)
        }
        let elevation = LabeledField(label: "Dénivelé positif (m)") {
            RXTextField(placeholder: "0", text: $fields.elevation, keyboard: .number)
        }
        let notes = LabeledField(label: "Notes (facultatif)") {
            RXTextField(placeholder: "Sortie longue, fractionné…", text: $fields.notes)
        }

        // Deux colonnes dès que la fenêtre est assez large (iPad, paysage), une seule sinon
        if width >= RX.twoColumnsForm {
            Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow { distance; duration }
                GridRow { heartRate; temperature }
                GridRow {
                    elevation
                    if withNotes { notes } else { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        } else {
            distance
            duration
            heartRate
            temperature
            elevation
            if withNotes { notes }
        }
    }
}

// Fenêtre « Nouvelle course » / « Modifier la course »
struct RunFormView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let editor: RunEditor
    @State private var fields: RunFields
    @State private var error = ""
    @State private var busy = false

    init(editor: RunEditor) {
        self.editor = editor
        if case .edit(let run) = editor {
            let f = RunFields(distanceKm: run.distanceKm, durationSec: run.durationSec, avgHeartRate: run.avgHeartRate,
                              temperatureC: run.temperatureC, elevationGainM: run.elevationGainM)
            f.date = run.date
            f.notes = run.notes ?? ""
            _fields = State(initialValue: f)
        } else {
            _fields = State(initialValue: RunFields())
        }
    }

    private var editing: Bool { if case .edit = editor { true } else { false } }

    var body: some View {
        DialogScaffold(title: editing ? "Modifier la course" : "Nouvelle course") {
            LabeledField(label: "Date et heure") {
                DatePicker("", selection: $fields.date, in: ...Date().addingTimeInterval(86400))
                    .labelsHidden()
                    .environment(\.locale, Fmt.locale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            RunFieldsForm(fields: fields, withNotes: true)
            RunPreview(fields: fields)
            ErrorText(message: error)
            HStack(spacing: 10) {
                Spacer()
                Button("Annuler") { dismiss() }.buttonStyle(.rxGhost)
                Button(editing ? "Enregistrer" : "Ajouter la course", action: submit)
                    .buttonStyle(.rxPrimary)
                    .disabled(busy)
            }
        }
    }

    private func submit() {
        error = ""
        if Fmt.parse(fields.temperature) == nil { error = "La température est obligatoire"; return }
        guard let api = session.api else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let input = fields.input(withDate: true)
                let run: Run
                if case .edit(let existing) = editor {
                    run = try await api.updateRun(id: existing.id, input)
                } else {
                    run = try await api.createRun(input)
                }
                dismiss()
                session.runSaved(run, isNew: !editing)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// Objectif d'indice : course « type » visée, tracée en pointillés sur le graphique
struct TargetFormView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let target: Target?
    @State private var fields: RunFields
    @State private var error = ""
    @State private var busy = false

    init(target: Target?) {
        self.target = target
        if let t = target {
            _fields = State(initialValue: RunFields(distanceKm: t.distanceKm, durationSec: t.durationSec, avgHeartRate: t.avgHeartRate,
                                                    temperatureC: t.temperatureC, elevationGainM: t.elevationGainM))
        } else {
            _fields = State(initialValue: RunFields())
        }
    }

    var body: some View {
        DialogScaffold(title: "Objectif d'indice") {
            Text("Décrivez la course que vous visez : son indice sera tracé en pointillés sur le graphique.")
                .foregroundStyle(Color.rxGrey)
            RunFieldsForm(fields: fields)
            RunPreview(fields: fields, paceLabel: "Allure visée", indexLabel: "Indice objectif")
            ErrorText(message: error)
            HStack(spacing: 10) {
                if target != nil {
                    Button("Supprimer") { save(delete: true) }.buttonStyle(.rxDanger).disabled(busy)
                }
                Spacer()
                Button("Annuler") { dismiss() }.buttonStyle(.rxGhost)
                Button("Enregistrer") { save(delete: false) }.buttonStyle(.rxPrimary).disabled(busy)
            }
        }
    }

    private func save(delete: Bool) {
        error = ""
        if !delete && Fmt.parse(fields.temperature) == nil { error = "La température est obligatoire"; return }
        guard let api = session.api else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let user = delete ? try await api.deleteTarget() : try await api.setTarget(fields.input(withDate: false))
                session.updateUser(user)
                dismiss()
                session.show(user.target.map { "Objectif fixé · indice \(Fmt.num($0.performanceIndex))" } ?? "Objectif supprimé")
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// Mise en page des fenêtres de saisie (titre, contenu défilant)
struct DialogScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.rxBlack)
                content
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        // Largeur de la fenêtre elle-même (et non de l'écran) pour choisir 1 ou 2 colonnes
        .measuresLayoutWidth()
        .presentationSizing(.form)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
