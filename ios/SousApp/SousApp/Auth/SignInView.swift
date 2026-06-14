import SwiftUI
import AuthenticationServices

/// Full-screen sign-in shown whenever `authState.status == .signedOut`. Presents
/// the Sous wordmark, a short value proposition, and the native Sign in with
/// Apple button.
struct SignInView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("SOUS")
                    .font(.sousLogotype)
                    .kerning(2)
                    .foregroundStyle(Color.sousText)

                Text("Your AI sous-chef. Cook with a living recipe that adapts as you go.")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                if let error = authState.signInError {
                    Text(error)
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousTerracotta)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleCompletion(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Text("By continuing you agree to use Sous responsibly.")
                    .font(.sousCaption)
                    .foregroundStyle(Color.sousMuted)
                    .padding(.bottom, 32)
            }
        }
    }

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            // Includes user cancellation; keep it gentle.
            authState.signInError = "Sign in was canceled. Tap to try again."
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                authState.signInError = "Could not read your Apple credentials. Please try again."
                return
            }
            let fullName = credential.fullName.flatMap(formattedName)
            Task { await authState.signIn(identityToken: token, fullName: fullName) }
        }
    }

    private func formattedName(_ components: PersonNameComponents) -> String? {
        let formatter = PersonNameComponentsFormatter()
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }
}
