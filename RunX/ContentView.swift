import SwiftUI

// Racine : reconnexion au lancement, puis écran de connexion ou application
struct ContentView: View {
    @State private var session = AppSession()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rxBg.ignoresSafeArea()
            switch session.phase {
            case .starting:
                SplashView()
            case .loggedOut:
                LoginView()
            case .loggedIn:
                MainView()
            }
            ToastView(toast: session.toast, raised: session.phase == .loggedIn)
        }
        .measuresLayoutWidth()
        .environment(session)
        .preferredColorScheme(.light)
        .tint(.rxBlue)
        .task { await session.start() }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 0) {
            StatusBarBand()
            Spacer()
            BrandText(size: 34, color: .rxBlack)
            ProgressView().padding(.top, 16)
            Spacer()
        }
    }
}

// Bandeau sombre derrière l'heure et la batterie, sur tous les écrans (comme la version web)
struct StatusBarBand: View {
    var body: some View {
        Color.rxBlack
            .frame(height: 0)
            .background(Color.rxBlack.ignoresSafeArea(edges: .top))
    }
}

struct ToastView: View {
    let toast: Toast?
    var raised: Bool

    var body: some View {
        if let toast {
            Text(toast.message)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(toast.isError ? Color.rxDanger : Color.rxBlack, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.rxBlack.opacity(0.25), radius: 12, y: 6)
                .padding(.horizontal, 20)
                // Au-dessus du bouton flottant « Nouvelle course »
                .padding(.bottom, raised ? 84 : 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
