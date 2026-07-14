import Foundation
import Observation
import StoreKit

enum AdPlacement: Sendable { case calendarSummary, earningsFooter, settings }
protocol AdProviding: Sendable { func contentIdentifier(for placement: AdPlacement) -> String? }
struct NullAdProvider: AdProviding { func contentIdentifier(for placement: AdPlacement) -> String? { nil } }
struct LocalHouseAdProvider: AdProviding { func contentIdentifier(for placement: AdPlacement) -> String? { "local.removeAds" } }

@Observable @MainActor final class EntitlementStore {
    var hasRemoveAdsEntitlement = false
    var knownExpirationDate: Date?
    var shouldShowAds: Bool { AppConfiguration.advertisingEnabled && !hasRemoveAdsEntitlement }
}

@MainActor protocol SubscriptionProviding {
    var products: [Product] { get }
    func load() async
    func purchase(_ product: Product) async throws
    func restore() async throws
}

@Observable @MainActor final class StoreKitSubscriptionService: SubscriptionProviding {
    private(set) var products: [Product] = []
    let entitlementStore: EntitlementStore
    private var updatesTask: Task<Void, Never>?

    init(entitlementStore: EntitlementStore) {
        self.entitlementStore = entitlementStore
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates { await self?.refreshEntitlements() }
        }
    }

    func load() async {
        products = (try? await Product.products(for: AppConfiguration.subscriptionProductIDs)) ?? []
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result, case .verified(let transaction) = verification {
            await transaction.finish(); await refreshEntitlements()
        }
    }

    func restore() async throws { try await AppStore.sync(); await refreshEntitlements() }

    private func refreshEntitlements() async {
        var entitled = false, expiration: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  AppConfiguration.subscriptionProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if transaction.expirationDate.map({ $0 > Date() }) ?? true { entitled = true; expiration = transaction.expirationDate }
        }
        entitlementStore.hasRemoveAdsEntitlement = entitled
        entitlementStore.knownExpirationDate = expiration
    }
}
