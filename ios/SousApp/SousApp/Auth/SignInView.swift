import SwiftUI
import AuthenticationServices

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// Full-screen sign-in shown whenever `authState.status == .signedOut`. Presents
/// the Sous wordmark, a short value proposition, and the native Sign in with
/// Apple button.
struct SignInView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeURL: IdentifiableURL?
#if DEBUG
    @State private var debugHandle: String = DebugSignIn.lastHandle
#endif

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

#if DEBUG
                debugBypass
#endif

                HStack(spacing: 0) {
                    Text("By continuing, you agree to our ")
                    Button { activeURL = IdentifiableURL(url: SousSupport.termsOfServiceURL) } label: {
                        Text("Terms of Service").underline()
                    }
                    Text(" and ")
                    Button { activeURL = IdentifiableURL(url: SousSupport.privacyPolicyURL) } label: {
                        Text("Privacy Policy").underline()
                    }
                    Text(".")
                }
                .font(.sousCaption)
                .foregroundStyle(Color.sousMuted)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $activeURL) { item in
            SafariView(url: item.url)
        }
    }

#if DEBUG
    /// Debug-only bypass. Signs in through the real `AuthState.signIn` using the
    /// handle as the Apple `sub`, which the backend accepts when its dev bypass
    /// is enabled. Never compiled into Release.
    private var debugBypass: some View {
        VStack(spacing: 8) {
            TextField("debug handle", text: $debugHandle)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.sousCaption)

            Button {
                signInAsDebugUser(handle: debugHandle)
            } label: {
                Text("Skip sign-in (Debug)")
                    .font(.sousCaption)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func signInAsDebugUser(handle: String) {
        DebugSignIn.lastHandle = handle
        let resolved = DebugSignIn.lastHandle
        debugHandle = resolved
        Task {
            await authState.signIn(
                identityToken: resolved,
                fullName: DebugSignIn.displayName(for: resolved)
            )
        }
    }
#endif

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
