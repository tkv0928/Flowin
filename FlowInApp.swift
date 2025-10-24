import SwiftUI

@main
struct FlowInApp: App {
    // AppDelegate を SwiftUI App にアダプト
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var trialManager = TrialManager()
    @StateObject private var purchaseManager = PurchaseManager()   // ← 追加

    init() {
        // Analytics初期化
        Analytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(trialManager)
                .environmentObject(purchaseManager)                 // ← 追加
                .onAppear {
                    trialManager.checkTrialStatus()
                    if !trialManager.isTrialActive {
                        trialManager.endTrial()
                    }
                    
                    // トライアル状況をトラッキング
                    Analytics.trackTrialStatus(
                        isActive: trialManager.isTrialActive,
                        daysRemaining: trialManager.daysRemaining
                    )
                }
        }
    }
}
