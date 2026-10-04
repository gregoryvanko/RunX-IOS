import SwiftUI

// Écran de connexion : serveur, identifiant, mot de passe (ou création de compte)
struct LoginView: View {
    @Environment(AppSession.self) private var session
    @State private var server = CredentialStore.server ?? ""
    @State private var username = CredentialStore.username ?? ""
    @State private var password = CredentialStore.password ?? ""
    @State private var displayName = ""
    @State private var confirm = ""
    @State private var isRegister = false
    @State private var error = ""
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            StatusBarBand()
            ScrollView {
                VStack(spacing: 0) {
                    BrandText(size: 29, color: .rxBlack)
                        .padding(.bottom, 4)
                    Text(isRegister ? "Créez votre compte" : "Connectez-vous à votre espace")
                        .foregroundStyle(Color.rxGrey)
                        .padding(.bottom, 22)

                    VStack(alignment: .leading, spacing: 14) {
                        LabeledField(label: "Serveur") {
                            RXTextField(placeholder: "runx.vanko.be", text: $server, keyboard: .username)
                        }
                        LabeledField(label: "Identifiant") {
                            RXTextField(placeholder: "", text: $username, keyboard: .username)
                                .textContentType(.username)
                        }
                        if isRegister {
                            LabeledField(label: "Nom affiché (facultatif)") {
                                RXTextField(placeholder: "", text: $displayName)
                                    .textContentType(.name)
                            }
                        }
                        LabeledField(label: "Mot de passe") {
                            RXTextField(placeholder: "", text: $password, secure: true)
                                .textContentType(isRegister ? .newPassword : .password)
                        }
                        if isRegister {
                            LabeledField(label: "Confirmation") {
                                RXTextField(placeholder: "", text: $confirm, secure: true)
                                    .textContentType(.newPassword)
                            }
                        }
                        ErrorText(message: error)
                        Button(action: submit) {
                            HStack(spacing: 8) {
                                if busy { ProgressView().tint(.white) }
                                Text(isRegister ? "Créer mon compte" : "Se connecter")
                            }
                        }
                        .buttonStyle(.rx(.primary, block: true))
                        .disabled(busy)
                    }

                    HStack(spacing: 4) {
                        Text(isRegister ? "Déjà inscrit ?" : "Pas encore de compte ?")
                        Button(isRegister ? "Se connecter" : "Créer un compte") {
                            isRegister.toggle()
                            error = ""
                        }
                        .foregroundStyle(Color.rxBlue)
                    }
                    .font(.system(size: 15))
                    .padding(.top, 18)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 30)
                .frame(maxWidth: 380)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rxLine, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .onAppear { error = session.loginError }
    }

    private func submit() {
        error = ""
        if server.trimmingCharacters(in: .whitespaces).isEmpty { error = "Indiquez l'adresse du serveur"; return }
        if isRegister && password != confirm { error = "Les mots de passe ne correspondent pas"; return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await session.connect(server: server, username: username, password: password,
                                          register: isRegister, displayName: displayName)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
