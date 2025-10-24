import Foundation
import TelemetryDeck

class Analytics {
    static let shared = Analytics()

    // SettingsView の @AppStorage("analytics_disabled") と連動
    private static var isEnabled: Bool {
        return !UserDefaults.standard.bool(forKey: "analytics_disabled")
    }

    private init() {
        // TelemetryDeck 初期化
        let config = TelemetryDeck.Config(appID: "A218226F-FD2C-45E2-A0D9-FB6AA7062583")
        TelemetryDeck.initialize(config: config)
    }

    static func configure() {
        _ = shared
    }

    // --- イベント送信は必ずこの窓口を経由 ---
    static func track(_ eventName: String, parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        TelemetryDeck.signal(eventName, parameters: parameters)
    }

    // メニュー選択（SessionType）
    static func trackMenuSelected<T>(session: T) where T: RawRepresentable, T.RawValue == String {
        let sessionName = session.rawValue  // "Quick Flow" or "Deep Flow"
        track("menu_selected", parameters: ["session_type": sessionName])
    }

    // ゲーム完了
    static func trackGameCompleted(session: SessionType, avgMs: Int) {
        let avgMsRange: String
        if avgMs < 250 {
            avgMsRange = "<250ms"
        } else if avgMs <= 350 {
            avgMsRange = "250-350ms"
        } else {
            avgMsRange = "350ms+"
        }
        let mode = session.rawValue  // "Quick Flow" or "Deep Flow"
        track("game_completed", parameters: [
            "mode": mode,
            "avg_ms_range": avgMsRange
        ])
    }

    // トライアル状態
    static func trackTrialStatus(isActive: Bool, daysRemaining: Int) {
        track("trial_status", parameters: [
            "is_active": isActive ? "true" : "false",
            "days_remaining": "\(daysRemaining)"
        ])
    }

    // Pro 購入
    static func trackProPurchase() {
        track("pro_purchased")
    }
}
