import SwiftUI
import SousCore

struct RecentRecipesView: View {
    @ObservedObject var store: AppStore
    var onDismiss: () -> Void

    @State private var sessions: [SessionSnapshot] = []

    private func relativeTimestamp(_ date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        if elapsed < 60 { return "1 min ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No recent recipes")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sessions, id: \.recipe.id) { snapshot in
                            Button {
                                store.requestResumeSession(snapshot)
                                onDismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(snapshot.recipe.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(relativeTimestamp(snapshot.savedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indices in
                            for i in indices {
                                store.deleteRecentSession(sessions[i])
                            }
                            sessions.remove(atOffsets: indices)
                        }
                    }
                }
            }
            .navigationTitle("Recent Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDismiss() }
                }
            }
        }
        .onAppear {
            sessions = store.loadRecentSessions()
        }
    }
}
