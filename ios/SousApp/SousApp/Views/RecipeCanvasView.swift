import SwiftUI
import SousCore
import UIKit

struct RecipeCanvasView: View {
    let recipe: Recipe
    let onOpenChat: () -> Void
    var onMarkStepDone: (UUID) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onStartNew: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var llmDebugStatus: String? = nil

    @State private var checkedIngredients: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title.uppercased())
                            .font(.sousTitle)
                            .foregroundStyle(Color.sousText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("REV. \(recipe.version)")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousMuted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        SousIconButton(systemName: "plus") { onStartNew() }
                        SousIconButton(systemName: "clock") { onOpenRecents() }
                        SousIconButton(systemName: "gearshape") { onOpenSettings() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                SousRule()

                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Ingredients
                    SousSectionLabel(title: "Ingredients")
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    ForEach(recipe.ingredients, id: \.id) { ingredient in
                        let isChecked = checkedIngredients.contains(ingredient.id)
                        Button {
                            if isChecked {
                                checkedIngredients.remove(ingredient.id)
                            } else {
                                checkedIngredients.insert(ingredient.id)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                SousCheckbox(isChecked: isChecked)
                                    .padding(.top, 2)
                                Text(ingredient.text)
                                    .font(.sousBody)
                                    .foregroundStyle(isChecked ? Color.sousMuted : Color.sousText)
                                    .strikethrough(isChecked, color: Color.sousMuted)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        SousRule()
                    }

                    // MARK: Procedure
                    SousSectionLabel(title: "Procedure")
                        .padding(.top, 24)
                        .padding(.bottom, 12)

                    ForEach(recipe.steps, id: \.id) { step in
                        let isDone = step.status == .done
                        Button {
                            if step.status == .todo { onMarkStepDone(step.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                SousCheckbox(isChecked: isDone)
                                    .padding(.top, 2)
                                Text(step.text)
                                    .font(.sousBody)
                                    .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                                    .strikethrough(isDone, color: Color.sousMuted)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDone)
                        SousRule()
                    }

                    // MARK: Notes
                    if !recipe.notes.isEmpty {
                        SousSectionLabel(title: "Notes")
                            .padding(.top, 24)
                            .padding(.bottom, 12)
                        ForEach(recipe.notes, id: \.self) { note in
                            Text("— \(note)")
                                .font(.sousBody)
                                .foregroundStyle(Color.sousText)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)

#if DEBUG
                if let status = llmDebugStatus {
                    Text(status)
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
#endif
            }
        }
        .background(Color.sousBackground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                SousRule()
                Button {
                    onOpenChat()
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
                // Swipe-down affordance hint
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.sousMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    .background(Color.sousBackground)
                    .allowsHitTesting(false)
            }
            .simultaneousGesture(openChatGesture)
        }
    }

    // MARK: - Open Chat Gesture

    private var openChatGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                guard value.translation.height >= 20 else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenChat()
            }
    }
}
