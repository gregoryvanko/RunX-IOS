import Foundation

// Formats identiques à l'application web (locale fr-FR)
enum Fmt {
    static let locale = Locale(identifier: "fr_FR")

    static func num(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(locale).grouping(.automatic))
    }

    private static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    static func pace(_ secPerKm: Double) -> String {
        var m = Int(secPerKm / 60)
        var s = Int((secPerKm.truncatingRemainder(dividingBy: 60)).rounded())
        if s == 60 { m += 1; s = 0 }
        return "\(m):\(pad2(s)) /km"
    }

    static func duration(_ seconds: Double) -> String {
        let sec = Int(seconds.rounded())
        let h = sec / 3600, m = (sec % 3600) / 60, s = sec % 60
        return h > 0 ? "\(h):\(pad2(m)):\(pad2(s))" : "\(m):\(pad2(s))"
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = format
        return f
    }

    private static let dayF = formatter("dd/MM/yyyy")
    private static let shortDayF = formatter("dd/MM")
    private static let timeF = formatter("HH:mm")
    private static let compactDayF = formatter("dd/MM/yy")
    private static let secondsF = formatter("HH:mm:ss")
    private static let dateTimeF = formatter("dd/MM/yyyy HH:mm:ss")

    static func day(_ d: Date) -> String { dayF.string(from: d) }
    static func shortDay(_ d: Date) -> String { shortDayF.string(from: d) }
    static func time(_ d: Date) -> String { timeF.string(from: d) }
    static func compactDay(_ d: Date) -> String { compactDayF.string(from: d) }
    static func timeSeconds(_ d: Date) -> String { secondsF.string(from: d) }
    static func dateTime(_ d: Date?) -> String { d.map { dateTimeF.string(from: $0) } ?? "—" }

    static func signed(_ v: Double, unit: String = "") -> String {
        let sign = v > 0 ? "+" : v < 0 ? "−" : "±"
        return "\(sign)\(num(abs(v)))\(unit)"
    }

    // Saisie utilisateur : « 10,5 » ou « 10.5 » ; nil si vide ou invalide
    static func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "−", with: "-")
        return t.isEmpty ? nil : Double(t)
    }

    // Valeur pré-remplie dans un champ (pas de « .0 » inutile, virgule décimale)
    static func input(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v).replacingOccurrences(of: ".", with: ",")
    }
}

// ---------- Tendance ----------
enum Trend {
    static let window = 5

    enum Status: String { case up, down, flat, unknown }

    struct Analysis {
        var status: Status
        var label: String
        var change: Double?
    }

    static func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }

    // Moyenne mobile de l'indice sur les `window` dernières courses
    static func trend(of runs: [Run]) -> [Double] {
        runs.indices.map { i in mean(runs[max(0, i - window + 1)...i].map(\.performanceIndex)) }
    }

    // Compare les `window` dernières courses aux `window` précédentes
    static func analyse(_ runs: [Run]) -> Analysis {
        let values = runs.map(\.performanceIndex)
        let recent = Array(values.suffix(window))
        let before = Array(values.dropLast(window).suffix(window))
        guard !before.isEmpty else { return Analysis(status: .unknown, label: "Pas encore assez de courses", change: nil) }
        let change = (mean(recent) - mean(before)) / mean(before) * 100
        if change > 1.5 { return Analysis(status: .up, label: "En progression", change: change) }
        if change < -1.5 { return Analysis(status: .down, label: "En baisse", change: change) }
        return Analysis(status: .flat, label: "Stable", change: change)
    }

    // Message de synthèse du tableau de bord
    static func message(_ runs: [Run]) -> String {
        if runs.isEmpty {
            return "Chaussez vos baskets et enregistrez votre première course pour lancer le suivi de votre performance !"
        }
        let a = analyse(runs)
        let pct = a.change.map { Fmt.num(abs($0)) } ?? ""
        switch a.status {
        case .up:
            return "Belle progression : votre indice moyen a gagné \(pct) % sur vos \(window) dernières courses par rapport aux précédentes. Continuez comme ça !"
        case .down:
            return "Votre indice moyen a reculé de \(pct) % sur vos \(window) dernières courses par rapport aux précédentes. Fatigue, séances intenses ? Pensez à bien récupérer."
        case .flat:
            return "Performance stable sur vos \(window) dernières courses. Variez vos séances pour franchir un cap !"
        case .unknown:
            let missing = window + 1 - runs.count
            let done = runs.count > 1 ? "ces \(runs.count) courses" : "cette première course"
            return "Bravo pour \(done) ! Encore \(missing) course\(missing > 1 ? "s" : "") et votre tendance pourra être établie : à vos baskets !"
        }
    }
}
