import SwiftUI

// Application connectée : barre supérieure + menu déroulant, contenu, bouton flottant « Nouvelle course »
struct MainView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @State private var menuOpen = false

    var body: some View {
        @Bindable var session = session
        VStack(spacing: 0) {
            TopBar(menuOpen: $menuOpen)
                .zIndex(2)
            ZStack(alignment: .bottomTrailing) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Écran large : bouton avec libellé ; téléphone : bouton rond « + »
                Button { session.runEditor = .new } label: {
                    HStack(spacing: 8) {
                        Text("+")
                            .font(.system(size: wide ? 26 : 32, weight: .regular))
                            .offset(y: -2)
                        if wide {
                            Text("Nouvelle course").font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, wide ? 16 : 0)
                    .padding(.trailing, wide ? 20 : 0)
                    .frame(minWidth: 56, minHeight: wide ? 52 : 56)
                    .background(Color.rxBlue, in: Capsule())
                    .shadow(color: Color.rxBlue.opacity(0.4), radius: 12, y: 8)
                }
                .accessibilityLabel("Nouvelle course")
                .padding(20)

                if menuOpen {
                    // Clic en dehors du menu : fermeture
                    Color.black.opacity(0.001)
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { menuOpen = false } }
                    NavMenu(open: $menuOpen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: wide ? .topTrailing : .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
        }
        .sheet(item: $session.runEditor) { editor in
            RunFormView(editor: editor)
        }
    }

    @ViewBuilder private var content: some View {
        switch session.route {
        case .home: HomeView()
        case .runs: RunsView()
        case .explication: ExplanationView()
        case .account: AccountView()
        case .adminUsers: AdminUsersView()
        case .adminLogs: AdminLogsView()
        }
    }
}

struct TopBar: View {
    @Environment(AppSession.self) private var session
    @Binding var menuOpen: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button { session.navigate(.home); menuOpen = false } label: { BrandText(size: 20) }
                .accessibilityLabel("RunX – Accueil")
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.15)) { menuOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1).fill(.white).frame(width: 18, height: 2)
                        }
                    }
                    Text("Menu").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(menuOpen ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .accessibilityValue(menuOpen ? "ouvert" : "fermé")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.rxBlack.ignoresSafeArea(edges: .top))
    }
}

// Panneau de navigation pleine largeur, sombre, sous la barre supérieure
struct NavMenu: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @Binding var open: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Route.allCases.filter { !$0.adminOnly || session.isAdmin }) { route in
                item(route.title, active: session.route == route) {
                    session.navigate(route)
                }
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.top, 6)
            item("Déconnexion", active: false) {
                Task { await session.logout() }
            }
        }
        .padding(wide ? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8) : EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
        .frame(maxWidth: wide ? 240 : .infinity)
        .background(Color.rxBlack, in: RoundedRectangle(cornerRadius: wide ? RX.radius : 0))
        .overlay {
            // Téléphone : panneau pleine largeur ; écran large : panneau flottant à droite, comme sur le web
            if wide {
                RoundedRectangle(cornerRadius: RX.radius).stroke(Color.white.opacity(0.12), lineWidth: 1)
            } else {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .shadow(color: Color.rxBlack.opacity(0.35), radius: 16, y: 12)
        .padding(.top, wide ? 6 : 0)
        .padding(.trailing, wide ? 20 : 0)
    }

    private func item(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { open = false }
            action()
        } label: {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(active ? .white : Color.rxNavText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(active ? Color.rxBlue : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Conteneur des écrans : défilement, fond gris, marge basse pour le bouton flottant
struct Screen<Content: View>: View {
    var onRefresh: (() async -> Void)?
    @ViewBuilder var content: Content
    @Environment(\.isWide) private var wide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: wide ? 18 : 10) {
                content
            }
            .padding(.horizontal, wide ? 20 : 6)
            .padding(.top, wide ? 28 : 14)
            .padding(.bottom, 96)
            // Toute la largeur de l'écran, y compris en paysage sur iPad (pas de largeur maximale)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await onRefresh?() }
        .background(Color.rxBg)
    }
}

// Pagination « ← Précédent · Page x / y · Suivant → »
struct Pager: View {
    @Binding var page: Int
    let total: Int
    let limit: Int

    var body: some View {
        let pages = max(1, Int(ceil(Double(total) / Double(limit))))
        HStack(spacing: 10) {
            Button("← Précédent") { page -= 1 }
                .buttonStyle(.rx(.ghost, small: true))
                .disabled(page <= 1)
            Spacer(minLength: 0)
            Text("Page \(page) / \(pages) · \(total) élément(s)")
                .font(.system(size: 13))
                .foregroundStyle(Color.rxGrey)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button("Suivant →") { page += 1 }
                .buttonStyle(.rx(.ghost, small: true))
                .disabled(page >= pages)
        }
        .padding(.top, 14)
    }
}
