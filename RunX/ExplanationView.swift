import SwiftUI

// Explication complète du calcul de l'indice (menu « Explication »)
struct ExplanationView: View {
    private let w = Trend.window

    var body: some View {
        Screen {
            PageHeader(title: "Explication de l'indice de performance",
                       subtitle: "Comment RunX évalue votre progression course après course.")

            section("L'idée de départ") {
                Text("L'indice mesure votre efficacité : la vitesse que vous tenez pour chaque battement de cœur. Courir plus vite ne suffit pas : si votre cœur doit battre beaucoup plus fort pour y parvenir, vous n'êtes pas plus performant, vous forcez davantage.")
                formula("Indice = 100 × vitesse équivalente plat (m/min) × correction température ÷ FC moyenne (bpm)")
                Text("Plus l'indice est élevé, plus vous êtes performant. Il se construit en quatre étapes.")
            }
            section("1. Vitesse équivalente plat : le dénivelé") {
                Text("Monter coûte de l'énergie. Chaque 100 m de dénivelé positif compte comme 1 km supplémentaire à plat (règle du « kilomètre-effort » utilisée en trail).")
                formula("distance effort (km) = distance + D+ ÷ 100\nvitesse (m/min) = distance effort × 1000 ÷ durée (min)")
                Text("Exemple : 10 km avec 150 m de D+ comptent comme 11,5 km à plat. Une sortie vallonnée n'est donc pas pénalisée par rapport à une sortie à plat.")
            }
            section("2. Correction de la température") {
                Text("La chaleur fait monter la fréquence cardiaque (le corps envoie du sang vers la peau pour se refroidir) ; le froid a un effet plus faible. L'indice est relevé quand les conditions sont difficiles :")
                table(["Température", "Facteur"], [
                    ["De 5 à 12 °C (zone idéale)", "× 1"],
                    ["Au-dessus de 12 °C", "+ 0,4 % par °C (25 °C → × 1,052)"],
                    ["En dessous de 5 °C", "+ 0,2 % par °C (−5 °C → × 1,02)"],
                ])
                Text("Ces coefficients reprennent l'ordre de grandeur observé sur les marathons : environ 0,3 à 0,4 % de performance perdue par degré au-delà de 10-15 °C.")
                    .foregroundStyle(Color.rxGrey)
            }
            section("3. Division par la fréquence cardiaque moyenne") {
                Text("Si votre vitesse augmente de 3 % mais votre fréquence cardiaque de 8 %, le rapport baisse : l'indice diminue, ce n'est pas une progression. À l'inverse, la même allure tenue avec un cœur plus calme fait monter l'indice.")
            }
            section("4. Multiplication par 100") {
                Text("Elle sert uniquement à obtenir un nombre lisible (de l'ordre de 100 à 160) plutôt que 1,35.")
            }
            section("Exemples") {
                table(["Course", "Calcul", "Indice"], [
                    ["10 km en 50:00, plat, 15 °C, 150 bpm", "200 × 1,012 ÷ 150 × 100", "134,9"],
                    ["Plus rapide (48:20) mais 162 bpm", "206,9 × 1,012 ÷ 162 × 100", "129,2 ↓"],
                    ["Même allure qu'au départ, 145 bpm", "200 × 1,012 ÷ 145 × 100", "139,6 ↑"],
                    ["50:00 avec 100 m de D+, 25 °C, 155 bpm", "220 × 1,052 ÷ 155 × 100", "149,3"],
                ])
                Text("La deuxième ligne illustre une fausse progression : l'allure s'améliore, mais le cœur s'emballe davantage. La troisième est une vraie progression. La dernière montre qu'une sortie lente au chrono peut être excellente une fois le dénivelé et la chaleur pris en compte.")
            }
            section("La tendance du tableau de bord") {
                Text("Une course isolée varie selon la fatigue, le sommeil ou le vent. Le tableau de bord compare donc la moyenne de vos \(w) dernières courses à celle des \(w) précédentes :")
                bullets([
                    Text("\(Text("En progression").bold()) : au-delà de +1,5 %"),
                    Text("\(Text("Stable").bold()) : entre −1,5 % et +1,5 %"),
                    Text("\(Text("En baisse").bold()) : en deçà de −1,5 %"),
                ])
                Text("Sur le graphique, la courbe orange est la moyenne de vos \(w) dernières courses à chaque date.")
            }
            section("Limites à connaître") {
                bullets([
                    Text("Le type de séance compte : un fractionné ne fait pas monter la fréquence cardiaque moyenne comme une sortie en endurance. Les comparaisons sont plus fiables entre séances similaires."),
                    Text("La fréquence cardiaque est propre à chacun : l'indice sert à vous comparer à vous-même, pas à d'autres coureurs."),
                    Text("Les coefficients de dénivelé et de température sont des moyennes générales, pas calibrés sur vos données."),
                ])
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.rxBlack)
                .padding(.bottom, 4)
            content()
        }
        .font(.system(size: 15.5))
        .foregroundStyle(Color.rxInk)
        .fixedSize(horizontal: false, vertical: true)
        .card(padding: 14)
    }

    private func formula(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rxBg, in: RoundedRectangle(cornerRadius: 8))
    }

    private func table(_ head: [String], _ rows: [[String]]) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 0) {
            GridRow {
                ForEach(head, id: \.self) { t in
                    Text(t.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(0.5)
                        .foregroundStyle(Color.rxGrey)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.rxBg)
            ForEach(rows.indices, id: \.self) { i in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(rows[i].indices, id: \.self) { j in
                        Text(rows[i][j])
                            .font(.system(size: 14))
                            .monospacedDigit()
                            .padding(.vertical, 8)
                            .fixedSize(horizontal: j == rows[i].count - 1, vertical: true)
                    }
                }
            }
            Divider().gridCellUnsizedAxes(.horizontal)
        }
    }

    private func bullets(_ items: [Text]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    items[i]
                }
            }
        }
    }
}
