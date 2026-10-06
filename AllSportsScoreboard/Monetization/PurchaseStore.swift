import Foundation
import Observation
import StoreKit

/// The Remove Ads purchase, on StoreKit 2. Ownership is cached so ads stay off at launch,
/// even offline, and is re-checked against the App Store's signed entitlements.
@Observable
@MainActor
final class PurchaseStore {
    static let shared = PurchaseStore()

    enum Status: Equatable {
        case idle
        case working
        case pending
        case failed(String)
    }

    private(set) var adsRemoved: Bool {
        didSet { defaults.set(adsRemoved, forKey: Self.ownedKey) }
    }
    private(set) var product: Product?
    var status: Status = .idle

    /// The localized price ("$2.99", "2,99 €"), once the App Store has answered.
    var displayPrice: String? { product?.displayPrice }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private static let ownedKey = "purchases.adsRemoved"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adsRemoved = defaults.bool(forKey: Self.ownedKey)
    }

    /// Listens for purchases made elsewhere (Ask to Buy approvals, other devices, refunds)
    /// and refreshes what this Apple Account owns.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [AdConfig.removeAdsProductID]).first
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AdConfig.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        adsRemoved = owned
    }

    func purchase() async {
        guard !adsRemoved, status != .working else { return }
        status = .working
        await loadProduct()
        guard let product else {
            status = .failed("The App Store can't be reached right now. Check your connection and try again.")
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                status = adsRemoved ? .idle : .failed("The App Store couldn't confirm the purchase yet. Try Restore Purchases in a moment.")
            case .pending:
                status = .pending
            case .userCancelled:
                status = .idle
            @unknown default:
                status = .idle
            }
        } catch {
            status = .failed("The purchase didn't go through, and you haven't been charged.")
        }
    }

    func restore() async {
        guard status != .working else { return }
        status = .working
        try? await AppStore.sync()
        await refreshEntitlements()
        status = adsRemoved ? .idle : .failed("No Remove Ads purchase was found for this Apple Account.")
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == AdConfig.removeAdsProductID {
            adsRemoved = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
