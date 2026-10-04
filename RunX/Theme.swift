import SwiftUI

// Couleurs et styles repris de l'application web (public/css/style.css)
extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    static let rxBlack = Color(hex: 0x0A0F1C)
    static let rxInk = Color(hex: 0x111827)
    static let rxBlue = Color(hex: 0x1E5EFF)
    static let rxBlueHover = Color(hex: 0x164AD1)
    static let rxBlueDark = Color(hex: 0x0B1F4D)
    static let rxBlueSoft = Color(hex: 0xE8EFFF)
    static let rxGrey = Color(hex: 0x6B7280)
    static let rxLine = Color(hex: 0xDFE4EE)
    static let rxBg = Color(hex: 0xF5F7FB)
    static let rxDanger = Color(hex: 0xD92D20)
    static let rxDangerSoft = Color(hex: 0xFDECEA)
    static let rxWarn = Color(hex: 0xB54708)
    static let rxWarnSoft = Color(hex: 0xFFF4E5)
    static let rxGood = Color(hex: 0x067647)
    static let rxGoodSoft = Color(hex: 0xE7F6EC)
    static let rxNavText = Color(hex: 0xC7D2FE)
    static let rxGridLine = Color(hex: 0xECEFF5)
    static let rxSeriesIndex = Color(hex: 0x1E5EFF)
    static let rxSeriesTrend = Color(hex: 0xE8590C)
}

enum RX {
    static let radius: CGFloat = 10
    // Mêmes points de rupture que la feuille de style web
    static let wide: CGFloat = 760      // tableaux, menu en panneau, bouton « Nouvelle course » complet
    static let tiles4: CGFloat = 900    // indicateurs sur 4 colonnes
    static let twoColumnsForm: CGFloat = 500
}

// Largeur disponible pour la mise en page (équivalent des media queries CSS)
extension EnvironmentValues {
    @Entry var layoutWidth: CGFloat = 390
}

extension EnvironmentValues {
    var isWide: Bool { layoutWidth > RX.wide }
}

private struct LayoutWidthReader: ViewModifier {
    @State private var width: CGFloat = 390

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .environment(\.layoutWidth, width)
    }
}

extension View {
    // Mesure la largeur de la vue et la transmet à ses descendants (rotation, iPad, Split View)
    func measuresLayoutWidth() -> some View { modifier(LayoutWidthReader()) }
}

// Logo « RunX » : X en bleu
struct BrandText: View {
    var size: CGFloat = 20
    var color: Color = .white

    var body: some View {
        Text("\(Text("Run").foregroundStyle(color))\(Text("X").foregroundStyle(Color.rxBlue))")
            .font(.system(size: size, weight: .heavy))
            .kerning(0.5)
    }
}

// ---------- Cartes ----------
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    @Environment(\.isWide) private var wide

    func body(content: Content) -> some View {
        content
            .padding(wide ? 22 : padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: RX.radius))
            .overlay(RoundedRectangle(cornerRadius: RX.radius).stroke(Color.rxLine, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }
}

// ---------- Boutons ----------
enum RXButtonKind { case primary, ghost, danger, dangerSolid }

struct RXButtonStyle: ButtonStyle {
    var kind: RXButtonKind = .primary
    var block = false
    var small = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let (fg, bg, border): (Color, Color, Color) = switch kind {
        case .primary: (.white, pressed ? .rxBlueHover : .rxBlue, .rxBlue)
        case .ghost: (.rxBlue, pressed ? .rxBlueSoft : .white, .rxBlue)
        case .danger: (.rxDanger, pressed ? .rxDangerSoft : .white, .rxDanger)
        case .dangerSolid: (.white, pressed ? Color(hex: 0xB42318) : .rxDanger, .rxDanger)
        }
        return configuration.label
            .font(.system(size: small ? 14 : 16, weight: .semibold))
            .padding(.horizontal, small ? 10 : 16)
            .frame(minHeight: small ? 32 : 44)
            .frame(maxWidth: block ? .infinity : nil)
            .foregroundStyle(fg)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.6)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == RXButtonStyle {
    static var rxPrimary: RXButtonStyle { RXButtonStyle(kind: .primary) }
    static var rxGhost: RXButtonStyle { RXButtonStyle(kind: .ghost) }
    static var rxDanger: RXButtonStyle { RXButtonStyle(kind: .danger) }
    static func rx(_ kind: RXButtonKind, block: Bool = false, small: Bool = false) -> RXButtonStyle {
        RXButtonStyle(kind: kind, block: block, small: small)
    }
}

// ---------- Champs de formulaire ----------
struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Color.rxBlueDark)
    }
}

enum RXKeyboard { case text, decimal, number, signedDecimal, username }

struct RXTextField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: RXKeyboard = .text
    var monospaced = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .focused($focused)
        .font(monospaced ? .system(.body, design: .monospaced) : .body)
        .foregroundStyle(Color.rxInk)
        .rxKeyboard(keyboard)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Color.rxBlue : Color.rxLine, lineWidth: focused ? 2 : 1))
        // Toute la surface du champ donne le focus, pas seulement le texte
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { focused = true }
    }
}

extension View {
    @ViewBuilder func rxKeyboard(_ kind: RXKeyboard) -> some View {
        #if os(iOS) || os(visionOS)
        switch kind {
        case .text: self
        case .decimal: self.keyboardType(.decimalPad)
        case .number: self.keyboardType(.numberPad)
        // Le pavé décimal iOS n'a pas de signe moins : clavier numérique complet
        case .signedDecimal: self.keyboardType(.numbersAndPunctuation)
        case .username:
            self.keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        #else
        self
        #endif
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            content
        }
    }
}

// Liste déroulante au même gabarit qu'un champ texte
struct RXPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    var height: CGFloat = 44
    var disabled = false

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { value, label in
                Button {
                    selection = value
                } label: {
                    if value == selection { Label(label, systemImage: "checkmark") } else { Text(label) }
                }
            }
        } label: {
            HStack {
                Text(options.first { $0.0 == selection }?.1 ?? "")
                    .font(.system(size: height < 44 ? 15 : 16))
                    .foregroundStyle(Color.rxInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.rxBlueDark)
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.rxLine, lineWidth: 1))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}

// ---------- Badges ----------
struct Badge: View {
    let text: String
    var fg: Color = .rxBlueDark
    var bg: Color = .rxBlueSoft

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

// Titre de page + sous-titre grisé
struct PageHeader: View {
    let title: String
    var subtitle: String?
    @Environment(\.isWide) private var wide

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: wide ? 26 : 25, weight: .bold))
                .foregroundStyle(Color.rxBlack)
            if let subtitle {
                Text(subtitle).foregroundStyle(Color.rxGrey)
            }
        }
        .padding(.horizontal, wide ? 0 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ---------- Tableaux (écrans larges) ----------
struct TableHeaderCell: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(Color.rxGrey)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
    }
}

struct TableLine: View {
    var body: some View {
        Rectangle().fill(Color.rxLine).frame(height: 1)
    }
}

extension View {
    // Cellule de tableau de largeur fixe : le texte passe à la ligne au lieu d'élargir le tableau
    func cell(_ width: CGFloat, alignment: Alignment = .leading) -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(width: width, alignment: alignment)
    }
}

// Tableau dont les colonnes sont des fractions de la largeur disponible :
// il ne déborde jamais de l'écran (iPad en portrait, Split View…)
struct ProportionalTable<Item: Identifiable, Row: View>: View {
    let headers: [String]
    let fractions: [CGFloat]
    let items: [Item]
    @ViewBuilder let row: (Item, [CGFloat]) -> Row
    @State private var width: CGFloat = 0

    var body: some View {
        let widths = fractions.map { max(0, $0 * width) }
        VStack(alignment: .leading, spacing: 0) {
            if width > 0 {
                HStack(spacing: 0) {
                    ForEach(headers.indices, id: \.self) { i in
                        TableHeaderCell(headers[i]).frame(width: widths[i], alignment: .leading)
                    }
                }
                .background(Color.rxBg)
                TableLine()
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 0) { row(item, widths) }
                    TableLine()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

struct ErrorText: View {
    let message: String
    var body: some View {
        if !message.isEmpty {
            Text(message)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.rxDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
