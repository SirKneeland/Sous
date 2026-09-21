#if DEBUG
import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - DebugReportSubmitting

/// The slice of the backend this sheet needs. Declared separately so tests can
/// substitute a double without building a whole `SousBackend`.
@MainActor
protocol DebugReportSubmitting: AnyObject {
    func submitBugReport(_ report: BugReportSubmission) async throws -> BugReportReceipt
}

extension SousAPIClient: DebugReportSubmitting {}

// MARK: - DebugReportSheetModel

/// Drives the "Report a problem" sheet: validates what the user typed, builds the
/// submission, and tracks the send.
///
/// The diagnostic is captured once, when the sheet opens — not when Send is tapped.
/// Otherwise anything the user does while typing (a timer firing, a step completing)
/// would edit the state under inspection before it is recorded.
@MainActor
final class DebugReportSheetModel: ObservableObject {

    enum SendState: Equatable {
        case editing
        case sending
        /// Landed in the backlog. `seq` is the short number, e.g. 17 → "BUG-17".
        case sent(seq: Int, alreadySubmitted: Bool)
        case failed(String)
    }

    @Published var description: String = ""
    @Published var expectedBehavior: String = ""
    @Published private(set) var sendState: SendState = .editing

    /// Captured at init — see the note above.
    let diagnostic: String
    private let metadata: DebugReportMetadata
    private let backend: any DebugReportSubmitting

    /// Stable for the life of the sheet, so a retry after a failure is recognised
    /// as the same report rather than filed a second time.
    private let clientReportId = UUID().uuidString

    init(
        diagnostic: String,
        metadata: DebugReportMetadata,
        backend: any DebugReportSubmitting
    ) {
        self.diagnostic = diagnostic
        self.metadata = metadata
        self.backend = backend
    }

    /// A report needs a description; everything else is optional.
    var canSend: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sendState != .sending
    }

    var isSending: Bool { sendState == .sending }

    func submission() -> BugReportSubmission {
        let trimmedExpected = expectedBehavior.trimmingCharacters(in: .whitespacesAndNewlines)
        return BugReportSubmission(
            clientReportId: clientReportId,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedBehavior: trimmedExpected.isEmpty ? nil : trimmedExpected,
            diagnostic: diagnostic,
            appVersion: metadata.appVersion,
            buildNumber: metadata.buildNumber,
            iosVersion: metadata.iosVersion,
            deviceModel: metadata.deviceModel,
            appState: metadata.appState
        )
    }

    func send() async {
        guard canSend else { return }
        sendState = .sending
        do {
            let receipt = try await backend.submitBugReport(submission())
            sendState = .sent(seq: receipt.seq, alreadySubmitted: receipt.alreadySubmitted)
        } catch {
            sendState = .failed(Self.message(for: error))
        }
    }

    /// Plain-English failure text. A bug report is worth nothing if the person
    /// filing it cannot tell "try again" from "share the file instead".
    static func message(for error: Error) -> String {
        switch error {
        case SousAPIError.notAuthenticated:
            return "You're signed out, so this can't be filed. Sign in, or use Share file instead."
        case SousAPIError.unauthorized:
            return "Your session expired. Sign in again, or use Share file instead."
        case SousAPIError.http(let status) where status == 413:
            return "This diagnostic is too large to send. Use Share file instead."
        case SousAPIError.http(let status) where status == 429:
            return "Too many reports sent in the last hour. Try again later, or use Share file."
        case SousAPIError.http(let status):
            return "The server rejected it (error \(status)). Try again, or use Share file."
        default:
            return "Couldn't reach the server. Try again, or use Share file instead."
        }
    }
}

// MARK: - DebugReportMetadata

/// Device and build facts sent alongside the diagnostic so reports can be filtered
/// by build without parsing the markdown.
struct DebugReportMetadata: Equatable, Sendable {
    let appVersion: String?
    let buildNumber: String?
    let iosVersion: String?
    let deviceModel: String?
    let appState: String?

    static func current(appState: String) -> DebugReportMetadata {
        let info = Bundle.main.infoDictionary
        return DebugReportMetadata(
            appVersion: info?["CFBundleShortVersionString"] as? String,
            buildNumber: info?["CFBundleVersion"] as? String,
            iosVersion: UIDevice.current.systemVersion,
            deviceModel: hardwareIdentifier(),
            appState: appState
        )
    }

    /// The hardware string, e.g. "iPhone16,1". `UIDevice.model` only ever says
    /// "iPhone", which cannot distinguish a device-specific layout bug.
    static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}

// MARK: - DebugReportSheet

/// Debug-only "Report a problem" sheet. Replaces the straight-to-share-sheet
/// behaviour of the 5-tap gesture: the report can now go to the triage backlog,
/// with sharing the file kept as a fallback (and for when the network is down).
struct DebugReportSheet: View {
    @ObservedObject var model: DebugReportSheetModel
    /// Hands the diagnostic to the iOS share sheet — the original 5-tap behaviour.
    let onShareFile: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                switch model.sendState {
                case .sent(let seq, let alreadySubmitted):
                    sentSection(seq: seq, alreadySubmitted: alreadySubmitted)
                default:
                    editingSections
                }
            }
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isFinished ? "Done" : "Cancel", action: onDismiss)
                }
            }
            .interactiveDismissDisabled(model.isSending)
        }
    }

    private var isFinished: Bool {
        if case .sent = model.sendState { return true }
        return false
    }

    // MARK: Editing

    @ViewBuilder
    private var editingSections: some View {
        Section {
            TextField(
                "What went wrong?",
                text: $model.description,
                axis: .vertical
            )
            .lineLimit(3...8)
            .disabled(model.isSending)
        } header: {
            Text("What happened")
        } footer: {
            Text("Required. What you did, and what the app did instead.")
        }

        Section {
            TextField(
                "What should it have done?",
                text: $model.expectedBehavior,
                axis: .vertical
            )
            .lineLimit(2...6)
            .disabled(model.isSending)
        } header: {
            Text("Expected")
        } footer: {
            Text("Optional.")
        }

        if case .failed(let message) = model.sendState {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }

        Section {
            Button {
                Task { await model.send() }
            } label: {
                HStack {
                    if model.isSending {
                        ProgressView().controlSize(.small)
                        Text("Sending…")
                    } else {
                        Text(isRetry ? "Try Again" : "Send to Backlog")
                    }
                    Spacer()
                }
            }
            .disabled(!model.canSend)

            Button("Share File…", action: onShareFile)
                .disabled(model.isSending)
        } footer: {
            Text(
                "Attaches the full diagnostic: recipe state, chat transcript, prompts, "
                + "preferences, memories, and the last import attempt."
            )
        }
    }

    private var isRetry: Bool {
        if case .failed = model.sendState { return true }
        return false
    }

    // MARK: Sent

    @ViewBuilder
    private func sentSection(seq: Int, alreadySubmitted: Bool) -> some View {
        Section {
            Label("Filed as BUG-\(seq)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            if alreadySubmitted {
                Text("This report was already in the backlog — it wasn't filed twice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Run `./scripts/bugs.sh show \(seq)` from backend/ to read it.")
        }
    }
}
#endif
