import Foundation

enum SessionType: String, CaseIterable, Codable {
    case quick = "Quick Flow"
    case deep = "Deep Flow"
    
    var duration: TimeInterval {
        switch self {
        case .quick: return 30.0   // V0.55: 30秒
        case .deep: return 60.0    // V0.55: 60秒
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var displayNameJapanese: String {
        switch self {
        case .quick: return "Quick Flow"
        case .deep: return "Deep Flow"
        }
    }
    
    var description: String {
        switch self {
        case .quick: return "Measure your score and average reaction speed."
        case .deep: return "Measure your flow time and mistake rate for deeper analysis."
        }
    }
    
    var descriptionJapanese: String {
        switch self {
        case .quick: return "スコアと平均反応速度を計測します。"
        case .deep: return "さらにフロータイムや誤タップ率も計測します。"
        }
    }
    
    var startButtonText: String {
        switch self {
        case .quick: return "Start 60-Second Session"
        case .deep: return "Start 180-Second Session"
        }
    }
    
    var startButtonTextJapanese: String {
        switch self {
        case .quick: return "60秒で開始"
        case .deep: return "180秒で開始"
        }
    }
}
