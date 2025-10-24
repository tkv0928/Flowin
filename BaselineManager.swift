import Foundation

class BaselineManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let baselineKey = "baseline_ms_v1"
    private let sessionCountKey = "session_count_v1"
    
    // デフォルトベースライン（ミリ秒）
    private let defaultBaselineMs: Double = 300.0
    
    // EMA更新パラメータ
    private let alpha: Double = 0.2
    
    var currentBaseline: Double {
        if sessionCount == 0 {
            return defaultBaselineMs
        }
        return userDefaults.double(forKey: baselineKey)
    }
    
    private var sessionCount: Int {
        userDefaults.integer(forKey: sessionCountKey)
    }
    
    func sanitizeRTs(_ rawRTs: [TimeInterval]) -> [TimeInterval] {
        return rawRTs.filter { $0 >= 0.120 && $0 <= 1.500 }
    }
    
    func updateBaseline(with sessionAverage: Double) {
        let count = sessionCount
        
        if count == 0 {
            // 1セッション目：デフォルトベースライン使用、カウントのみ更新
            userDefaults.set(1, forKey: sessionCountKey)
        } else if count == 1 {
            // 2セッション目：初回学習開始
            userDefaults.set(sessionAverage, forKey: baselineKey)
            userDefaults.set(2, forKey: sessionCountKey)
        } else if count == 2 {
            // 3セッション目：3セッションの中央値で初期化
            let stored = userDefaults.double(forKey: baselineKey)
            let values = [defaultBaselineMs, stored, sessionAverage].sorted()
            let medianBaseline = values[1] // 中央値
            userDefaults.set(medianBaseline, forKey: baselineKey)
            userDefaults.set(3, forKey: sessionCountKey)
        } else {
            // 4セッション目以降：EMA更新
            let currentBaseline = userDefaults.double(forKey: baselineKey)
            let newBaseline = alpha * sessionAverage + (1.0 - alpha) * currentBaseline
            userDefaults.set(newBaseline, forKey: baselineKey)
            userDefaults.set(count + 1, forKey: sessionCountKey)
        }
    }
    
    func getFlowBand() -> (lower: Double, upper: Double) {
        let baseline = currentBaseline
        // 上位20%の帯域を計算（80%-100%の範囲）
        let lower = baseline * 0.8  // 80%
        let upper = baseline * 1.0  // 100%（ベースライン）
        return (lower: lower, upper: upper)
    }
    
    func isValidSession(validTapCount: Int) -> Bool {
        return validTapCount >= 5
    }
    
    func evaluatePerformance(_ sessionAverage: Double) -> FlowEvaluation {
        let band = getFlowBand()
        
        if sessionAverage <= band.lower {
            return .exceptional  // 上位20%以上
        } else if sessionAverage <= band.upper {
            return .good  // 上位20%帯域
        } else if sessionAverage <= currentBaseline * 1.2 {
            return .average  // 平均的
        } else {
            return .needsFocus  // 注意散漫
        }
    }
}

enum FlowEvaluation {
    case exceptional    // 攻めすぎ
    case good          // フロー寄り
    case average       // 平均的
    case needsFocus    // 注意散漫
    
    func displayName(isJapanese: Bool) -> String {
        switch self {
        case .exceptional:
            return isJapanese ? "優秀" : "Exceptional"
        case .good:
            return isJapanese ? "フロー寄り" : "Good Focus"
        case .average:
            return isJapanese ? "平均的" : "Average"
        case .needsFocus:
            return isJapanese ? "要集中" : "Needs Focus"
        }
    }
    
    func subtitle(isJapanese: Bool) -> String {
        switch self {
        case .exceptional:
            return isJapanese ? "素晴らしい集中力！" : "Outstanding performance!"
        case .good:
            return isJapanese ? "良い集中状態です" : "Good focus maintained"
        case .average:
            return isJapanese ? "標準的なパフォーマンス" : "Standard performance"
        case .needsFocus:
            return isJapanese ? "集中力を高めましょう" : "Focus needs improvement"
        }
    }
}
