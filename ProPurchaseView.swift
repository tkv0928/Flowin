import SwiftUI
import StoreKit

struct ProPurchaseView: View {
    let isJapanese: Bool

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchase: PurchaseManager
    @State private var message: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(isJapanese ? "Pro を購入" : "Get Pro")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // iOSの互換性のため navigationBarTrailing を使用
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isJapanese ? "閉じる" : "Close") { dismiss() }
                    }
                }
                .task {
                    await purchase.refresh()
                    if purchase.isProUnlocked {
                        message = isJapanese ? "すでにProが有効です。" : "Pro is already unlocked."
                    }
                }
        }
    }

    // MARK: - Composed content
    private var content: some View {
        VStack(spacing: 16) {
            header
            descriptionText
            purchaseSection
                .padding(.horizontal)

            if let msg = message {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 24)
    }

    private var header: some View {
        Image(systemName: "star.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(.yellow)
    }

    private var descriptionText: some View {
        Text(isJapanese
             ? "履歴・統計の解放、広告非表示などの機能が利用できます。"
             : "Unlock history & stats and remove ads to keep your focus.")
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        let pro = purchase.products.first(where: { $0.id == PurchaseManager.proProductID })

        if let pro {
            buyButton(for: pro)
        } else {
            ProgressView().padding(.vertical, 14)
        }

        restoreButton
    }

    private func buyButton(for pro: Product) -> some View {
        Button {
            Task { await buy(pro) }
        } label: {
            Text(isJapanese ? "\(pro.displayPrice) で購入" : "Buy for \(pro.displayPrice)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // .background(.accent) は型推論が重くなることがあるので明示
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var restoreButton: some View {
        Button(isJapanese ? "購入を復元" : "Restore Purchases") {
            Task { await restore() }
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Actions
    private func buy(_ product: Product) async {
        do {
            try await purchase.purchasePro()
            message = isJapanese
                ? "購入が完了しました。ありがとうございます！"
                : "Purchase completed. Thank you!"
            dismiss()
        } catch let error as PurchaseManager.PurchaseError {
            message = error.localizedDescription
        } catch {
            message = isJapanese
                ? "購入に失敗しました：\(error.localizedDescription)"
                : "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func restore() async {
        do {
            try await purchase.restore()
            message = isJapanese ? "購入を復元しました。" : "Purchases restored."
            if purchase.isProUnlocked { dismiss() }
        } catch {
            message = isJapanese
                ? "復元に失敗しました：\(error.localizedDescription)"
                : "Restore failed: \(error.localizedDescription)"
        }
    }
}

// プレビュー
struct ProPurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        ProPurchaseView(isJapanese: true)
            .environmentObject(PurchaseManager())
        ProPurchaseView(isJapanese: false)
            .environmentObject(PurchaseManager())
    }
}
