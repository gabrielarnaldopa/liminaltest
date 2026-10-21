import Foundation
import Observation
import StoreKit
import SwiftUI

/// Paying with Apple: the plans are App Store subscriptions (StoreKit 2).
/// A purchase, a renewal or a restored purchase turns the plan on in this app through `onActive`.
/// Each purchase carries the account's `appAccountToken`, so the server can match it when payments move there.
@MainActor
@Observable
final class Purchases {
    private(set) var products: [String: Product] = [:]
    private(set) var busy = false
    private(set) var loaded = false
    /// A sentence for the person after something went wrong or finished.
    var message: String?
    /// Apple confirmed a plan: the plan, whether it is the yearly one, until when, and the transaction.
    @ObservationIgnored var onActive: ((PlanKind, Bool, Date?, String) -> Void)?
    @ObservationIgnored private var updates: Task<Void, Never>?

    /// Starts listening to Apple once the app can turn plans on: renewals, purchases approved later
    /// (Ask to Buy) and purchases made on another device arrive here, and the current plan is checked.
    func start(onActive: @escaping (PlanKind, Bool, Date?, String) -> Void) {
        guard updates == nil else { return }
        self.onActive = onActive
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                _ = await self?.handle(result)
            }
        }
        Task { [weak self] in
            for await result in StoreKit.Transaction.currentEntitlements {
                _ = await self?.handle(result)
            }
        }
    }

    /// The App Store prices for the plans, in the person's own App Store.
    func load() async {
        guard !loaded else { return }
        do {
            let list = try await Product.products(for: PlanKind.productIDs)
            var found: [String: Product] = [:]
            for product in list { found[product.id] = product }
            products = found
            loaded = !found.isEmpty
        } catch {
            message = "No pudimos cargar los precios de Apple. Revisa tu conexión."
        }
    }

    func displayPrice(_ plan: PlanKind, annual: Bool) -> String? {
        guard let id = plan.productID(annual: annual) else { return nil }
        return products[id]?.displayPrice
    }

    /// Buys the plan with the person's Apple account. True when it went through.
    func buy(_ plan: PlanKind, annual: Bool, account: UUID?, using purchase: PurchaseAction) async -> Bool {
        guard let id = plan.productID(annual: annual) else { return false }
        if products[id] == nil { loaded = false; await load() }
        guard let product = products[id] else {
            message = "Este plan todavía no está a la venta en la App Store. Mientras tanto puedes pagar en la web."
            return false
        }
        busy = true
        defer { busy = false }
        do {
            var options: Set<Product.PurchaseOption> = []
            if let account { options.insert(.appAccountToken(account)) }
            switch try await purchase(product, options: options) {
            case .success(let verification):
                let ok = await handle(verification)
                if !ok { message = "Apple no pudo confirmar la compra. Si se cobró, toca Restaurar compras." }
                return ok
            case .pending:
                message = "Tu compra quedó pendiente de aprobación. Cuando Apple la apruebe, tu plan se activa solo."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            message = "Apple no pudo completar la compra. Inténtalo otra vez."
            return false
        }
    }

    /// Brings back plans bought with this Apple account, for example on a new iPhone.
    func restore() async {
        busy = true
        defer { busy = false }
        try? await StoreKit.AppStore.sync()
        var found = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if await handle(result) { found = true }
        }
        message = found ? "Listo: recuperamos tu plan." : "No encontramos planes comprados con esta cuenta de Apple."
    }

    /// Turns on a verified, current plan. Expired, refunded or unknown purchases do nothing.
    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else { return false }
        var active = false
        if transaction.revocationDate == nil,
           let match = PlanKind.from(productID: transaction.productID),
           (transaction.expirationDate ?? .distantFuture) > Date() {
            onActive?(match.plan, match.annual, transaction.expirationDate, String(transaction.id))
            active = true
        }
        await transaction.finish()
        return active
    }
}
