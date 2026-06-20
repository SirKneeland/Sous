import Combine
import Foundation
import StoreKit

// MARK: - StoreKitManager
//
// Owns the StoreKit 2 purchase flow for the single Sous Pro monthly subscription.
// It does NOT own entitlement state — `AuthState` does. After any successful
// transaction (purchase, restore, or a background `Transaction.updates` event),
// the manager validates the signed transaction with the Sous backend and then asks
// `AuthState` to re-fetch entitlement. The backend is the source of truth; the
// client never grants access on its own.
//
// Testability: the two side-effecting dependencies (validate-with-backend and
// refresh-entitlement) are injected as closures, and the transaction-handling core
// lives in `handle(jwsRepresentation:)`. Tests drive that method directly with fake
// closures — no StoreKit, no network, no signed-in Apple account required.

@MainActor
final class StoreKitManager: ObservableObject {

    /// The auto-renewable subscription product id (configured in App Store Connect).
    static let monthlyProductID = "com.donutindustries.SousApp.pro.monthly"

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case validating
        case success
        case cancelled
        case failed(String)
    }

    @Published private(set) var product: Product?
    @Published private(set) var purchaseState: PurchaseState = .idle
    /// Display price string from StoreKit (authoritative), e.g. "$4.99". Falls back
    /// to a config-provided string when the product hasn't loaded.
    @Published private(set) var displayPrice: String?

    /// Validate a signed transaction with the backend. Throws on failure.
    private let validateReceipt: (String) async throws -> Void
    /// Re-fetch entitlement from the backend (AuthState.refresh). Settable so the
    /// app root can `attach(authState:)` after both objects are constructed.
    private var refreshEntitlement: () async -> Void

    private var updatesListener: Task<Void, Never>?

    // MARK: Init

    /// Designated init with injected side effects (used by tests).
    init(
        validateReceipt: @escaping (String) async throws -> Void,
        refreshEntitlement: @escaping () async -> Void = {},
        listenForTransactions: Bool = true
    ) {
        self.validateReceipt = validateReceipt
        self.refreshEntitlement = refreshEntitlement
        if listenForTransactions {
            updatesListener = makeUpdatesListener()
        }
    }

    /// Convenience init wiring the real backend client. `attach(authState:)` must be
    /// called once to connect entitlement refresh.
    convenience init(api: any SousAuthBackend = SousAPIClient.shared) {
        self.init(
            validateReceipt: { [weak api] jws in
                guard let api else { return }
                _ = try await api.validateReceipt(jws)
            },
            refreshEntitlement: {}
        )
    }

    /// Connect entitlement refresh to AuthState. Called once from the app root.
    func attach(authState: AuthState) {
        refreshEntitlement = { [weak authState] in await authState?.refresh() }
    }

    deinit {
        updatesListener?.cancel()
    }

    // MARK: Product loading

    /// Load the subscription product from StoreKit. Safe to call repeatedly.
    func loadProduct() async {
        do {
            print("[StoreKit] Fetching product: \(Self.monthlyProductID)")
            let products = try await Product.products(for: [Self.monthlyProductID])
            print("[StoreKit] Products returned: \(products.count)")
            for p in products {
                print("[StoreKit] Found product: \(p.id) — \(p.displayName)")
            }
            if let p = products.first {
                product = p
                displayPrice = p.displayPrice
            } else {
                print("[StoreKit] No products found for ID: \(Self.monthlyProductID)")
            }
        } catch {
            print("[StoreKit] Error fetching product: \(error)")
        }
    }

    // MARK: Purchase

    /// Begin a purchase of the monthly subscription. Updates `purchaseState`.
    func purchase() async {
        guard let product else {
            await loadProduct()
            guard product != nil else {
                purchaseState = .failed("Product unavailable. Please try again.")
                return
            }
            return await purchase()
        }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
            case .userCancelled:
                purchaseState = .cancelled
            case .pending:
                // Deferred (e.g. Ask to Buy). Entitlement updates arrive later via
                // the transaction listener.
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("Purchase failed. Please try again.")
        }
    }

    // MARK: Restore

    /// Restore purchases: sync with the App Store, then validate current entitlements.
    func restore() async {
        purchaseState = .validating
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            // `sync()` can throw if the user cancels the sign-in sheet; fall through
            // and still inspect any current entitlements.
        }
        var restoredAny = false
        for await result in Transaction.currentEntitlements {
            if await handle(verification: result, setState: false) {
                restoredAny = true
            }
        }
        await refreshEntitlement()
        purchaseState = restoredAny ? .success : .failed("No purchases to restore.")
    }

    // MARK: - Transaction handling

    /// Long-lived listener for transaction updates (renewals, refunds applied on
    /// other devices, Ask-to-Buy approvals). Each verified update is validated and
    /// the local entitlement refreshed.
    private func makeUpdatesListener() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update, setState: false)
            }
        }
    }

    /// Process a StoreKit verification result: confirm it is verified, hand the
    /// signed JWS to the backend, then refresh entitlement. Returns true on success.
    @discardableResult
    private func handle(
        verification: VerificationResult<Transaction>,
        setState: Bool = true
    ) async -> Bool {
        switch verification {
        case .verified(let transaction):
            let ok = await handle(jwsRepresentation: verification.jwsRepresentation)
            // Finishing tells StoreKit we've delivered the entitlement.
            await transaction.finish()
            if setState { purchaseState = ok ? .success : .failed("Could not verify your purchase.") }
            return ok
        case .unverified:
            // StoreKit could not verify the transaction locally — never trust it.
            if setState { purchaseState = .failed("Could not verify your purchase.") }
            return false
        }
    }

    /// The testable core: send the signed transaction JWS to the backend for
    /// server-side validation, then refresh entitlement. Returns true on success.
    @discardableResult
    func handle(jwsRepresentation: String) async -> Bool {
        if purchaseState == .purchasing { purchaseState = .validating }
        do {
            try await validateReceipt(jwsRepresentation)
        } catch {
            return false
        }
        await refreshEntitlement()
        return true
    }
}
