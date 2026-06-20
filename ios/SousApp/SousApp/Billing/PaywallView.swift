import SwiftUI

// MARK: - Support / legal constants
//
// Centralized so they have a single source of truth. The legal URLs are
// placeholders the operator must replace before public launch.
enum SousSupport {
    /// Support address for the "Message John" hard-stop flow.
    /// TODO(operator): confirm the real support address before TestFlight.
    static let email = "john.kneeland@gmail.com"
    /// TODO(operator): replace with the real Privacy Policy URL before launch.
    static let privacyPolicyURL = URL(string: "https://donutindustries.com/sous/privacy")!
    /// TODO(operator): replace with the real Terms of Service URL before launch.
    static let termsOfServiceURL = URL(string: "https://donutindustries.com/sous/terms")!
}

// MARK: - PaywallView
//
// Full-screen subscription wall. Shown when a soft-wall (expired-trial) user
// attempts a generative action, taps a disabled feature, or taps "Upgrade" in
// Settings. Per DesignSpec: cream background, burgundy CTA, monospace-leaning
// Sous type, no bubbly chrome. No dismiss control unless presented from Settings
// (showsCloseButton), per the kickoff — otherwise the user subscribes or backs out.

struct PaywallView: View {
    @ObservedObject var storeKit: StoreKitManager

    /// Display price shown when StoreKit hasn't loaded the product yet (offline /
    /// sandbox not configured). StoreKit's `displayPrice` is authoritative when present.
    var priceFallback: String = "$4.99"
    /// Settings entry point shows a close control; trial-end / disabled-feature
    /// entry points do not.
    var showsCloseButton: Bool = false
    var onClose: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    private var priceString: String {
        storeKit.displayPrice ?? priceFallback
    }

    private var ctaLabel: String {
        "START SOUS PRO — \(priceString)/MONTH"
    }

    private let benefits: [String] = [
        "Unlimited cooking conversations with Sous",
        "Up to 100 new recipes every month",
        "Hands-free voice mode while you cook",
        "Your recipes, memories & preferences synced",
    ]

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if showsCloseButton {
                    HStack {
                        Spacer()
                        SousIconButton(systemName: "xmark") { onClose?() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                Spacer(minLength: 24)

                Text("SOUS")
                    .font(.sousLogotype)
                    .kerning(3)
                    .foregroundStyle(Color.sousText)

                Text("PRO")
                    .font(.sousSectionHeader)
                    .kerning(3)
                    .foregroundStyle(Color.sousTerracotta)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.sousTerracotta)
                                .padding(.top, 2)
                            Text(benefit)
                                .font(.sousBody)
                                .foregroundStyle(Color.sousText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)

                Spacer(minLength: 24)

                if case .failed(let message) = storeKit.purchaseState {
                    Text(message.uppercased())
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousTerracotta)
                        .padding(.bottom, 8)
                }

                // Primary CTA — filled burgundy rectangle.
                Button {
                    Task { await storeKit.purchase() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(ctaLabel)
                                .font(.sousButton)
                                .kerning(0.5)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Rectangle().fill(Color.sousTerracotta))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .padding(.horizontal, 20)

                Button {
                    Task { await storeKit.restore() }
                } label: {
                    Text("RESTORE PURCHASES")
                        .font(.sousCaption)
                        .kerning(1)
                        .foregroundStyle(Color.sousText)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .padding(.top, 16)

                HStack(spacing: 16) {
                    Button("Privacy Policy") { openURL(SousSupport.privacyPolicyURL) }
                    Text("·").foregroundStyle(Color.sousMuted)
                    Button("Terms of Service") { openURL(SousSupport.termsOfServiceURL) }
                }
                .font(.sousCaption)
                .foregroundStyle(Color.sousMuted)
                .buttonStyle(.plain)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .task { await storeKit.loadProduct() }
    }

    private var isWorking: Bool {
        switch storeKit.purchaseState {
        case .purchasing, .validating: return true
        default: return false
        }
    }
}
