import SwiftUI
import SousCore

struct RecentRecipesView: View {
    @ObservedObject var store: AppStore
    var onDismiss: () -> Void

    @State private var sessions: [SessionSnapshot] = []
    @State private var showDeleteActiveAlert = false

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

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    Spacer()
                    Text("NO RECENT RECIPES")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .kerning(1.0)
                    Spacer()
                } else {
                    List {
                        ForEach(sessions, id: \.recipe.id) { snapshot in
                            Button {
                                store.requestResumeSession(snapshot)
                                onDismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(snapshot.recipe.title)
                                        .font(.sousBody)
                                        .foregroundStyle(Color.sousText)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { onDismiss() }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousText)
                }
            }
            .background(Color.sousBackground.ignoresSafeArea())
        }
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
        }
    }
}
