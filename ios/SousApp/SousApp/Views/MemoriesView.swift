import SwiftUI

/// Shows all saved memories and lets the user edit or delete them.
struct MemoriesView: View {
    @ObservedObject var store: AppStore
    @State private var editingMemory: MemoryItem? = nil
    @State private var editText: String = ""

    var body: some View {
        Group {
            if store.memories.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("NO MEMORIES SAVED YET")
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .kerning(1.0)
                    Text("Sous will propose memories as you chat.")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(store.memories) { item in
                            Button {
                                editingMemory = item
                                editText = item.text
                                Task {
                                    let converted = await MemoryPersonConverter.toFirstPerson(text: item.text)
                                    editText = converted
                                }
                            } label: {
                                Text(item.text)
                                    .font(.sousBody)
                                    .foregroundStyle(Color.sousText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.sousBackground)
                            .listRowSeparatorTint(Color.sousSeparator)
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.deleteMemory(store.memories[idx])
                            }
                        }
                    } footer: {
                        Text("TAP TO EDIT  ·  SWIPE LEFT TO DELETE")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousMuted)
                            .kerning(0.5)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.sousBackground)
            }
        }
        .background(Color.sousBackground)
        .navigationTitle("MEMORIES")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingMemory) { item in
            NavigationView {
                Form {
                    Section {
                        TextEditor(text: $editText)
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 60)
                            .autocorrectionDisabled()
                    } header: {
                        Text("MEMORY TEXT")
                            .font(.sousSectionHeader)
                            .foregroundStyle(Color.sousTerracotta)
                            .kerning(1.2)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.sousBackground)
                    .listRowSeparatorTint(Color.sousSeparator)
                }
                .scrollContentBackground(.hidden)
                .background(Color.sousBackground)
                .navigationTitle("EDIT MEMORY")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("CANCEL") { editingMemory = nil }
                            .font(.sousButton)
                            .foregroundStyle(Color.sousText)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("SAVE") {
                            let snapshot = editText
                            editingMemory = nil
                            Task {
                                let converted = await MemoryPersonConverter.toSecondPerson(text: snapshot)
                                let trimmed = converted.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    var updated = item
                                    updated.text = trimmed
                                    store.updateMemory(updated)
                                }
                            }
                        }
                        .font(.sousButton)
                        .foregroundStyle(Color.sousText)
                    }
                }
            }
        }
    }
}
