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
    var onResetRecipe: () -> Void = {}
    var miseEnPlaceIsLoading: Bool = false
    var miseEnPlaceError: String? = nil
    var llmDebugStatus: String? = nil
    var timerManager: StepTimerManager? = nil
    @Binding var scrollToStepId: UUID?
    @Binding var highlightedStepId: UUID?
    @Binding var ingredientsExpanded: Bool

    @State private var checkedIngredients: Set<UUID> = []
    @AppStorage("miseEnPlaceConfirmed") private var miseEnPlaceConfirmed: Bool = false
    @State private var showingMiseEnPlaceModal: Bool = false
    @State private var modalDontShowAgain: Bool = false
    @State private var showingResetConfirmation: Bool = false

    init(
        recipe: Recipe,
        onMarkStepDone: @escaping (UUID) -> Void = { _ in },
        onMarkMiseEnPlaceDone: @escaping (UUID) -> Void = { _ in },
        onTriggerMiseEnPlace: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onStartNew: @escaping () -> Void = {},
        onOpenRecents: @escaping () -> Void = {},
        onResetRecipe: @escaping () -> Void = {},
        miseEnPlaceIsLoading: Bool = false,
        miseEnPlaceError: String? = nil,
        llmDebugStatus: String? = nil,
        timerManager: StepTimerManager? = nil,
        scrollToStepId: Binding<UUID?> = .constant(nil),
        highlightedStepId: Binding<UUID?> = .constant(nil),
        ingredientsExpanded: Binding<Bool> = .constant(true)
    ) {
        self.recipe = recipe
        self.onMarkStepDone = onMarkStepDone
        self.onMarkMiseEnPlaceDone = onMarkMiseEnPlaceDone
        self.onTriggerMiseEnPlace = onTriggerMiseEnPlace
        self.onOpenSettings = onOpenSettings
        self.onStartNew = onStartNew
        self.onOpenRecents = onOpenRecents
        self.onResetRecipe = onResetRecipe
        self.miseEnPlaceIsLoading = miseEnPlaceIsLoading
        self.miseEnPlaceError = miseEnPlaceError
        self.llmDebugStatus = llmDebugStatus
        self.timerManager = timerManager
        self._scrollToStepId = scrollToStepId
        self._highlightedStepId = highlightedStepId
        self._ingredientsExpanded = ingredientsExpanded
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
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
                        SousIconButton(systemName: "arrow.counterclockwise") {
                            showingResetConfirmation = true
                        }
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
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            ingredientsExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("INGREDIENTS")
                                .font(.sousSectionHeader)
                                .foregroundStyle(Color.sousTerracotta)
                                .kerning(1.2)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.sousTerracotta)
                                .rotationEffect(.degrees(ingredientsExpanded ? 0 : -90))
                                .animation(.easeInOut(duration: 0.2), value: ingredientsExpanded)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    if ingredientsExpanded {
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
                    }

                    // MARK: Mise en place section (once populated)
                    if let mepEntries = recipe.miseEnPlace, !mepEntries.isEmpty {
                        SousSectionLabel(title: "Mise en place")
                            .padding(.top, 24)
                            .padding(.bottom, 12)

                        ForEach(mepEntries, id: \.id) { entry in
                            miseEnPlaceEntryRow(entry)
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

                    ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                        let isDone = step.status == .done
                        let isHighlighted = !isDone && highlightedStepId == step.id
                        HStack(alignment: .top, spacing: 12) {
                            // Checkbox — marks step done (blocked when timer is active)
                            Button {
                                if step.status == .todo { onMarkStepDone(step.id) }
                            } label: {
                                SousCheckbox(isChecked: isDone)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)

                            // Step text with optional timer affordance
                            if let tm = timerManager, !isDone {
                                TimerAffordanceText(
                                    step: step,
                                    stepIndex: index,
                                    isHighlighted: isHighlighted,
                                    timerManager: tm
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        highlightedStepId = nil
                                    }
                                }
                            } else {
                                Text(step.text)
                                    .font(.sousBody)
                                    .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                                    .strikethrough(isDone, color: Color.sousMuted)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            highlightedStepId = nil
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            // Negative horizontal padding cancels the parent VStack's 20pt inset,
                            // so the highlight background bleeds edge-to-edge while content stays inset.
                            (isHighlighted ? Color.sousHighlightBackground : Color.clear)
                                .padding(.horizontal, -20)
                        }
                        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                        .id(step.id)
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
                .padding(.bottom, 20)

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
        .onChange(of: scrollToStepId) { stepId in
            guard let id = stepId else { return }
            withAnimation {
                scrollProxy.scrollTo(id, anchor: .top)
            }
            scrollToStepId = nil
        }
        .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                highlightedStepId = nil
            }
        })
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
        } // end ScrollViewReader
        .alert("Start over?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                checkedIngredients = []
                onResetRecipe()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your chat history will be kept.")
        }
    }

    // MARK: - Mise en place entry row

    @ViewBuilder
    private func miseEnPlaceEntryRow(_ entry: MiseEnPlaceEntry) -> some View {
        switch entry.content {
        case .group(let vesselName, let components):
            VStack(alignment: .leading, spacing: 0) {
                // Header: display-only checkbox that reflects auto-complete state
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: entry.isDone)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                    Text(vesselName.uppercased())
                        .font(.sousSectionHeader)
                        .kerning(1.0)
                        .foregroundStyle(entry.isDone ? Color.sousMuted : Color.sousText)
                    Spacer()
                }
                .padding(.vertical, 10)

                // Per-component rows, indented
                ForEach(components, id: \.id) { component in
                    Button {
                        if !component.isDone { onMarkMiseEnPlaceDone(component.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Color.clear.frame(width: 20) // indent to align beneath header text
                            SousCheckbox(isChecked: component.isDone)
                                .padding(.top, 2)
                            Text(component.text)
                                .font(.sousBody)
                                .foregroundStyle(component.isDone ? Color.sousMuted : Color.sousText)
                                .strikethrough(component.isDone, color: Color.sousMuted)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .solo(let instruction, let isDone):
            Button {
                if !isDone { onMarkMiseEnPlaceDone(entry.id) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: isDone)
                        .padding(.top, 2)
                    Text(instruction)
                        .font(.sousBody)
                        .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                        .strikethrough(isDone, color: Color.sousMuted)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
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
