import SwiftUI
import UIKit

// MARK: - HistoryDrawer

/// Left-edge slide-in drawer showing the Recent Recipes list.
///
/// Opened by:
///   - Dragging right from a 20pt transparent zone pinned to the left edge.
///   - `store.showRecentRecipes = true` (e.g. nav bar History button)
///
/// Dismissed by:
///   - Swiping left anywhere on the drawer panel (UIPanGestureRecognizer on the window,
///     angle-gated to horizontal-leftward so vertical scrolling is unaffected)
///   - Tapping the exposed canvas strip (~20% on the right)
///   - The DONE button inside the drawer content
///
/// `canvasOffset` is written inside every `withAnimation` block that moves `progress`, so
/// the canvas and drawer always animate together. Direct (non-animated) sets during a live
/// drag also update canvasOffset immediately.
struct HistoryDrawer: View {
    @ObservedObject var store: AppStore
    @Binding var isCanvasEnabled: Bool
    @Binding var canvasOffset: CGFloat
    var onNewRecipe: () -> Void = {}
    var onSettings: () -> Void = {}

    @State private var progress: CGFloat = 0
    @State private var gestureActive = false
    /// Cached from GeometryReader so snap() can compute the target canvasOffset.
    @State private var drawerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let dw = geo.size.width * 0.80
            ZStack(alignment: .leading) {
                if gestureActive || progress > 0.001 {
                    // Tap zone covering only the exposed right strip — dismisses drawer.
                    // z-order below the drawer panel so panel rows handle their own taps.
                    // .transition(.identity) suppresses the default fade when this view
                    // is removed as progress crosses 0 during the close animation.
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { snap(open: false) }
                        .padding(.leading, dw * progress)
                        .transition(.identity)

                    VStack(spacing: 0) {
                        // MARK: Header
                        ZStack(alignment: .center) {
                            Text("SOUS")
                                .font(.sousLogotype)
                                .foregroundStyle(Color.sousText)
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 0) {
                                Spacer()
                                Button {
                                    onSettings()
                                    snap(open: false)
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color(red: 26/255, green: 26/255, blue: 26/255))
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 16)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                        .background(Color.sousBackground)

                        SousRule()

                        // MARK: Body
                        RecentRecipesView(store: store, onDismiss: { snap(open: false) })

                        // MARK: Footer
                        SousRule()
                        Button {
                            snap(open: false) { onNewRecipe() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.square.fill")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.white)
                                Text("NEW RECIPE")
                                    .font(.sousButton)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.sousTerracotta)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.sousBackground.ignoresSafeArea(edges: .bottom))
                    }
                    .frame(width: dw)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color.sousBackground.ignoresSafeArea(edges: .top))
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.2), location: 0.0),
                                .init(color: .black.opacity(0.08), location: 0.4),
                                .init(color: .black.opacity(0.02), location: 0.7),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                        .frame(width: 32)
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea(edges: [.top, .bottom])
                        .allowsHitTesting(false)
                        .opacity(Double(progress))
                    }
                    .offset(x: dw * (progress - 1))
                    .transition(.identity)
                    .background(
                        DrawerDismissInstaller(
                            isActive: progress > 0.001,
                            onChanged: { tx in
                                guard tx < 0 else { return }
                                gestureActive = true
                                let p = min(1, max(0, 1.0 + tx / dw))
                                // Direct (no animation) — mirrors the live finger position.
                                progress = p
                                canvasOffset = p * dw
                            },
                            onEnded: { tx, vx in
                                gestureActive = false
                                if tx < -60 || vx < -300 {
                                    snap(open: false)
                                } else {
                                    snap(open: true)
                                }
                            }
                        )
                    )
                }

                // 20pt left-edge hit zone. Always present and above the canvas.
                Color.clear
                    .frame(width: 20)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                guard value.translation.width > 0 else { return }
                                if !gestureActive { isCanvasEnabled = false }
                                gestureActive = true
                                let p = min(1, max(0, value.translation.width / dw))
                                // Direct (no animation) — follows the finger in real time.
                                progress = p
                                canvasOffset = p * dw
                            }
                            .onEnded { value in
                                gestureActive = false
                                let p = min(1, max(0, value.translation.width / dw))
                                snap(open: p > 0.4 || value.velocity.width > 300)
                            }
                    )
            }
            .onAppear { drawerWidth = dw }
            .onChange(of: geo.size.width) { _, w in drawerWidth = w * 0.80 }
            .onChange(of: store.showRecentRecipes) { _, newValue in
                guard !gestureActive else { return }
                let target: CGFloat = newValue ? 1 : 0
                guard abs(progress - target) > 0.01 else { return }
                if newValue { isCanvasEnabled = false }
                withAnimation(
                    .spring(response: 0.35, dampingFraction: 0.85),
                    completionCriteria: .logicallyComplete
                ) {
                    progress = target
                    canvasOffset = target * drawerWidth
                } completion: {
                    if !newValue { isCanvasEnabled = true }
                }
            }
        }
    }

    private func snap(open: Bool, completion: (() -> Void)? = nil) {
        if open { isCanvasEnabled = false }
        withAnimation(
            .spring(response: 0.35, dampingFraction: 0.85),
            completionCriteria: .logicallyComplete
        ) {
            progress = open ? 1 : 0
            // Animated together so canvas and drawer always move in lockstep.
            canvasOffset = open ? drawerWidth : 0
        } completion: {
            if !open {
                isCanvasEnabled = true
                canvasOffset = 0
            }
            if store.showRecentRecipes != open { store.showRecentRecipes = open }
            completion?()
        }
    }
}

// MARK: - DrawerDismissInstaller

/// Installs a `UIPanGestureRecognizer` on the key UIWindow so it fires before UIKit's
/// scroll-view pan recognizer. Angle gating in `shouldBegin` ensures only
/// horizontal-leftward swipes are claimed; vertical scrolls pass through unaffected.
/// `cancelsTouchesInView = true` prevents the swipe from also registering as a row tap.
struct DrawerDismissInstaller: UIViewRepresentable {
    var isActive: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> DrawerDismissInstallerView {
        let view = DrawerDismissInstallerView()
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = true
        view.panGesture = pan
        return view
    }

    func updateUIView(_ uiView: DrawerDismissInstallerView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive: Bool = false
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void

        init(onChanged: @escaping (CGFloat) -> Void,
             onEnded: @escaping (CGFloat, CGFloat) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ gr: UIPanGestureRecognizer) {
            let t = gr.translation(in: gr.view).x
            let v = gr.velocity(in: gr.view).x
            switch gr.state {
            case .changed: onChanged(t)
            case .ended, .cancelled: onEnded(t, v)
            default: break
            }
        }

        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard isActive, let pan = gr as? UIPanGestureRecognizer else { return false }
            let vel = pan.velocity(in: gr.view)
            return vel.x < 0 && abs(vel.x) > abs(vel.y) * 1.5
        }

        func gestureRecognizer(
            _ gr: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}

// MARK: - DrawerDismissInstallerView

final class DrawerDismissInstallerView: UIView {
    var panGesture: UIPanGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let pan = panGesture else { return }
        pan.view?.removeGestureRecognizer(pan)
        window?.addGestureRecognizer(pan)
    }
}

