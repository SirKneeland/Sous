import SwiftUI

// MARK: - DrawerContent

/// The recipe-navigation panel: the SOUS wordmark with the Settings gear beside it,
/// the Recent Recipes list, and NEW RECIPE pinned to the bottom.
///
/// Lifted out of `HistoryDrawer` unchanged when the window shade arrived, because
/// both surfaces show exactly this. The drawer slides it in from the left edge; the
/// shade drops it from the top. Nothing in here knows which.
///
/// The two parameters that differ are both about where the panel's edges are:
/// the drawer's panel already sits below the status bar, where the shade's covers
/// it, and the drawer's footer runs to the bottom of the screen, where the shade's
/// has a grab bar underneath it.
struct DrawerContent: View {
    @ObservedObject var store: AppStore
    /// True while the containing surface is on screen. The recents list reloads on
    /// every rising edge, so a recipe generated since the last open shows up.
    var isPresented: Bool
    /// Space above the wordmark. The shade adds the status bar height to it.
    var topPadding: CGFloat = 16
    /// Whether the footer's background runs under the home indicator. False in the
    /// shade, where the grab bar owns the bottom edge.
    var footerExtendsToSafeArea: Bool = true
    var onSettings: () -> Void
    var onNewRecipe: () -> Void
    /// Dismiss the containing surface — what choosing a recipe does.
    var onDismiss: () -> Void

    @State private var newRecipePressed = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            ZStack(alignment: .center) {
                Text("SOUS")
                    .font(.sousLogotype)
                    .kerning(SousType.wordmarkTracking)
                    .foregroundStyle(Color.sousText)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 0) {
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.sousIcon(.large, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.sousSurfaceInverse)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .padding(.trailing, 16)
                }
            }
            .padding(.top, topPadding)
            .padding(.bottom, 16)
            .background(Color.sousBackground)

            SousRule()

            // MARK: Body
            RecentRecipesView(store: store, isPresented: isPresented, onDismiss: onDismiss)

            // MARK: Footer
            SousRule()
            Button(action: onNewRecipe) {
                SousButtonLabel(title: "NEW RECIPE", style: .primary,
                                icon: "plus.square.fill",
                                isPressed: newRecipePressed)
            }
            .buttonStyle(PressReportingStyle(isPressed: $newRecipePressed))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                footerExtendsToSafeArea
                    ? AnyView(Color.sousBackground.ignoresSafeArea(edges: .bottom))
                    : AnyView(Color.sousBackground)
            )
        }
    }
}
