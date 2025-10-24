// PurchaseManager.swift
import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let proProductID = "com.yourdomain.flowin.pro"   // ←あなたのIDに変更

    @Published var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []

    // 代わりに UserDefaults を使う
    private var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "isPro") }
        set { UserDefaults.standard.set(newValue, forKey: "isPro") }
    }
    // 公開状態
    var isProUnlocked: Bool { purchasedIDs.contains(Self.proProductID) || isPro }

    init() {
        Task {
            await refresh()
        }
    }

    // まとめて初期化
    func refresh() async {
        await loadProducts()
        await updateCustomerProductStatus()
    }

    // 商品取得
    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.proProductID])
        } catch {
            print("❌ loadProducts error: \(error)")
        }
    }

    // 所有状況の反映（復元含む）
    func updateCustomerProductStatus() async {
        purchasedIDs.removeAll()
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == Self.proProductID,
                   transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("❌ verification error: \(error)")
            }
        }
        // 既存の isPro を同期（保持している場合も unlock 扱い）
        if isProUnlocked != isPro { isPro = isProUnlocked }
    }

    // 購入
    func purchasePro() async throws {
        guard let product = products.first(where: { $0.id == Self.proProductID }) else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            purchasedIDs.insert(transaction.productID)
            // 既存の AppStorage とも同期
            isPro = true
            Analytics.trackProPurchase()
            await transaction.finish()

        case .userCancelled:
            throw PurchaseError.userCancelled

        case .pending:
            // ファミリー承認など
            throw PurchaseError.pending

        @unknown default:
            throw PurchaseError.unknown
        }
    }

    // 復元（トランザクション再同期）
    func restore() async throws {
        try await AppStore.sync()
        await updateCustomerProductStatus()
    }

    // 検証ヘルパ
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    enum PurchaseError: Error, LocalizedError {
        case productNotFound, userCancelled, pending, unverified, unknown
        var errorDescription: String? {
            switch self {
            case .productNotFound: return "商品が見つかりませんでした。"
            case .userCancelled:   return "購入をキャンセルしました。"
            case .pending:         return "承認待ちです。"
            case .unverified:      return "トランザクションの検証に失敗しました。"
            case .unknown:         return "不明なエラーです。"
            }
        }
    }
}
