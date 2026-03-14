import SwiftUI
import UIKit

@main
struct SousAppApp: App {
    init() {
        configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

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

        let monoFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = creamColor
        appearance.shadowColor = separatorColor
        appearance.titleTextAttributes = [
            .font: monoFont,
            .foregroundColor: textColor
        ]

        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
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
