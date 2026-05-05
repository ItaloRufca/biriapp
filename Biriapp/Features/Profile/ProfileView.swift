import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var avatarURL = ""
    @State private var visibility: ProfileVisibility = .public
    @State private var legacyCode = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Conta")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(session.email.isEmpty ? "Sem email" : session.email)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Perfil")
                                .font(.headline)
                                .foregroundStyle(.white)

                            field("Nome de usuário", text: $username)
                            field("URL do avatar", text: $avatarURL)

                            Picker("Privacidade", selection: $visibility) {
                                Text("Público").tag(ProfileVisibility.public)
                                Text("Privado").tag(ProfileVisibility.private)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Legado")
                                .font(.headline)
                                .foregroundStyle(.white)

                            if session.hasClaimedLegacy {
                                Text("Legado já resgatado")
                                    .foregroundStyle(.white.opacity(0.75))
                            } else {
                                field("Código de legado", text: $legacyCode)

                                Button("Resgatar legado") {
                                    Task { await claimLegacy() }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .disabled(isLoading)
                            }
                        }
                    }

                    if let infoMessage {
                        Text(infoMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(isLoading ? "Salvando..." : "Salvar") {
                        Task { await saveProfile() }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(isLoading)

                    Button("Sair", role: .destructive) {
                        Task { await signOut() }
                    }
                    .disabled(isLoading)
                }
                .padding(16)
            }
            .premiumBackground()
            .navigationTitle("Perfil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                username = session.username
                avatarURL = session.avatarURLString
                visibility = session.visibility
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(.white)
            .padding(12)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .premiumPanel()
    }

    private func saveProfile() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        do {
            try await session.updateProfile(username: username, avatarURLString: avatarURL, visibility: visibility)
            infoMessage = "Perfil atualizado."
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func claimLegacy() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        do {
            let message = try await session.claimLegacy(accessCode: legacyCode)
            infoMessage = message
            legacyCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signOut() async {
        isLoading = true
        errorMessage = nil
        do {
            try await session.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppSession())
}
