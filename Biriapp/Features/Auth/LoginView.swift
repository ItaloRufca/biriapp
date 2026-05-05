import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AppSession

    @State private var mode: LoginMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("BiriApp")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Seu app premium de carteados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(spacing: 14) {
                    Picker("Modo", selection: $mode) {
                        Text("Entrar").tag(LoginMode.signIn)
                        Text("Cadastrar").tag(LoginMode.signUp)
                    }
                    .pickerStyle(.segmented)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    SecureField("Senha", text: $password)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text(mode == .signIn ? "Entrar" : "Cadastrar")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(isLoading)
                }
                .padding(18)
                .premiumPanel()

                Spacer()
            }
            .padding(20)
            .premiumBackground()
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            if mode == .signIn {
                try await session.signIn(email: email, password: password)
            } else {
                try await session.signUp(email: email, password: password)
                infoMessage = "Conta criada. Agora faça login."
                mode = .signIn
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private enum LoginMode {
    case signIn
    case signUp
}

#Preview {
    LoginView()
        .environmentObject(AppSession())
}
