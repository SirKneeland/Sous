import SwiftUI
import SousCore

struct RecentRecipesView: View {
    @ObservedObject var store: AppStore
    var onDismiss: () -> Void

    @State private var sessions: [SessionSnapshot] = []
    @State private var showDeleteActiveAlert = false

    /// IDs of pre-canvas sessions whose summary is currently being generated.
    @State private var shimmering: Set<UUID> = []
    /// Resolved summaries keyed by recipe ID (populated from cache or after generation).
    @State private var localSummaries: [UUID: String] = [:]

    private func formatAge(_ date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        if elapsed < 60 { return "NOW" }
        let minutes = elapsed / 60
        if minutes < 60 { return "\(minutes) MIN" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) HR" }
        let days = hours / 24
        if days < 7 { return "\(days) DAY" }
        let weeks = days / 7
        return "\(weeks) WK"
    }

    // MARK: - Summary generation

    private func loadSummaries(for loadedSessions: [SessionSnapshot]) {
        for snapshot in loadedSessions where !snapshot.hasCanvas {
            let id = snapshot.recipe.id
            let messageCount = snapshot.chatMessages.filter {
                $0.role == .user || $0.role == .assistant
            }.count

            // No messages yet — skip generation; leave localSummaries[id] unset (fallback shown).
            guard messageCount > 0 else { continue }

            // Cache hit with matching count — populate immediately, no shimmer.
            if let cached = store.sessionSummaryCache[id], cached.messageCount == messageCount {
                localSummaries[id] = cached.summary
                continue
            }

            // Cache miss or stale — kick off async generation with shimmer.
            shimmering.insert(id)
            let messages = snapshot.chatMessages
            Task { @MainActor in
                let result = await SessionSummarizer.summarize(messages: messages)
                let summary = result ?? "New Recipe"
                store.updateSessionSummary(recipeId: id, messageCount: messageCount, summary: summary)
                localSummaries[id] = summary
                shimmering.remove(id)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack {
                    Spacer()
                    Text("NO RECENT RECIPES")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .kerning(1.0)
                    Spacer()
                }
            } else {
                List {
                    ForEach(sessions, id: \.recipe.id) { snapshot in
                        Button {
                            store.requestResumeSession(snapshot)
                            onDismiss()
                        } label: {
                            HStack(spacing: 8) {
                                titleView(for: snapshot)
                                Text(formatAge(snapshot.savedAt))
                                    .font(.sousCaption)
                                    .foregroundStyle(Color.sousMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(Color.sousMuted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.sousBackground)
                        .listRowSeparatorTint(Color.sousSeparator)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .padding(.vertical, 14)
                        .contextMenu {
                            Button(role: .destructive) {
                                if snapshot.recipe.id == store.uiState.recipe.id {
                                    showDeleteActiveAlert = true
                                } else if let index = sessions.firstIndex(where: { $0.recipe.id == snapshot.recipe.id }) {
                                    store.deleteRecentSession(snapshot)
                                    sessions.remove(at: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.sousBackground)
        .alert("Delete Recipe?", isPresented: $showDeleteActiveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let deletedId = store.uiState.recipe.id
                store.deleteActiveSessionAndStartNew()
                sessions.removeAll { $0.recipe.id == deletedId }
            }
        } message: {
            Text("This will delete the recipe you are currently viewing.")
        }
        .onAppear {
            sessions = store.loadRecentSessions()
            loadSummaries(for: sessions)
        }
    }

    // MARK: - Title view

    @ViewBuilder
    private func titleView(for snapshot: SessionSnapshot) -> some View {
        if snapshot.hasCanvas {
            // Canvas sessions: show recipe title unchanged.
            Text(snapshot.recipe.title)
                .font(.sousBody)
                .foregroundStyle(Color.sousText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if shimmering.contains(snapshot.recipe.id) {
            // Summary generation in progress: shimmer placeholder.
            SummaryShimmer()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Pre-canvas: lightbulb.min + resolved summary (or static fallback).
            HStack(spacing: 5) {
                Image(systemName: "lightbulb.min")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.sousMuted)
                Text(localSummaries[snapshot.recipe.id] ?? "New Recipe")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - SummaryShimmer

private struct SummaryShimmer: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.sousMuted.opacity(0.22))
            .frame(height: 14)
            .overlay(
                GeometryReader { proxy in
                    let w = proxy.size.width
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.sousMuted.opacity(0.45), location: 0.4),
                            .init(color: Color.sousMuted.opacity(0.45), location: 0.6),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                    )
                    .frame(width: w)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            )
            .frame(maxWidth: 220)
            .onAppear {
                phase = -0.3
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}
