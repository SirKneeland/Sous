import SwiftUI
import SousCore

struct RecipeCanvasView: View {
    let recipe: Recipe
    var onMarkStepDone: (UUID) -> Void = { _ in }
    var onMarkMiseEnPlaceDone: (UUID) -> Void = { _ in }
    var onTriggerMiseEnPlace: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onStartNew: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var miseEnPlaceIsLoading: Bool = false
    var miseEnPlaceError: String? = nil
    var llmDebugStatus: String? = nil

    @State private var checkedIngredients: Set<UUID> = []
    @AppStorage("miseEnPlaceConfirmed") private var miseEnPlaceConfirmed: Bool = false
    @State private var showingMiseEnPlaceModal: Bool = false
    @State private var modalDontShowAgain: Bool = false

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
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: GearButtonFrameKey.self,
                                                       value: geo.frame(in: .named("contentRoot")))
                            })
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
                                    .foregroundStyle(Color.sousText)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        SousRule()
                    }

                    // MARK: Mise en place section (once populated)
                    if let mepSteps = recipe.miseEnPlace, !mepSteps.isEmpty {
                        SousSectionLabel(title: "Mise en place")
                            .padding(.top, 24)
                            .padding(.bottom, 12)

                        ForEach(mepSteps, id: \.id) { step in
                            let isDone = step.status == .done
                            Button {
                                if step.status == .todo { onMarkMiseEnPlaceDone(step.id) }
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
                            SousRule()
                        }
                    }

                    // MARK: Procedure header (with mise en place trigger)
                    HStack(alignment: .center) {
                        Text("PROCEDURE")
                            .font(.sousSectionHeader)
                            .foregroundStyle(Color.sousTerracotta)
                            .kerning(1.2)
                        Spacer()
                        if recipe.miseEnPlace == nil {
                            miseEnPlaceTrigger
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, miseEnPlaceError != nil ? 4 : 12)

                    // Inline error below header
                    if let error = miseEnPlaceError {
                        Text(error)
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousTerracotta)
                            .padding(.bottom, 12)
                    }

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
        .sheet(isPresented: $showingMiseEnPlaceModal) {
            MiseEnPlaceConfirmationModal(
                dontShowAgain: $modalDontShowAgain,
                onCancel: {
                    showingMiseEnPlaceModal = false
                    modalDontShowAgain = false
                },
                onConfirm: {
                    if modalDontShowAgain { miseEnPlaceConfirmed = true }
                    showingMiseEnPlaceModal = false
                    modalDontShowAgain = false
                    onTriggerMiseEnPlace()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Mise en place trigger

    @ViewBuilder
    private var miseEnPlaceTrigger: some View {
        Button {
            handleMiseEnPlaceTap()
        } label: {
            HStack(spacing: 5) {
                if miseEnPlaceIsLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(Color.sousTerracotta)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "carrot")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                }
                Text("MISE EN PLACE")
                    .font(.sousSectionHeader)
                    .kerning(1.2)
            }
            .foregroundStyle(Color.sousTerracotta)
        }
        .buttonStyle(.plain)
        .disabled(miseEnPlaceIsLoading)
    }

    private func handleMiseEnPlaceTap() {
        if miseEnPlaceConfirmed {
            onTriggerMiseEnPlace()
        } else {
            modalDontShowAgain = false
            showingMiseEnPlaceModal = true
        }
    }
}

// MARK: - Mise en place confirmation modal

private struct MiseEnPlaceConfirmationModal: View {
    @Binding var dontShowAgain: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MISE EN PLACE")
                    .font(.sousTitle)
                    .foregroundStyle(Color.sousText)

                Text("Mise en place will move all prep work — chopping, measuring, preheating — to a dedicated section at the top of your recipe, so everything is ready before you start cooking.")
                    .font(.sousBody)
                    .foregroundStyle(Color.sousText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                dontShowAgain.toggle()
            } label: {
                HStack(spacing: 12) {
                    SousCheckbox(isChecked: dontShowAgain, size: 18)
                    Text("Got it, don't show this again")
                        .font(.sousBody)
                        .foregroundStyle(Color.sousText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                Button {
                    onCancel()
                } label: {
                    Text("CANCEL")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))

                Button {
                    onConfirm()
                } label: {
                    Text("OK")
                        .font(.sousButton)
                        .foregroundStyle(Color.sousBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.sousText)
                }
                .buttonStyle(.plain)
            }
            .overlay(Rectangle().stroke(Color.sousText, lineWidth: 1))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.sousBackground)
    }
}
