import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    let run: Run
    let trend: Double
    var id: String { run.id }
    var date: Date { run.date }
}

// Graphique d'évolution : indice par course (bleu), tendance (orange), objectif (pointillés).
// Toucher / glisser le doigt sur le graphique affiche le détail de la course la plus proche.
struct PerfChart: View {
    let points: [ChartPoint]
    let targetIndex: Double?
    @Environment(\.layoutWidth) private var width
    // Glisser : sélection temporaire ; toucher : sélection conservée (comme sur le web)
    @State private var dragDate: Date?
    @State private var tapDate: Date?

    private var selected: ChartPoint? {
        guard let selectedDate = dragDate ?? tapDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    // Échelle verticale arrondie à un pas « rond », comme la version web
    private var yScale: (domain: ClosedRange<Double>, step: Double) {
        var values = points.flatMap { [$0.run.performanceIndex, $0.trend] }
        if let targetIndex { values.append(targetIndex) }
        var lo = values.min() ?? 0, hi = values.max() ?? 1
        if hi - lo < 4 { lo -= 2; hi += 2 }
        let raw = (hi - lo) / 4
        let mag = pow(10, floor(log10(raw)))
        let step = [1, 2, 2.5, 5, 10].map { $0 * mag }.first { $0 >= raw } ?? raw
        return ((floor(lo / step) * step)...(ceil(hi / step) * step), step)
    }

    // Domaine horizontal : une seule course → une journée centrée sur elle
    private var xDomain: ClosedRange<Date> {
        let first = points.first!.date, last = points.last!.date
        if first == last { return first.addingTimeInterval(-43200)...last.addingTimeInterval(43200) }
        return first...last
    }

    var body: some View {
        let scale = yScale
        Chart {
            if let targetIndex {
                RuleMark(y: .value("Objectif", targetIndex))
                    .foregroundStyle(Color.rxBlueDark)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("Objectif \(Fmt.num(targetIndex))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.rxBlueDark)
                            .monospacedDigit()
                    }
            }

            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Indice", p.run.performanceIndex), series: .value("Série", "Indice"))
                    .foregroundStyle(Color.rxSeriesIndex.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Tendance", p.trend), series: .value("Série", "Tendance"))
                    .foregroundStyle(Color.rxSeriesTrend)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            ForEach(points) { p in
                PointMark(x: .value("Date", p.date), y: .value("Indice", p.run.performanceIndex))
                    .symbol {
                        let active = selected?.id == p.id
                        Circle()
                            .fill(Color.rxSeriesIndex)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: active ? 14 : 10, height: active ? 14 : 10)
                    }
            }
            if let last = points.last {
                PointMark(x: .value("Date", last.date), y: .value("Tendance", last.trend))
                    .symbol {
                        Circle().fill(Color.rxSeriesTrend).stroke(Color.white, lineWidth: 2).frame(width: 10, height: 10)
                    }
            }

            // En dernier : l'infobulle passe au-dessus des courbes
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.rxGrey)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(point: selected, targetIndex: targetIndex)
                    }
            }
        }
        .chartYScale(domain: scale.domain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: scale.step)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.rxGridLine)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.num(v, digits: scale.step < 1 ? 1 : 0))
                            .font(.system(size: 11)).foregroundStyle(Color.rxGrey).monospacedDigit()
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(Fmt.shortDay(d)).font(.system(size: 11)).foregroundStyle(Color.rxGrey)
                    }
                }
            }
        }
        .chartXSelection(value: $dragDate)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let frame = proxy.plotFrame else { return }
                        let x = location.x - geo[frame].origin.x
                        if let date: Date = proxy.value(atX: x) { tapDate = date }
                    }
            }
        }
        // Fin du glissement : la dernière course survolée reste sélectionnée
        .onChange(of: dragDate) { old, new in if new == nil, let old { tapDate = old } }
        .frame(height: width < 560 ? 260 : width > 1200 ? 380 : 320)
        .padding(.top, 4)
        .accessibilityLabel("Évolution de l'indice de performance sur \(points.count) course(s)")
    }
}

struct ChartTooltip: View {
    let point: ChartPoint
    let targetIndex: Double?

    var body: some View {
        let r = point.run
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.day(r.date)).fontWeight(.semibold).padding(.bottom, 2)
            row(Color.rxSeriesIndex, Fmt.num(r.performanceIndex), "indice")
            row(Color.rxSeriesTrend, Fmt.num(point.trend), "tendance (\(Trend.window) courses)")
            if let targetIndex { row(Color.rxBlueDark, Fmt.num(targetIndex), "objectif", dashed: true) }
            Text("\(Fmt.num(r.distanceKm, digits: 2)) km · \(Fmt.pace(r.avgPaceSecPerKm)) · \(Int(r.avgHeartRate)) bpm · \(Fmt.num(r.temperatureC)) °C · D+ \(Int(r.elevationGainM)) m")
                .font(.system(size: 12))
                .foregroundStyle(Color.rxGrey)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.rxInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 250, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.rxLine, lineWidth: 1))
        .shadow(color: Color.rxBlack.opacity(0.12), radius: 10, y: 6)
    }

    private func row(_ color: Color, _ value: String, _ label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            Line().stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : [])).frame(width: 16, height: 2)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.rxBlack).monospacedDigit()
            Text(label).foregroundStyle(Color.rxGrey).lineLimit(1)
        }
    }
}
