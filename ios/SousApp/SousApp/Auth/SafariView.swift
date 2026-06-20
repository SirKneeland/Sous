import SwiftUI
import SafariServices

/// Thin `UIViewControllerRepresentable` wrapping `SFSafariViewController` for in-app
/// web browsing. Present as a `.sheet` — the built-in Done button handles dismissal.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
