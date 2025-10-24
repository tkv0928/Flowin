import Foundation

struct Rank {
    let displayName: String
    let subtitle: String
    let fireworkIntensity: CGFloat
    let stars: Int  // V0.5: 星の数
}

enum Ranker {
    private static let humanReactionLimit = 120
    
    // V0.5: ランク通算カウント取得
    private static func getRankCount(for rankName: String) -> Int {
        let dict = UserDefaults.standard.dictionary(forKey: "rankCountDict") as? [String: Int] ?? [:]
        return dict[rankName] ?? 0
    }
    
    // V0.5: ランク通算カウント更新
    static func updateRankCount(for rankName: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "rankCountDict") as? [String: Int] ?? [:]
        dict[rankName, default: 0] += 1
        UserDefaults.standard.set(dict, forKey: "rankCountDict")
    }
    
    // V0.5: 星の数を計算
    private static func calculateStars(count: Int) -> Int {
        if count >= 100 { return 5 }
        if count >= 60 { return 4 }
        if count >= 25 { return 3 }
        if count >= 10 { return 2 }
        return 1
    }
    
    static func rank(forAverageMs ms: Int, langOverride: String? = nil) -> Rank {
        // エラー値の処理
        if ms < 0 {
            return errorRank(ms: ms, langOverride: langOverride)
        }
        
        // 人間の反応限界未満の異常値
        if ms < humanReactionLimit {
            return anomalyRank(ms: ms, langOverride: langOverride)
        }
        
        return normalRank(ms, langOverride: langOverride)
    }
    
    // 統一された言語判定関数
    private static func isJapanese(langOverride: String?) -> Bool {
        switch langOverride {
        case "ja": return true
        case "en": return false
        default: return Locale.current.language.languageCode?.identifier == "ja"
        }
    }
    
    // エラー値（計測不能）の処理
    private static func errorRank(ms: Int, langOverride: String?) -> Rank {
        let isJapanese = isJapanese(langOverride: langOverride)
        
        switch ms {
        case -1:
            return .init(
                displayName: isJapanese ? "評価不能" : "Insufficient Data",
                subtitle: isJapanese ? "もう少し続けてから再挑戦してください" : "Play longer for accurate measurement",
                fireworkIntensity: 0.0,
                stars: 0
            )
        case -2:
            return .init(
                displayName: isJapanese ? "計測異常" : "Measurement Error",
                subtitle: isJapanese ? "正常に計測できませんでした" : "Unable to measure accurately",
                fireworkIntensity: 0.0,
                stars: 0
            )
        default:
            return .init(
                displayName: isJapanese ? "エラー" : "Error",
                subtitle: isJapanese ? "計測エラーが発生しました" : "Measurement error occurred",
                fireworkIntensity: 0.0,
                stars: 0
            )
        }
    }
    
    // 異常値（人間の限界未満）の処理
    private static func anomalyRank(ms: Int, langOverride: String?) -> Rank {
        let isJapanese = isJapanese(langOverride: langOverride)
        
        return .init(
            displayName: isJapanese ? "計測異常" : "Anomalous",
            subtitle: isJapanese ?
                "人間の反応限界を超えた値です（\(ms)ms）" :
                "Below human reaction limit (\(ms)ms)",
            fireworkIntensity: 0.1,
            stars: 0
        )
    }
    
    // V0.5: 17段階ランクシステム
    private static func normalRank(_ ms: Int, langOverride: String?) -> Rank {
        let isJapanese = isJapanese(langOverride: langOverride)
        
        let (name, subtitle, intensity) = getRankData(ms: ms, isJapanese: isJapanese)
        let count = getRankCount(for: name)
        let stars = calculateStars(count: count)
        
        return .init(
            displayName: name,
            subtitle: subtitle,
            fireworkIntensity: intensity,
            stars: stars
        )
    }
    
    private static func getRankData(ms: Int, isJapanese: Bool) -> (String, String, CGFloat) {
        if isJapanese {
            switch ms {
            case ...220:
                return ("神速", "人間を超えた領域。思考より速い。", 1.0)
            case 221...260:
                return ("超人", "極限集中。まさにゾーンの中。", 0.95)
            case 261...280:
                return ("達人", "精密さと速さが完璧に融合。", 0.9)
            case 281...290:
                return ("エリート", "上位1％の鋭い集中力。", 0.85)
            case 291...300:
                return ("シニアマスター", "熟練の反射、静かな精度。", 0.8)
            case 301...310:
                return ("マスター", "安定して速い。信頼できる集中力。", 0.75)
            case 311...320:
                return ("アスリート", "トップ層の集中反応。身体が先に動く。", 0.7)
            case 321...330:
                return ("エキスパート", "経験と集中が噛み合った好調域。", 0.65)
            case 331...340:
                return ("アドバンス", "平均を大きく超える反応速度。", 0.6)
            case 341...350:
                return ("スタンダード", "しっかり集中できています。基準ライン。", 0.55)
            case 351...360:
                return ("ノーマル", "平常時の集中状態。まだ伸びしろあり。", 0.5)
            case 361...370:
                return ("スロー", "やや遅れ気味。リズムを取り戻そう。", 0.45)
            case 371...380:
                return ("レイジー", "注意が散ってきています。深呼吸を。", 0.4)
            case 381...400:
                return ("リカバリー", "回復期。焦らず整えていこう。", 0.35)
            case 401...450:
                return ("リトライ", "仕切り直し。集中の再起動を。", 0.3)
            case 451...500:
                return ("リカバリースロー", "疲労蓄積中。短い休息をおすすめ。", 0.25)
            default:
                return ("レストモード", "今日は無理せずリラックス。", 0.2)
            }
        } else {
            switch ms {
            case ...220:
                return ("Divine Speed", "Beyond human limits. Faster than thought.", 1.0)
            case 221...260:
                return ("Superhuman", "Peak focus. Deep in the zone.", 0.95)
            case 261...280:
                return ("Master", "Precision and speed in perfect harmony.", 0.9)
            case 281...290:
                return ("Elite", "Top 1% sharp concentration.", 0.85)
            case 291...300:
                return ("Senior Master", "Veteran reflexes, quiet precision.", 0.8)
            case 301...310:
                return ("Master", "Consistently fast. Reliable focus.", 0.75)
            case 311...320:
                return ("Athlete", "Elite reactions. Body moves first.", 0.7)
            case 321...330:
                return ("Expert", "Experience meets focus in peak form.", 0.65)
            case 331...340:
                return ("Advanced", "Well above average response speed.", 0.6)
            case 341...350:
                return ("Standard", "Good focus. Baseline level.", 0.55)
            case 351...360:
                return ("Normal", "Regular focus. Room to grow.", 0.5)
            case 361...370:
                return ("Slow", "Slightly delayed. Let's find your rhythm.", 0.45)
            case 371...380:
                return ("Lazy", "Attention drifting. Take a deep breath.", 0.4)
            case 381...400:
                return ("Recovery", "Recovery phase. Reset without rushing.", 0.35)
            case 401...450:
                return ("Retry", "Fresh start. Reboot your focus.", 0.3)
            case 451...500:
                return ("Slow Recovery", "Fatigue building. Short rest recommended.", 0.25)
            default:
                return ("Rest Mode", "Take it easy today. Rest well.", 0.2)
            }
        }
    }
}
