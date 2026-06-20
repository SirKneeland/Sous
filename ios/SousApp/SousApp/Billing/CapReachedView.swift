import SwiftUI

// MARK: - CapReachedView
//
// The "hard stop" shown to a PAID subscriber who has hit the monthly recipe cap
// (default 100). This is NOT the paywall — the user already pays. It is the
// "whale UX": a warm, humanizing note from John with a direct line to support,
// shown in place of the new-recipe / import flow. Trial users who hit their trial
// cap see the paywall instead, never this screen.

struct CapReachedView: View {
    let recipesUsed: Int
    let recipeCap: Int
    let resetsInDays: Int
    /// User's email (from Apple Sign-In) and account id, pre-filled into the email.
    let userEmail: String?
    let accountId: String?

    var onClose: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    private static let johnMessage =
        "Hi, I'm John — I made Sous. I didn't think anyone would cook quite this much! " +
        "Drop me a line and I'll take a look at your account to see what we can do to " +
        "hold you over until next month."

    private var resetString: String {
        resetsInDays <= 0 ? "Resets today" : "Resets in \(resetsInDays) day\(resetsInDays == 1 ? "" : "s")"
    }

    private var shareText: String {
        "I've been cooking with Sous — give it a try."
    }

    var body: some View {
        ZStack {
            Color.sousBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if onClose != nil {
                    HStack {
                        Spacer()
                        SousIconButton(systemName: "xmark") { onClose?() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                Spacer(minLength: 16)

                SousSectionLabel(title: "Monthly limit reached")
                    .padding(.horizontal, 28)

                Text("\(recipesUsed) of \(recipeCap) recipes used")
                    .font(.sousTitle)
                    .foregroundStyle(Color.sousText)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(resetString.uppercased())
                    .font(.sousCaption)
                    .kerning(1)
                    .foregroundStyle(Color.sousMuted)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SousRule()
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)

                Text(Self.johnMessage)
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                Spacer(minLength: 24)

                // Primary: Message John — opens a pre-filled mail composer.
                Button {
                    if let url = mailtoURL() { openURL(url) }
                } label: {
                    Text("MESSAGE JOHN")
                        .font(.sousButton)
                        .kerning(0.5)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Rectangle().fill(Color.sousTerracotta))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                // Secondary: share Sous with a friend.
                ShareLink(item: shareText) {
                    Text("SHARE SOUS WITH A FRIEND")
                        .font(.sousButton)
                        .kerning(0.5)
                        .foregroundStyle(Color.sousText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }

    /// Build the pre-filled support email. Body carries the user's email + account
    /// id so John can look up the account.
    func mailtoURL() -> URL? {
        let subject = "Sous — Recipe cap reached"
        var bodyLines = ["", "—", "Sent from Sous"]
        if let accountId { bodyLines.insert("Account ID: \(accountId)", at: 0) }
        if let userEmail { bodyLines.insert("Account email: \(userEmail)", at: 0) }
        let body = bodyLines.joined(separator: "\n")

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = SousSupport.email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
