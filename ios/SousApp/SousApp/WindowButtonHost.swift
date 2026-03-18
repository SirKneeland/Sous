import Combine
import SwiftUI
import UIKit

// MARK: - Shared Model

/// Drives the window-level "Talk to Sous" bar from SwiftUI state.
@MainActor
final class TalkToSousWindowModel: ObservableObject {
    @Published var isVisible: Bool = false
    var onOpenChat: () -> Void = {}
}

// MARK: - UIViewRepresentable Anchor

/// Zero-size invisible anchor that installs the button bar into the key UIWindow.
/// Nothing at the UIWindow level can be clipped by any SwiftUI container.
struct TalkToSousWindowHost: UIViewRepresentable {
    @ObservedObject var model: TalkToSousWindowModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> UIView {
        let anchor = UIView()
        anchor.isHidden = true
        // Defer so this doesn't run during SwiftUI's layout pass
        Task { @MainActor in
            context.coordinator.install()
        }
        return anchor
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let hidden = !model.isVisible
        context.coordinator.hostingController?.view.isHidden = hidden
        context.coordinator.backgroundView?.isHidden = hidden
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.remove()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject {
        let model: TalkToSousWindowModel
        var hostingController: UIHostingController<TalkToSousBar>?
        var backgroundView: UIView?

        init(model: TalkToSousWindowModel) { self.model = model }

        func install() {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })
            else { return }

            // Solid background view — covers from the button bar's top all the way to the
            // physical bottom of the window, including the safe area. Inserted below the
            // hosting controller so it never obscures the button or chevron.
            let bg = UIView()
            bg.backgroundColor = UIColor(Color.sousBackground)
            bg.translatesAutoresizingMaskIntoConstraints = false
            bg.isHidden = !model.isVisible

            let hc = UIHostingController(rootView: TalkToSousBar(model: model))
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            hc.view.isHidden = !model.isVisible

            window.addSubview(bg)
            window.addSubview(hc.view) // added after bg so it renders on top
            NSLayoutConstraint.activate([
                hc.view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                hc.view.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor),

                bg.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                bg.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                bg.topAnchor.constraint(equalTo: hc.view.topAnchor),
                bg.bottomAnchor.constraint(equalTo: window.bottomAnchor), // extends to physical bottom
            ])

            backgroundView = bg
            hostingController = hc
        }

        func remove() {
            backgroundView?.removeFromSuperview()
            backgroundView = nil
            hostingController?.view.removeFromSuperview()
            hostingController = nil
        }
    }
}

// MARK: - Bar View

struct TalkToSousBar: View {
    @ObservedObject var model: TalkToSousWindowModel
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            SousRule()
            Button {
                model.onOpenChat()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message")
                        .font(.system(size: 14, weight: .semibold))
                    Text("TALK TO SOUS")
                        .font(.sousButton)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.sousTerracotta)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.sousBackground)
            .offset(y: dragOffset)
            .zIndex(1) // keep button above the chevron strip during translation
            // Swipe-down affordance hint
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.sousMuted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .background(Color.sousBackground)
                .allowsHitTesting(false)
        }
        .background(Color.sousBackground.ignoresSafeArea(edges: .bottom)) // extends into safe area to prevent bleed-through
        .simultaneousGesture(openChatGesture)
    }

    private var openChatGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let raw = value.translation.height
                guard raw > 0 else { return }
                dragOffset = min(raw * 0.65, 60)
            }
            .onEnded { value in
                if value.translation.height >= 20 {
                    dragOffset = 0
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    model.onOpenChat()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
