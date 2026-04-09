import SwiftUI
import SousCore

struct RecipeCanvasView: View {
    let recipe: Recipe
    var onMarkStepDone: (UUID) -> Void = { _ in }
    var onMarkSubStepDone: (UUID, UUID) -> Void = { _, _ in }
    var onMarkMiseEnPlaceDone: (UUID) -> Void = { _ in }
    var onTriggerMiseEnPlace: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onStartNew: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var onResetRecipe: () -> Void = {}
    /// Called when the user swipes left on a row and taps "Ask Sous".
    /// Arguments: (rowType, rowText) where rowType is "ingredient" or "step".
    var onAskSousAbout: (String, String) -> Void = { _, _ in }
    var miseEnPlaceIsLoading: Bool = false
    var miseEnPlaceError: String? = nil
    var llmDebugStatus: String? = nil
    var timerManager: StepTimerManager? = nil
    @Binding var scrollToStepId: UUID?
    @Binding var highlightedStepId: UUID?
    @Binding var ingredientsExpanded: Bool
    @Binding var navBarVisible: Bool

    @State private var checkedIngredients: Set<UUID> = []
    @AppStorage("miseEnPlaceConfirmed") private var miseEnPlaceConfirmed: Bool = false
    @State private var showingMiseEnPlaceModal: Bool = false
    @State private var modalDontShowAgain: Bool = false
    @State private var showingResetConfirmation: Bool = false

    init(
        recipe: Recipe,
        onMarkStepDone: @escaping (UUID) -> Void = { _ in },
        onMarkSubStepDone: @escaping (UUID, UUID) -> Void = { _, _ in },
        onMarkMiseEnPlaceDone: @escaping (UUID) -> Void = { _ in },
        onTriggerMiseEnPlace: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onStartNew: @escaping () -> Void = {},
        onOpenRecents: @escaping () -> Void = {},
        onResetRecipe: @escaping () -> Void = {},
        onAskSousAbout: @escaping (String, String) -> Void = { _, _ in },
        miseEnPlaceIsLoading: Bool = false,
        miseEnPlaceError: String? = nil,
        llmDebugStatus: String? = nil,
        timerManager: StepTimerManager? = nil,
        scrollToStepId: Binding<UUID?> = .constant(nil),
        highlightedStepId: Binding<UUID?> = .constant(nil),
        ingredientsExpanded: Binding<Bool> = .constant(true),
        navBarVisible: Binding<Bool> = .constant(true)
    ) {
        self.recipe = recipe
        self.onMarkStepDone = onMarkStepDone
        self.onMarkSubStepDone = onMarkSubStepDone
        self.onMarkMiseEnPlaceDone = onMarkMiseEnPlaceDone
        self.onTriggerMiseEnPlace = onTriggerMiseEnPlace
        self.onOpenSettings = onOpenSettings
        self.onStartNew = onStartNew
        self.onOpenRecents = onOpenRecents
        self.onResetRecipe = onResetRecipe
        self.onAskSousAbout = onAskSousAbout
        self.miseEnPlaceIsLoading = miseEnPlaceIsLoading
        self.miseEnPlaceError = miseEnPlaceError
        self.llmDebugStatus = llmDebugStatus
        self.timerManager = timerManager
        self._scrollToStepId = scrollToStepId
        self._highlightedStepId = highlightedStepId
        self._ingredientsExpanded = ingredientsExpanded
        self._navBarVisible = navBarVisible
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            // List provides native swipe-action gesture coordination — iOS resolves
            // conflicts between .swipeActions, row taps, and vertical scroll at the
            // UITableView/UICollectionView level without any custom gesture code.
            List {

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
                    SousIconButton(systemName: "arrow.counterclockwise") {
                        showingResetConfirmation = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.visible, edges: .bottom)
                .listRowSeparatorTint(Color.sousSeparator)

                // MARK: Ingredients section header (collapsible)
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // MARK: Ingredient rows
                if ingredientsExpanded {
                    ForEach(recipe.ingredients, id: \.id) { ingredient in
                        let isChecked = checkedIngredients.contains(ingredient.id)
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
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isChecked { checkedIngredients.remove(ingredient.id) }
                            else { checkedIngredients.insert(ingredient.id) }
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onAskSousAbout("ingredient", ingredient.text)
                                }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.sousSeparator)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !isChecked {
                                Button {
                                    checkedIngredients.insert(ingredient.id)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(Color.sousGreen)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                onAskSousAbout("ingredient", ingredient.text)
                            } label: {
                                Label("Ask Sous", systemImage: "bubble.left")
                            }
                            .tint(Color.sousTerracotta)
                        }
                    }
                }

                // MARK: Mise en place section (once populated)
                if let mepEntries = recipe.miseEnPlace, !mepEntries.isEmpty {
                    SousSectionLabel(title: "Mise en place")
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(flatMEPRows(mepEntries)) { row in
                        mepFlatRowView(row)
                            .padding(.horizontal, 20)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        onAskSousAbout("mise en place", row.askSousText)
                                    }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.visible, edges: .bottom)
                            .listRowSeparatorTint(Color.sousSeparator)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !row.isDone {
                                    Button {
                                        for id in row.completeIds { onMarkMiseEnPlaceDone(id) }
                                    } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(Color.sousGreen)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    onAskSousAbout("mise en place", row.askSousText)
                                } label: {
                                    Label("Ask Sous", systemImage: "bubble.left")
                                }
                                .tint(Color.sousTerracotta)
                            }
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
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, miseEnPlaceError != nil ? 4 : 12)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Inline error below procedure header
                if let error = miseEnPlaceError {
                    Text(error)
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousTerracotta)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // MARK: Step rows
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    if let subSteps = step.subSteps, !subSteps.isEmpty {
                        let items = subSteps.map { NestedStepItem(id: $0.id, text: $0.text, isDone: $0.effectiveStatus == .done) }
                        NestedStepGroupView(
                            header: step.text,
                            items: items,
                            isDone: step.effectiveStatus == .done,
                            onChildTap: { subStepId in onMarkSubStepDone(step.id, subStepId) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(step.id)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onAskSousAbout("step", step.text)
                                }
                        )
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.sousSeparator)
                    } else {
                        let isDone = step.status == .done
                        let isHighlighted = !isDone && highlightedStepId == step.id
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                if step.status == .todo { onMarkStepDone(step.id) }
                            } label: {
                                SousCheckbox(isChecked: isDone)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)

                            if let tm = timerManager, !isDone {
                                TimerAffordanceText(
                                    step: step,
                                    stepIndex: index,
                                    isHighlighted: isHighlighted,
                                    timerManager: tm,
                                    onClearHighlight: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            highlightedStepId = nil
                                        }
                                    }
                                )
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
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(step.id)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(
                            isHighlighted
                                ? Color.sousHighlightBackground
                                : Color.clear
                        )
                        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onAskSousAbout("step", step.text)
                                }
                        )
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.sousSeparator)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !isDone {
                                Button {
                                    onMarkStepDone(step.id)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(Color.sousGreen)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                onAskSousAbout("step", step.text)
                            } label: {
                                Label("Ask Sous", systemImage: "bubble.left")
                            }
                            .tint(Color.sousTerracotta)
                        }
                    }
                }

                // MARK: Notes
                if !recipe.notes.isEmpty {
                    SousSectionLabel(title: "Notes")
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(recipe.notes, id: \.self) { note in
                        Text("— \(note)")
                            .font(.sousBody)
                            .foregroundStyle(Color.sousText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                // Bottom breathing room
                Color.clear.frame(height: 20)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

#if DEBUG
                if let status = llmDebugStatus {
                    Text(status)
                        .font(.sousCaption)
                        .foregroundStyle(Color.sousMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
#endif

            } // end List
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.sousBackground.paperTexture())
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newVal in
                withAnimation(.easeInOut(duration: 0.2)) {
                    navBarVisible = newVal < 60
                }
            }
            .onChange(of: scrollToStepId) { stepId in
                guard let id = stepId else { return }
                withAnimation {
                    scrollProxy.scrollTo(id, anchor: .top)
                }
                scrollToStepId = nil
            }
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

    // MARK: - Mise en place flat row helpers

    private func flatMEPRows(_ entries: [MiseEnPlaceEntry]) -> [MEPFlatRow] {
        entries.flatMap { entry -> [MEPFlatRow] in
            switch entry.content {
            case .solo(let instruction, let isDone):
                return [MEPFlatRow(
                    id: entry.id,
                    kind: .solo(instruction: instruction, isDone: isDone)
                )]
            case .group(let vesselName, let components):
                let incompleteIds = components.filter { !$0.isDone }.map { $0.id }
                let header = MEPFlatRow(
                    id: entry.id,
                    kind: .groupHeader(vesselName: vesselName, isDone: entry.isDone,
                                       incompleteComponentIds: incompleteIds)
                )
                let children = components.map { c in
                    MEPFlatRow(id: c.id,
                               kind: .groupComponent(text: c.text, isDone: c.isDone, vesselName: vesselName))
                }
                return [header] + children
            }
        }
    }

    @ViewBuilder
    private func mepFlatRowView(_ row: MEPFlatRow) -> some View {
        switch row.kind {
        case .solo(let instruction, let isDone):
            Button {
                if !isDone { onMarkMiseEnPlaceDone(row.id) }
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

        case .groupHeader(let vesselName, let isDone, let incompleteIds):
            Button {
                for id in incompleteIds { onMarkMiseEnPlaceDone(id) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: isDone)
                        .padding(.top, 2)
                    Text(vesselName)
                        .font(.sousBody)
                        .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                        .strikethrough(isDone, color: Color.sousMuted)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

        case .groupComponent(let text, let isDone, _):
            NestedStepChildRow(text: text, isDone: isDone) {
                onMarkMiseEnPlaceDone(row.id)
            }
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

// MARK: - Mise en place flat row model

private struct MEPFlatRow: Identifiable {
    enum Kind {
        case solo(instruction: String, isDone: Bool)
        case groupHeader(vesselName: String, isDone: Bool, incompleteComponentIds: [UUID])
        case groupComponent(text: String, isDone: Bool, vesselName: String)
    }
    let id: UUID
    let kind: Kind

    var isDone: Bool {
        switch kind {
        case .solo(_, let d): return d
        case .groupHeader(_, let d, _): return d
        case .groupComponent(_, let d, _): return d
        }
    }

    /// IDs to mark done when the user taps this row's "Done" action.
    var completeIds: [UUID] {
        switch kind {
        case .solo: return [id]
        case .groupHeader(_, _, let ids): return ids
        case .groupComponent: return [id]
        }
    }

    /// Text used for "Ask Sous" context.
    var askSousText: String {
        switch kind {
        case .solo(let instruction, _): return instruction
        case .groupHeader(let name, _, _): return name
        case .groupComponent(let text, _, _): return text
        }
    }
}

// MARK: - Nested step group support

private struct NestedStepItem: Identifiable {
    let id: UUID
    let text: String
    let isDone: Bool
}

/// Renders a group header with a non-interactive derived-done checkbox, followed by
/// individually tappable child rows with indented checkboxes. Used for procedure
/// sub-step groups; child row rendering is shared with MEP group components via
/// `NestedStepChildRow`.
private struct NestedStepGroupView: View {
    let header: String
    let items: [NestedStepItem]
    let isDone: Bool
    let onChildTap: (UUID) -> Void

    var body: some View {
        Group {
            HStack(alignment: .top, spacing: 12) {
                SousCheckbox(isChecked: isDone)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
                Text(header.uppercased())
                    .font(.sousSectionHeader)
                    .kerning(1.0)
                    .foregroundStyle(isDone ? Color.sousMuted : Color.sousText)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)

            ForEach(items) { item in
                NestedStepChildRow(text: item.text, isDone: item.isDone, indentWidth: 32) {
                    onChildTap(item.id)
                }
            }
        }
    }
}

/// Single indented child row used by both `NestedStepGroupView` (procedure sub-steps)
/// and `mepFlatRowView` (MEP group components). Pass `indentWidth` to match the
/// surrounding layout: 32 for procedure (header has explicit 20px horizontal padding),
/// 20 for MEP (caller applies 20px horizontal padding to the row).
private struct NestedStepChildRow: View {
    let text: String
    let isDone: Bool
    var indentWidth: CGFloat = 20
    let onTap: () -> Void

    var body: some View {
        Button {
            if !isDone { onTap() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Color.clear.frame(width: indentWidth, height: 20)
                SousCheckbox(isChecked: isDone)
                    .padding(.top, 2)
                Text(text)
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
