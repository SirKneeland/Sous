import SwiftUI
import SousCore

struct RecentRecipesView: View {
    @ObservedObject var store: AppStore
    var onDismiss: () -> Void

    @State private var sessions: [SessionSnapshot] = []

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
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(sessions.enumerated()), id: \.element.recipe.id) { index, snapshot in
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteRecentSession(snapshot)
                                        sessions.remove(at: index)
                                    } label: {
                                        Text("DELETE")
                                            .font(.sousCaption)
                                    }
                                }

                                if index < sessions.count - 1 {
                                    SousRule()
                                }
                            }
                        }
                        .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
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
        .onAppear {
            sessions = store.loadRecentSessions()
        }
    }
}
