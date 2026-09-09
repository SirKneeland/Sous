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
        guard let handle = DebugSignIn.launchHandle() else { return }
        guard authState.status == .signedOut else { return }
        await authState.signIn(
            identityToken: handle,
            fullName: DebugSignIn.displayName(for: handle)
        )
    }
#endif

    private func configureNavigationBar() {
        let creamColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
                : UIColor(red: 242/255, green: 239/255, blue: 233/255, alpha: 1)
        }
        let textColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 242/255, green: 239/255, blue: 233/255, alpha: 1)
                : UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
        }
        let separatorColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 58/255, green: 53/255, blue: 48/255, alpha: 1)
                : UIColor(red: 208/255, green: 203/255, blue: 195/255, alpha: 1)
        }

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
