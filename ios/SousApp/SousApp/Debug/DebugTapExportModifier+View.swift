import SwiftUI

// MARK: - View.debugTapExport

extension View {
    /// Attaches the 5-tap diagnostic export gesture. Compiles to a no-op in release builds,
    /// so call sites don't need their own `#if DEBUG` guards.
    @ViewBuilder
    func debugTapExport(store: AppStore) -> some View {
        #if DEBUG
        modifier(DebugTapExportModifier(store: store))
        #else
        self
        #endif
    }
}
