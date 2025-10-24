import UIKit
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // ✅ あなたの“通っていた版”に合わせる
        MobileAds.shared.start { _ in
            // 初期化完了
        }

        #if DEBUG
        // ✅ Debugのみテスト端末指定（MobileAds API系）
        let cfg = MobileAds.shared.requestConfiguration
        cfg.testDeviceIdentifiers = ["6c28c01e90fe3d2c3fecb8fb9ebb5bf9"]   // ← kGADSimulatorID の実体

        // GADSimulatorID が無い環境があるので、確実な kGADSimulatorID を使用
        // cfg.testDeviceIdentifiers = [ kGADSimulatorID as String ]
        // 実機のハッシュIDを追加したい場合：
        // cfg.testDeviceIdentifiers?.append("YOUR_HASHED_DEVICE_ID")
        #endif

        return true
    }
}
