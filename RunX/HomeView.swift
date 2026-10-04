import SwiftUI

// Tableau de bord : évolution de l'indice de performance course après course
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.layoutWidth) private var width
    @State private var runs: [Run] = []
    @State private var loaded = false
    @State private var period = "all"
    @State private var periodChosen = false
    @State private var editingTarget = false

    var body: some View {
        Screen(onRefresh: load) {
            if let user = session.user {
                hero(user)
                if loaded {
                    if runs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Aucune course enregistrée")
                                .font(.system(size: 18, weight: .bold)).foregroundStyle(Color.rxBlack)
                            Button("+ Ajouter une course") { session.runEditor = .new }
                                .buttonStyle(.rxPrimary)
                        }
                        .card()
                    } else {
                        tiles
                        chartCard(user)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(40)
                }
            }
        }
        .task(id: session.reloadToken) { await load() }
        .sheet(isPresented: $editingTarget) {
            TargetFormView(target: session.user?.target)
        }
    }

    private func load() async {
        guard let api = session.api else { return }
        do {
            async let me = api.me()
            async let page = api.listRuns(order: "asc", limit: 500)
            let (user, data) = try await (me, page)
            session.updateUser(user)
            runs = data.items
            if !periodChosen { period = runs.count > 30 ? "30" : "all" }
            loaded = true
        } catch {
            session.show(error)
        }
    }

    private func hero(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bienvenue \(user.displayName) !")
                .font(.system(size: width > RX.wide ? 24 : 20, weight: .bold))
                .foregroundStyle(.white)
            Text(loaded ? Trend.message(runs) : " ")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.rxNavText)
        }
        .padding(.horizontal, width > RX.wide ? 24 : 16)
        .padding(.vertical, width > RX.wide ? 20 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(stops: [.init(color: .rxBlack, location: 0), .init(color: .rxBlueDark, location: 0.6), .init(color: .rxBlue, location: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14))
    }

    // ---------- Indicateurs ----------
    private var tiles: some View {
        let last = runs[runs.count - 1]
        let prev = runs.count > 1 ? runs[runs.count - 2] : nil
        let trend = Trend.analyse(runs)
        let best = runs.max { $0.performanceIndex < $1.performanceIndex }!
        let spacing: CGFloat = width > RX.wide ? 12 : 8

        let lastTile = Tile(label: "Dernière course") {
            TileValue(Fmt.num(last.performanceIndex))
            TileSub(prev.map { "\(Fmt.signed(last.performanceIndex - $0.performanceIndex)) vs la précédente" } ?? Fmt.day(last.date))
        }
        let trendTile = Tile(label: "Tendance") {
            TrendStatus(analysis: trend)
            TileSub(trend.change.map { "\(Fmt.signed($0, unit: " %")) : \(Trend.window) dernières vs \(Trend.window) précédentes" }
                    ?? "Comparaison dès \(Trend.window + 1) courses")
        }
        let bestTile = Tile(label: "Meilleur indice") {
            TileValue(Fmt.num(best.performanceIndex))
            TileSub(Fmt.day(best.date))
        }
        let countTile = Tile(label: "Courses") {
            TileValue(String(runs.count))
            Button("Voir la liste →") { session.navigate(.runs) }
                .font(.system(size: 13))
                .foregroundStyle(Color.rxBlue)
        }

        // 4 colonnes au-delà de 900 pt (iPad, paysage), 2 sinon ; tuiles d'une même ligne à la même hauteur
        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            if width > RX.tiles4 {
                GridRow { lastTile; trendTile; bestTile; countTile }
            } else {
                GridRow { lastTile; trendTile }
                GridRow { bestTile; countTile }
            }
        }
    }

    // ---------- Graphique ----------
    private func chartCard(_ user: User) -> some View {
        let trend = Trend.trend(of: runs)
        let points = zip(runs, trend).map { ChartPoint(run: $0, trend: $1) }
        let shown = period == "all" ? points : Array(points.suffix(Int(period) ?? points.count))
        let target = user.target

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Évolution de l'indice de performance")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.rxBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
                RXPicker(selection: Binding(get: { period }, set: { period = $0; periodChosen = true }),
                         options: [("15", "15 dernières"), ("30", "30 dernières"), ("all", "Toutes")],
                         height: 38)
                    .fixedSize()
                Button { editingTarget = true } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.rxBlueDark)
                        .frame(width: 38, height: 38)
                        .background(target != nil ? Color.rxBlueSoft : .white, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(target != nil ? Color.rxBlueDark : Color.rxLine, lineWidth: 1))
                }
                .accessibilityLabel(target.map { "Modifier l'objectif d'indice (\(Fmt.num($0.performanceIndex)))" } ?? "Définir un objectif d'indice")
            }

            PerfChart(points: shown, targetIndex: target?.performanceIndex)

            FlowLegend(target: target)
        }
        .card(padding: 12)
    }
}

// ---------- Tuiles ----------
struct Tile<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rxGrey)
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: RX.radius))
        .overlay(RoundedRectangle(cornerRadius: RX.radius).stroke(Color.rxLine, lineWidth: 1))
    }
}

struct TileValue: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color.rxBlack)
            .monospacedDigit()
    }
}

struct TileSub: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.rxGrey)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TrendStatus: View {
    let analysis: Trend.Analysis

    var body: some View {
        let (icon, fg, bg): (String, Color, Color) = switch analysis.status {
        case .up: ("▲", .rxGood, .rxGoodSoft)
        case .down: ("▼", .rxDanger, .rxDangerSoft)
        case .flat: ("▶", .rxBlueDark, .rxBlueSoft)
        case .unknown: ("…", .rxBlueDark, .rxBlueSoft)
        }
        HStack(spacing: 6) {
            Text(icon).font(.system(size: 11))
            Text(analysis.label).font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(bg, in: Capsule())
        .padding(.vertical, 4)
    }
}

struct FlowLegend: View {
    let target: Target?

    var body: some View {
        // Sur une ligne si la place le permet, sinon une entrée par ligne
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { keys }
            VStack(alignment: .leading, spacing: 4) { keys }
        }
        .frame(maxWidth: .infinity)
        if let target {
            HStack(spacing: 6) {
                Line().stroke(Color.rxBlueDark, style: StrokeStyle(lineWidth: 2, dash: [4, 3])).frame(width: 16, height: 2)
                Text("Objectif (\(Fmt.num(target.performanceIndex)))")
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.rxGrey)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var keys: some View {
        key(Color.rxSeriesIndex, "Indice par course")
        key(Color.rxSeriesTrend, "Tendance (moyenne des \(Trend.window) dernières)")
    }

    private func key(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 16, height: 2)
            Text(label)
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.rxGrey)
    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
