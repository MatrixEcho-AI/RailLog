import StoreKit

@Observable
final class StoreManager {
    private(set) var donationProduct: Product?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadDonationProduct() async {
        do {
            let products = try await Product.products(for: ["DONATION_1"])
            donationProduct = products.first
        } catch {
            print("Failed to load donation product: \(error)")
        }
    }

    func purchaseDonation() async -> Bool {
        guard let product = donationProduct else { return false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            return false
        }
    }
}
