import SwiftUI

/// Shows all saved memories and lets the user edit or delete them.
struct MemoriesView: View {
    @ObservedObject var store: AppStore
    @State private var editingMemory: MemoryItem? = nil
    @State private var editText: String = ""

    var body: some View {
        Group {
            if store.memories.isEmpty {
                Text("No memories saved yet.\nSous will propose memories as you chat.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(footer: Text("Tap to edit · Swipe left to delete")
                        .font(.caption)
                        .foregroundStyle(.secondary)) {
                        ForEach(store.memories) { item in
                            Button {
                                editingMemory = item
                                editText = item.text
                            } label: {
                                Text(item.text)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.deleteMemory(store.memories[idx])
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingMemory) { item in
            NavigationView {
                Form {
                    Section {
                        TextEditor(text: $editText)
                            .frame(minHeight: 60)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Memory text")
                    }
                }
                .navigationTitle("Edit Memory")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingMemory = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            var updated = item
                            updated.text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !updated.text.isEmpty {
                                store.updateMemory(updated)
                            }
                            editingMemory = nil
                        }
                    }
                }
            }
        }
    }
}
