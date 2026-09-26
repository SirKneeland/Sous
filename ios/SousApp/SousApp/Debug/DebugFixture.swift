#if DEBUG
import Foundation
import SousCore

/// Debug-only UI fixtures for unattended simulator verification.
///
/// The problem this solves: every screen in Sous sits behind Sign in with Apple, and
/// almost every screen worth looking at needs a recipe on the canvas — which normally
/// costs a live LLM call. That makes it impossible to check a colour or a label in the
/// Simulator without a backend, an OpenAI key, and real spend.
///
/// A fixture supplies both halves offline: `AuthState.debugSignInOffline` fakes the
/// session without touching the network, and `AppStore.applyDebugFixture` puts a canned
/// recipe (and optionally a pending patch) straight into `uiState`.
///
/// Nothing here is a substitute for the real paths. It never fakes `PatchValidationResult`
/// — the validator runs for real against the fixture recipe, so an invalid fixture shows
/// up as an invalid patch rather than a green button that lies. Compiled out of Release.
///
/// Usage:
///   -sous-fixture canvas                  recipe on the canvas
///   -sous-fixture review                  recipe + pending patch, on the review screen
///   -sous-fixture explore                 no canvas, generate pill showing
///   -sous-fixture paywall                 the subscription wall
///   -sous-fixture capReached              the 100-a-month hard stop
///   -sous-fixture memoryToast             the memory proposal toast, over the chat
///   -sous-fixture-entitlement byok        entitlement to fake (default: subscriber)
enum DebugFixture {

    enum Kind: String {
        /// A recipe on the canvas, with an `originalRecipe` that differs so the
        /// RESTORE ORIGINAL RECIPE button is reachable.
        case canvas
        /// The same recipe with a pending PatchSet, landing on the change-review screen.
        case review
        /// No canvas, mid-exploration, with the generate pill showing.
        case explore
        /// The subscription wall, over a canvas.
        case paywall
        /// The 100-recipes-a-month hard stop, over a canvas.
        case capReached
        /// A memory proposal toast over the chat. Normally needs a live model turn.
        case memoryToast
    }

    /// Canned usage for the cap-reached screen. Reaching it for real needs a paid
    /// account that has actually spent 100 recipes, which no test account will have.
    static func cappedUsage() -> UsageSummary {
        UsageSummary(recipesUsed: 100, recipeCap: 100, billingPeriod: "2026-09",
                     resetsInDays: 6, entitlement: "subscriber",
                     trialRecipesUsed: nil, trialRecipeCap: nil, trialDaysRemaining: nil)
    }

    // MARK: Launch flags

    /// The fixture requested at launch, or nil when none was.
    static func requested(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Kind? {
        value(for: "SOUS_FIXTURE", flag: "-sous-fixture", environment, arguments)
            .flatMap(Kind.init(rawValue:))
    }

    /// Entitlement to fake. Defaults to `.subscriber` — full access, no billing walls.
    static func entitlement(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Entitlement {
        value(for: "SOUS_FIXTURE_ENTITLEMENT", flag: "-sous-fixture-entitlement", environment, arguments)
            .flatMap(Entitlement.init(rawValue:)) ?? .subscriber
    }

    private static func value(
        for envKey: String,
        flag: String,
        _ environment: [String: String],
        _ arguments: [String]
    ) -> String? {
        if let raw = environment[envKey] {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard let flagIndex = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else { return nil }
        let candidate = arguments[valueIndex]
        // A following token that is itself a flag belongs to someone else.
        guard !candidate.hasPrefix("-") else { return nil }
        return candidate
    }

    // MARK: Fixture data

    // Stable ids so a patch can target the recipe it was built against.
    private static let recipeId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000A1")!
    private static let groupId  = UUID(uuidString: "F1000000-0000-0000-0000-0000000000B1")!
    private static let ingChickenId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000C1")!
    private static let ingPaprikaId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000C2")!
    private static let ingPankoId   = UUID(uuidString: "F1000000-0000-0000-0000-0000000000C3")!
    private static let stepPrepId   = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D1")!
    private static let stepDredgeId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D2")!
    private static let stepBakeId   = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D3")!
    private static let stepRestId   = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D4")!
    private static let mepGroupId     = UUID(uuidString: "F1000000-0000-0000-0000-0000000000E1")!
    private static let mepCompPankoId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000E2")!
    private static let mepCompSpiceId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000E3")!
    private static let mepSoloId      = UUID(uuidString: "F1000000-0000-0000-0000-0000000000E4")!
    private static let stepSubEggId   = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D5")!
    private static let stepSubPressId = UUID(uuidString: "F1000000-0000-0000-0000-0000000000D6")!

    /// The canvas recipe. Deliberately exercises the things worth looking at: a servings
    /// value (servings picker), a step with a duration phrase (inline timer affordance →
    /// duration picker), a ranged duration (duration picker), a step already marked done
    /// (immutability styling), and a mise en place section carrying all three row shapes —
    /// group header, group component, and solo — so every checklist row is on one screen.
    static func recipe() -> Recipe {
        Recipe(
            id: recipeId,
            version: 3,
            title: "Crispy Baked Chicken Cutlets",
            ingredients: [
                // A named group, so the ingredient group header renders — it is the one
                // header with its own letter-spacing, and nothing else exercises it.
                IngredientGroup(id: groupId, header: "For the cutlets", items: [
                    Ingredient(id: ingChickenId, text: "4 chicken cutlets, pounded thin"),
                    Ingredient(id: ingPaprikaId, text: "2 tsp smoked paprika"),
                    Ingredient(id: ingPankoId,   text: "1 cup panko breadcrumbs"),
                ]),
            ],
            steps: [
                Step(id: stepPrepId,   text: "Heat the oven to 425°F and line a sheet pan", status: .done),
                // Carries sub-steps, so the nesting indent is on screen — the only thing
                // that shows whether a sub-step and a prep task line up.
                Step(id: stepDredgeId, text: "Dredge the cutlets in panko and paprika",     status: .todo,
                     subSteps: [
                        Step(id: stepSubEggId,   text: "Dip in beaten egg first", status: .todo),
                        Step(id: stepSubPressId, text: "Press the panko on firmly", status: .todo),
                     ]),
                Step(id: stepBakeId,   text: "Bake for 18 minutes until golden",            status: .todo),
                // A range, deliberately: a single duration starts the timer straight away,
                // whereas a range is what opens DurationPickerSheet.
                Step(id: stepRestId,   text: "Rest 5 to 10 minutes before slicing",          status: .todo),
            ],
            miseEnPlace: [
                MiseEnPlaceEntry(id: mepGroupId, content: .group(
                    vesselName: "Breading station",
                    components: [
                        MiseEnPlaceComponent(id: mepCompPankoId,   text: "1 cup panko", isDone: true),
                        MiseEnPlaceComponent(id: mepCompSpiceId,   text: "2 tsp smoked paprika"),
                    ]
                )),
                MiseEnPlaceEntry(id: mepSoloId, content: .solo(
                    instruction: "Line a sheet pan with parchment", isDone: false
                )),
            ],
            servings: 4
        )
    }

    /// A prior version of the recipe, so `originalRecipe` differs from the current one and
    /// the RESTORE ORIGINAL RECIPE button appears.
    static func originalRecipe() -> Recipe {
        var original = recipe()
        original.version = 1
        original.title = "Baked Chicken Cutlets"
        return original
    }

    /// A pending patch against `recipe()`: one ingredient edited, one step added. Enough
    /// for the review screen to show both a removed and an added diff row.
    static func patchSet() -> PatchSet {
        PatchSet(
            baseRecipeId: recipeId,
            baseRecipeVersion: 3,
            patches: [
                .updateIngredient(id: ingPaprikaId, text: "1 tbsp smoked paprika"),
                .addStep(parentId: nil, afterId: stepDredgeId,
                         text: "Spray the tops lightly with oil so the panko browns",
                         preassignedId: nil),
            ],
            summary: "Spicier, and a step to help the crust brown"
        )
    }
}
#endif
