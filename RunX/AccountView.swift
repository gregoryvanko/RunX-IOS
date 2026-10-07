import SwiftUI

struct AccountView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.isWide) private var wide
    @State private var name = ""
    @State private var current = ""
    @State private var next = ""
    @State private var confirm = ""
    @State private var pwdError = ""
    @State private var savingName = false
    @State private var savingPwd = false
    @State private var deletePwd = ""
    @State private var deleteError = ""
    @State private var confirmDelete = false
    @State private var deleting = false

    var body: some View {
        Screen {
            PageHeader(title: "Mon compte", subtitle: "Connecté en tant que \(session.user?.username ?? "")")

            // Écran large : Profil et Mot de passe côte à côte, à la même hauteur
            if wide {
                Grid(alignment: .topLeading, horizontalSpacing: 18, verticalSpacing: 18) {
                    GridRow { profileCard; passwordCard }
                }
            } else {
                profileCard
                passwordCard
            }
            serverCard
            deleteCard
        }
        .onAppear { name = session.user?.displayName ?? "" }
        .alert("Supprimer mon compte", isPresented: $confirmDelete) {
            Button("Supprimer définitivement", role: .destructive, action: deleteAccount)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Votre compte, toutes vos courses et votre objectif seront supprimés définitivement. Cette action est irréversible.")
        }
    }

    private var deleteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Supprimer mon compte")
            if session.isMainAdmin {
                // Le compte administrateur principal est protégé par le serveur
                Text("Votre compte est le compte administrateur principal : il est protégé et ne peut pas être supprimé.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.rxGrey)
            } else {
                Text("Supprime définitivement votre compte et toutes vos données (courses, objectif). Vos autres appareils seront déconnectés.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.rxGrey)
                LabeledField(label: "Mot de passe") {
                    RXTextField(placeholder: "", text: $deletePwd, secure: true).textContentType(.password)
                }
                ErrorText(message: deleteError)
                Button("Supprimer mon compte") {
                    deleteError = ""
                    if deletePwd.isEmpty { deleteError = "Saisissez votre mot de passe pour confirmer"; return }
                    confirmDelete = true
                }
                .buttonStyle(.rx(.dangerSolid))
                .disabled(deleting)
            }
        }
        .card(padding: 14)
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Profil")
            LabeledField(label: "Nom affiché") { RXTextField(placeholder: "", text: $name) }
            Button("Enregistrer", action: saveName)
                .buttonStyle(.rxPrimary)
                .disabled(savingName)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(padding: 14)
    }

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Mot de passe")
            LabeledField(label: "Mot de passe actuel") {
                RXTextField(placeholder: "", text: $current, secure: true).textContentType(.password)
            }
            LabeledField(label: "Nouveau mot de passe") {
                RXTextField(placeholder: "", text: $next, secure: true).textContentType(.newPassword)
            }
            LabeledField(label: "Confirmation") {
                RXTextField(placeholder: "", text: $confirm, secure: true).textContentType(.newPassword)
            }
            ErrorText(message: pwdError)
            Button("Changer le mot de passe", action: savePassword)
                .buttonStyle(.rxPrimary)
                .disabled(savingPwd)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .card(padding: 14)
    }

    // Propre à l'application iOS : serveur auquel l'application est reliée
    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Serveur")
            Text(session.serverDisplay)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.rxInk)
            Text("La déconnexion efface le mot de passe enregistré sur cet appareil ; vous pourrez alors choisir un autre serveur.")
                .font(.system(size: 14))
                .foregroundStyle(Color.rxGrey)
        }
        .card(padding: 14)
    }

    private func saveName() {
        guard let api = session.api else { return }
        savingName = true
        Task {
            defer { savingName = false }
            do {
                session.updateUser(try await api.updateMe(displayName: name))
                session.show("Profil mis à jour")
            } catch { session.show(error) }
        }
    }

    private func savePassword() {
        pwdError = ""
        if next != confirm { pwdError = "Les mots de passe ne correspondent pas"; return }
        guard let api = session.api else { return }
        savingPwd = true
        Task {
            defer { savingPwd = false }
            do {
                let res = try await api.changePassword(current: current, new: next)
                session.passwordChanged(res, newPassword: next)
                current = ""; next = ""; confirm = ""
                session.show("Mot de passe modifié")
            } catch { pwdError = error.localizedDescription }
        }
    }

    private func deleteAccount() {
        guard let api = session.api, !session.isMainAdmin else { return }
        deleting = true
        Task {
            defer { deleting = false }
            do {
                try await api.deleteAccount(password: deletePwd)
                session.accountDeleted()
            } catch is CancellationError {
            } catch { deleteError = error.localizedDescription }
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.rxBlack)
    }
}
