import SwiftUI
import SousCore

private struct ScrollState: Equatable {
    var offset: CGFloat
    var contentHeight: CGFloat
    var containerHeight: CGFloat
}

struct RecipeCanvasView: View {
    let recipe: Recipe
    var onMarkStepDone: (UUID) -> Void = { _ in }
    var onMarkStepUndone: (UUID) -> Void = { _ in }
    var onMarkSubStepDone: (UUID, UUID) -> Void = { _, _ in }
    var onMarkMiseEnPlaceDone: (UUID) -> Void = { _ in }
    var onTriggerMiseEnPlace: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onStartNew: () -> Void = {}
    var onOpenRecents: () -> Void = {}
    var onResetRecipe: () -> Void = {}
    var onUpdateTitle: (String) -> Void = { _ in }
    var onEditingTitleChanged: (Bool) -> Void = { _ in }
    /// Called when the user swipes left on a row and taps "Ask Sous".
    /// Arguments: (rowType, rowText) where rowType is "ingredient" or "step".
    var onAskSousAbout: (String, String) -> Void = { _, _ in }
    var onMarkMiseEnPlaceUndone: (UUID) -> Void = { _ in }
    var miseEnPlaceIsLoading: Bool = false
    var miseEnPlaceError: String? = nil
    var llmDebugStatus: String? = nil
    var timerManager: StepTimerManager? = nil
    @Binding var scrollToStepId: UUID?
    @Binding var highlightedStepId: UUID?
    @Binding var ingredientsExpanded: Bool
    @Binding var stepsCompletedExpanded: Bool
    @Binding var miseEnPlaceExpanded: Bool
    @Binding var navBarVisible: Bool
    var bottomZoneHeight: CGFloat = 0

    @State private var checkedIngredients: Set<UUID> = []
    @AppStorage("miseEnPlaceConfirmed") private var miseEnPlaceConfirmed: Bool = false
    @State private var showingMiseEnPlaceModal: Bool = false
    @State private var modalDontShowAgain: Bool = false
    @State private var showingResetConfirmation: Bool = false
    @State private var resetButtonPressed: Bool = false
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String = ""
    @FocusState private var isTitleFocused: Bool
    @State private var stepCollapseStates: [String: StepCollapsePhase] = [:]
    @State private var stepDrainScales: [String: CGFloat] = [:]
    @State private var mepDrainStates: [String: StepCollapsePhase] = [:]
    @State private var mepDrainScales: [String: CGFloat] = [:]

    init(
        recipe: Recipe,
        onMarkStepDone: @escaping (UUID) -> Void = { _ in },
        onMarkStepUndone: @escaping (UUID) -> Void = { _ in },
        onMarkSubStepDone: @escaping (UUID, UUID) -> Void = { _, _ in },
        onMarkMiseEnPlaceDone: @escaping (UUID) -> Void = { _ in },
        onMarkMiseEnPlaceUndone: @escaping (UUID) -> Void = { _ in },
        onTriggerMiseEnPlace: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onStartNew: @escaping () -> Void = {},
        onOpenRecents: @escaping () -> Void = {},
        onResetRecipe: @escaping () -> Void = {},
        onUpdateTitle: @escaping (String) -> Void = { _ in },
        onEditingTitleChanged: @escaping (Bool) -> Void = { _ in },
        onAskSousAbout: @escaping (String, String) -> Void = { _, _ in },
        miseEnPlaceIsLoading: Bool = false,
        miseEnPlaceError: String? = nil,
        llmDebugStatus: String? = nil,
        timerManager: StepTimerManager? = nil,
        scrollToStepId: Binding<UUID?> = .constant(nil),
        highlightedStepId: Binding<UUID?> = .constant(nil),
        ingredientsExpanded: Binding<Bool> = .constant(true),
        stepsCompletedExpanded: Binding<Bool> = .constant(true),
        miseEnPlaceExpanded: Binding<Bool> = .constant(true),
        navBarVisible: Binding<Bool> = .constant(true),
        bottomZoneHeight: CGFloat = 0
    ) {
        self.recipe = recipe
        self.onMarkStepDone = onMarkStepDone
        self.onMarkStepUndone = onMarkStepUndone
        self.onMarkSubStepDone = onMarkSubStepDone
        self.onMarkMiseEnPlaceDone = onMarkMiseEnPlaceDone
        self.onMarkMiseEnPlaceUndone = onMarkMiseEnPlaceUndone
        self.onTriggerMiseEnPlace = onTriggerMiseEnPlace
        self.onOpenSettings = onOpenSettings
        self.onStartNew = onStartNew
        self.onOpenRecents = onOpenRecents
        self.onResetRecipe = onResetRecipe
        self.onUpdateTitle = onUpdateTitle
        self.onEditingTitleChanged = onEditingTitleChanged
        self.onAskSousAbout = onAskSousAbout
        self.miseEnPlaceIsLoading = miseEnPlaceIsLoading
        self.miseEnPlaceError = miseEnPlaceError
        self.llmDebugStatus = llmDebugStatus
        self.timerManager = timerManager
        self._scrollToStepId = scrollToStepId
        self._highlightedStepId = highlightedStepId
        self._ingredientsExpanded = ingredientsExpanded
        self._stepsCompletedExpanded = stepsCompletedExpanded
        self._miseEnPlaceExpanded = miseEnPlaceExpanded
        self._navBarVisible = navBarVisible
        self.bottomZoneHeight = bottomZoneHeight
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            // List provides native swipe-action gesture coordination — iOS resolves
            // conflicts between .swipeActions, row taps, and vertical scroll at the
            // UITableView/UICollectionView level without any custom gesture code.
            List {

                // MARK: Header
                // The row itself is full-width (listRowInsets zero) so the separator spans
                // the full canvas width matching all other rows.
                // titleInset pads only the title+revision content to clear the 44pt hamburger
                // button (16pt safe-area offset + 44pt button + 16pt margin = 76pt).
                let titleInset: CGFloat = 76
                VStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 4) {
                        if isEditingTitle {
                            TextField("", text: $titleDraft, axis: .vertical)
                                .font(.sousTitle)
                                .foregroundStyle(Color.sousText)
                                .textCase(.uppercase)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.center)
                                .focused($isTitleFocused)
                                .onChange(of: titleDraft) { _, newValue in
                                    // axis: .vertical swallows the return key as a newline;
                                    // detect it here and treat as submit.
                                    if newValue.contains("\n") {
                                        titleDraft = newValue.replacingOccurrences(of: "\n", with: "")
                                        commitTitleEdit()
                                    }
                                }
                                .onChange(of: isTitleFocused) { _, focused in
                                    // Commit when focus leaves the field (e.g. user taps
                                    // a list row or dismisses the keyboard). iOS text
                                    // selection does not blur the field, so this is safe.
                                    if !focused { commitTitleEdit() }
                                }
                        } else {
                            Text(recipe.title.uppercased())
                                .font(.sousTitle)
                                .foregroundStyle(Color.sousText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture {
                                    titleDraft = recipe.title
                                    isEditingTitle = true
                                    isTitleFocused = true
                                    onEditingTitleChanged(true)
                                }
                        }
                        Text("REV. \(recipe.version)")
                            .font(.sousCaption)
                            .foregroundStyle(Color.sousMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, titleInset)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    Divider()
                        .background(Color.sousSeparator)
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            miseEnPlaceExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("MISE EN PLACE")
                                    .font(.sousSectionHeader)
                                    .foregroundStyle(Color.sousTerracotta)
                                    .kerning(1.2)
                                if !miseEnPlaceExpanded && completedMEPRows.count > 0 {
                                    Text("· \(completedMEPRows.count) done")
                                        .font(.sousCaption)
                                        .foregroundStyle(Color.sousMuted)
                                }
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.sousTerracotta)
                                .rotationEffect(.degrees(miseEnPlaceExpanded ? 0 : -90))
                                .animation(.easeInOut(duration: 0.2), value: miseEnPlaceExpanded)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(flatMEPRows(mepEntries)) { row in
                        let mepPhase = mepDrainStates[row.id.uuidString]
                        if !row.isDone || miseEnPlaceExpanded || mepPhase != nil {
                            let undoOverride: (() -> Void)? = mepPhase == .draining ? {
                                mepDrainStates.removeValue(forKey: row.id.uuidString)
                                mepDrainScales.removeValue(forKey: row.id.uuidString)
                                onMarkMiseEnPlaceUndone(row.id)
                            } : nil
                            mepFlatRowView(row, tapOverride: undoOverride)
                                .padding(.horizontal, 20)
                                .overlay(alignment: .top) {
                                    if mepPhase == .draining {
                                        Rectangle()
                                            .fill(Color.sousTerracotta)
                                            .frame(height: 2)
                                            .scaleEffect(x: mepDrainScales[row.id.uuidString] ?? 1.0, y: 1, anchor: .leading)
                                    }
                                }
                                .opacity(mepPhase == .fading ? 0 : 1)
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
                                            for id in row.completeIds { handleMarkMEPDone(id) }
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
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }

                // MARK: Procedure header (with mise en place trigger)
                HStack(alignment: .center) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            stepsCompletedExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("PROCEDURE")
                                    .font(.sousSectionHeader)
                                    .foregroundStyle(Color.sousTerracotta)
                                    .kerning(1.2)
                                if !stepsCompletedExpanded && completedFlatSteps.count > 0 {
                                    Text("· \(completedFlatSteps.count) done")
                                        .font(.sousCaption)
                                        .foregroundStyle(Color.sousMuted)
                                }
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.sousTerracotta)
                                .rotationEffect(.degrees(stepsCompletedExpanded ? 0 : -90))
                                .animation(.easeInOut(duration: 0.2), value: stepsCompletedExpanded)
                        }
                    }
                    .buttonStyle(.plain)
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

                // MARK: Step rows (all steps in original order)
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    if let subSteps = step.subSteps, !subSteps.isEmpty {
                        let items = subSteps.map { NestedStepItem(id: $0.id, text: $0.text, isDone: $0.effectiveStatus == .done) }
                        NestedStepGroupView(
                            header: step.text,
                            items: items,
                            isDone: step.effectiveStatus == .done,
                            isCurrent: step.id == currentStepId,
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
                        let isDone = step.effectiveStatus == .done
                        let collapsePhase = stepCollapseStates[step.id.uuidString]
                        if !isDone || stepsCompletedExpanded || collapsePhase != nil {
                            let isHighlighted = !isDone && highlightedStepId == step.id
                            HStack(alignment: .top, spacing: 12) {
                                Button {
                                    // Check drain state FIRST — if draining, cancel and revert.
                                    // Must not fall through to any logic that touches stepsCompletedExpanded.
                                    if collapsePhase == .draining {
                                        stepCollapseStates.removeValue(forKey: step.id.uuidString)
                                        stepDrainScales.removeValue(forKey: step.id.uuidString)
                                        onMarkStepUndone(step.id)
                                        return
                                    }
                                    if step.status == .todo {
                                        handleMarkStepDone(step.id)
                                    }
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
                                        isCurrent: step.id == currentStepId,
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
                                        .fontWeight(step.id == currentStepId ? .bold : nil)
                                        .animation(.easeInOut(duration: 0.2), value: currentStepId)
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
                            .overlay(alignment: .top) {
                                if collapsePhase == .draining {
                                    Rectangle()
                                        .fill(Color.sousTerracotta)
                                        .frame(height: 2)
                                        .scaleEffect(x: stepDrainScales[step.id.uuidString] ?? 1.0, y: 1, anchor: .leading)
                                }
                            }
                            .opacity(collapsePhase == .fading ? 0 : 1)
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
                                        handleMarkStepDone(step.id)
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
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
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

                // Reset Recipe button at bottom of canvas
                Button {
                    resetButtonPressed = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingResetConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Reset Recipe")
                            .font(.sousButton)
                    }
                    .foregroundStyle(resetButtonPressed ? Color.white : Color.sousTerracotta)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(resetButtonPressed ? Color.sousTerracotta : Color.clear)
                    .overlay(Rectangle().stroke(Color.sousTerracotta, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Bottom breathing room — sized to bottomZoneHeight so the Reset
                // button scrolls fully clear of the BottomZoneView frame.
                Color.clear.frame(height: bottomZoneHeight)
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
            .onScrollGeometryChange(for: ScrollState.self) { geo in
                ScrollState(
                    offset: geo.contentOffset.y,
                    contentHeight: geo.contentSize.height,
                    containerHeight: geo.containerSize.height
                )
            } action: { oldVal, newVal in
                let distanceFromBottom = newVal.contentHeight - newVal.containerHeight - newVal.offset
                if newVal.offset < 60 {
                    navBarVisible = true
                } else if newVal.offset < oldVal.offset && distanceFromBottom > 40 {
                    navBarVisible = true
                } else if newVal.offset > oldVal.offset + 10 {
                    navBarVisible = false
                }
            }
            .onChange(of: scrollToStepId) { stepId in
                guard let id = stepId else { return }
                withAnimation {
                    scrollProxy.scrollTo(id, anchor: .top)
                }
                scrollToStepId = nil
            }
            .onChange(of: stepsCompletedExpanded) { _, expanded in
                if expanded {
                    stepCollapseStates.removeAll()
                    stepDrainScales.removeAll()
                }
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
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                // Blur layer — blurs scroll content passing through, masked to fade bottom
                Color.clear
                    .frame(height: 80)
                    .background(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                // Solid fade — opaque at top, transitions to clear so blur layer takes over
                LinearGradient(
                    stops: [
                        .init(color: Color.sousBackground, location: 0),
                        .init(color: Color.sousBackground.opacity(0.9), location: 0.35),
                        .init(color: Color.sousBackground.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
        .alert("Start over?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                resetButtonPressed = false
                checkedIngredients = []
                onResetRecipe()
            }
            Button("Cancel", role: .cancel) {
                resetButtonPressed = false
            }
        } message: {
            Text("Your chat history will be kept.")
        }
    }

    // MARK: - Title editing

    private func commitTitleEdit() {
        guard isEditingTitle else { return }
        isTitleFocused = false
        isEditingTitle = false
        onEditingTitleChanged(false)
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onUpdateTitle(trimmed)
    }

    // MARK: - Step collapse helpers

    /// Completed MEP rows (solo or groupComponent), used for the "N done" count in the MEP header.
    private var completedMEPRows: [MEPFlatRow] {
        guard let entries = recipe.miseEnPlace else { return [] }
        return flatMEPRows(entries).filter { $0.isDone && !$0.isGroupHeader }
    }

    /// Flat steps that are done, in original recipe order. Used for the "N done" count in the header.
    private var completedFlatSteps: [Step] {
        recipe.steps.filter { step in
            (step.subSteps == nil || step.subSteps!.isEmpty) && step.effectiveStatus == .done
        }
    }

    /// The ID of the step that should receive bold treatment — the earliest unchecked step.
    /// MEP takes priority: if any MEP entry is undone, the first undone MEP entry is current.
    /// Once all MEP is done (or absent), the first undone procedure step is current.
    private var currentStepId: UUID? {
        if let mepEntries = recipe.miseEnPlace, !mepEntries.isEmpty {
            if !mepEntries.allSatisfy({ $0.isDone }) {
                return mepEntries.first(where: { !$0.isDone })?.id
            }
        }
        return recipe.steps.first(where: { $0.effectiveStatus == .todo })?.id
    }

    /// Marks a step done, triggering the two-phase drain animation when the
    /// completed section is collapsed.
    private func handleMarkStepDone(_ stepId: UUID) {
        onMarkStepDone(stepId)
        guard !stepsCompletedExpanded else { return }
        let idStr = stepId.uuidString
        // Set scale to 1.0 and phase synchronously so SwiftUI commits them
        // before the Task runs on the next run-loop iteration.
        stepDrainScales[idStr] = 1.0
        stepCollapseStates[idStr] = .draining
        Task { @MainActor in
            // Phase 1: drain bar shrinks from 1.0 → 0.0 over 5 seconds.
            // withAnimation runs after the synchronous frame so SwiftUI
            // correctly interpolates from the committed 1.0 value.
            withAnimation(.linear(duration: 3.0)) {
                stepDrainScales[idStr] = 0.0
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard stepCollapseStates[idStr] == .draining else { return }
            // Phase 2: fade row to opacity 0.
            withAnimation(.easeInOut(duration: 0.3)) {
                stepCollapseStates[idStr] = .fading
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Remove entry so the list row collapses upward.
            withAnimation(.easeInOut(duration: 0.3)) {
                stepCollapseStates.removeValue(forKey: idStr)
                stepDrainScales.removeValue(forKey: idStr)
            }
        }
    }

    /// Marks an MEP row done and starts the drain animation when the section is collapsed.
    private func handleMarkMEPDone(_ id: UUID) {
        onMarkMiseEnPlaceDone(id)
        guard !miseEnPlaceExpanded else { return }
        let idStr = id.uuidString
        mepDrainScales[idStr] = 1.0
        mepDrainStates[idStr] = .draining
        Task { @MainActor in
            withAnimation(.linear(duration: 3.0)) {
                mepDrainScales[idStr] = 0.0
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard mepDrainStates[idStr] == .draining else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                mepDrainStates[idStr] = .fading
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                mepDrainStates.removeValue(forKey: idStr)
                mepDrainScales.removeValue(forKey: idStr)
            }
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
    private func mepFlatRowView(_ row: MEPFlatRow, tapOverride: (() -> Void)? = nil) -> some View {
        switch row.kind {
        case .solo(let instruction, let isDone):
            Button {
                if let override = tapOverride {
                    override()
                } else if !isDone {
                    handleMarkMEPDone(row.id)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: isDone)
                        .padding(.top, 2)
                    Text(instruction)
                        .font(.sousBody)
                        .fontWeight(row.id == currentStepId ? .bold : nil)
                        .animation(.easeInOut(duration: 0.2), value: currentStepId)
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
                if let override = tapOverride {
                    override()
                } else {
                    for id in incompleteIds { handleMarkMEPDone(id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    SousCheckbox(isChecked: isDone)
                        .padding(.top, 2)
                    Text(vesselName)
                        .font(.sousBody)
                        .fontWeight(row.id == currentStepId ? .bold : nil)
                        .animation(.easeInOut(duration: 0.2), value: currentStepId)
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
                if let override = tapOverride { override() }
                else { handleMarkMEPDone(row.id) }
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

    var isGroupHeader: Bool {
        if case .groupHeader = kind { return true }
        return false
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

// MARK: - Step collapse phase

private enum StepCollapsePhase { case draining, fading }

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
    var isCurrent: Bool = false
    let onChildTap: (UUID) -> Void

    var body: some View {
        Group {
            HStack(alignment: .top, spacing: 12) {
                SousCheckbox(isChecked: isDone)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
                Text(header.uppercased())
                    .font(.sousSectionHeader)
                    .fontWeight(isCurrent ? .bold : nil)
                    .animation(.easeInOut(duration: 0.2), value: isCurrent)
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
