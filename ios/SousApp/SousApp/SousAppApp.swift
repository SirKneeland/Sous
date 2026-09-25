import SwiftUI
import UIKit

@main
struct SousAppApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var storeKit = StoreKitManager()

    init() {
        configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
                .environmentObject(storeKit)
                .task {
                    storeKit.attach(authState: authState)
                    await authState.bootstrap()
#if DEBUG
                    await autoSignInIfRequested()
#endif
                }
        }
    }

#if DEBUG
    /// Unattended debug sign-in for simulator automation and UI tests. Runs only
    /// when `SOUS_DEV_SIGNIN` (env) or `-sous-dev-signin <handle>` (launch
    /// argument) is present, and only if bootstrap left us signed out — an
    /// existing real session is never disturbed.
    private func autoSignInIfRequested() async {
        // A UI fixture signs in offline — no backend, no Keychain, no LLM spend.
        // Checked first so a fixture run never depends on the network.
        if DebugFixture.requested() != nil {
            guard authState.status == .signedOut else { return }
            authState.debugSignInOffline(entitlement: DebugFixture.entitlement())
            return
        }
        guard let handle = DebugSignIn.launchHandle() else { return }
        guard authState.status == .signedOut else { return }
        await authState.signIn(
            identityToken: handle,
            fullName: DebugSignIn.displayName(for: handle)
        )
    }
#endif

    private func configureNavigationBar() {
        let creamColor = UIColor.sousBackgroundUI
        let textColor = UIColor.sousTextUI
        let separatorColor = UIColor.sousSeparatorUI

        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = creamColor
        appearance.shadowColor = separatorColor
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: textColor
        ]

        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: textColor
        ]
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = textColor
    }
}
