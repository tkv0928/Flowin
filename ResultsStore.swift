import Foundation

// V0.5: V4データ構造
struct RunResult: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var sessionType: SessionType
    
    // 共通項目
    var score: Int
    var averageMs: Int
    var maxCombo: Int
    
    // Deep専用（Quickの場合はデフォルト値）
    var flowTime: Double = 0.0        // フロー時間（秒）
    var missRate: Double = 0.0        // 誤タップ率（%）
    var missCount: Int = 0            // 誤タップ回数
    
    // V3から継続（将来分析用）
    var flowHitCount: Int = 0
    var flowEnterCount: Int = 0
    var flowTotalMs: Double = 0.0
    
    // ランク情報
    var rank: String = ""
    var rankStars: Int = 0
}

final class ResultsStore: ObservableObject {
    @Published var items: [RunResult] = [] { didSet { save() } }
    private let keyV4 = "results_v4"
    private let keyV3 = "results_v3"
    private let keyV2 = "results_v2"
    private let migrationKey = "migrated_to_v4"

    init() {
        // V4データを優先的に読み込み
        if let data = UserDefaults.standard.data(forKey: keyV4),
           let s = try? JSONDecoder().decode([RunResult].self, from: data) {
            items = s
            print("📊 Loaded \(items.count) items from V4")
        }
        // V3/V2データからのマイグレーション
        else if !UserDefaults.standard.bool(forKey: migrationKey) {
            migrateFromV3()
        } else {
            print("⚠️ No existing data found")
        }
        
        trimToOneYear()
        print("📊 ResultsStore V0.5 initialized with \(items.count) items")
    }
    
    // V3→V4マイグレーション
    private func migrateFromV3() {
        // V3データ構造（仮定）
        struct V3Result: Codable {
            var id: UUID?
            var date: Date
            var score: Int
            var bestCombo: Int
            var averageMs: Int
            var modeRaw: Int?
            var missCount: Int?
            var flowHitCount: Int?
            var flowEnterCount: Int?
            var flowTotalMs: Double?
        }
        
        var migratedItems: [RunResult] = []
        
        // V3データ読み込み試行
        if let data = UserDefaults.standard.data(forKey: keyV3),
           let v3Results = try? JSONDecoder().decode([V3Result].self, from: data) {
            
            for v3 in v3Results {
                // SessionType判定: V3ではPlayModeとSessionTypeが分離していたが、
                // ここではセッション時間で推定（60秒=quick, 180秒=deep）
                // 実際のV3データにSessionType情報がない場合はquickにフォールバック
                let sessionType: SessionType = .quick  // デフォルト
                
                let v4 = RunResult(
                    id: v3.id ?? UUID(),
                    date: v3.date,
                    sessionType: sessionType,
                    score: v3.score,
                    averageMs: v3.averageMs,
                    maxCombo: v3.bestCombo,
                    flowTime: (v3.flowTotalMs ?? 0) / 1000.0,
                    missRate: 0.0,  // V3では未計算
                    missCount: v3.missCount ?? 0,
                    flowHitCount: v3.flowHitCount ?? 0,
                    flowEnterCount: v3.flowEnterCount ?? 0,
                    flowTotalMs: v3.flowTotalMs ?? 0.0,
                    rank: "",
                    rankStars: 0
                )
                migratedItems.append(v4)
            }
            
            print("✅ Migrated \(migratedItems.count) items from V3 to V4")
        }
        // V2データ読み込み試行
        else if let data = UserDefaults.standard.data(forKey: keyV2),
                let v2Results = try? JSONDecoder().decode([V3Result].self, from: data) {
            
            for v2 in v2Results {
                let v4 = RunResult(
                    id: v2.id ?? UUID(),
                    date: v2.date,
                    sessionType: .quick,
                    score: v2.score,
                    averageMs: v2.averageMs,
                    maxCombo: v2.bestCombo
                )
                migratedItems.append(v4)
            }
            
            print("✅ Migrated \(migratedItems.count) items from V2 to V4")
        }
        
        items = migratedItems
        UserDefaults.standard.set(true, forKey: migrationKey)
        save()
    }

    // V0.5: 拡張パラメータ対応
    func add(score: Int,
             maxCombo: Int,
             avgMs: Int,
             sessionType: SessionType,
             missCount: Int = 0,
             flowHitCount: Int = 0,
             flowEnterCount: Int = 0,
             flowTotalMs: Double = 0.0) {
        
        // ランク判定
        let rankResult = Ranker.rank(forAverageMs: avgMs)
        Ranker.updateRankCount(for: rankResult.displayName)
        
        // フロー時間計算（秒）
        let flowTime = flowTotalMs / 1000.0
        
        // 誤タップ率計算（Deep専用）
        let missRate: Double
        if sessionType == .deep {
            let totalTaps = (score / 2) + missCount  // 概算
            missRate = totalTaps > 0 ? (Double(missCount) / Double(totalTaps)) * 100.0 : 0.0
        } else {
            missRate = 0.0
        }
        
        items.append(.init(
            date: Date(),
            sessionType: sessionType,
            score: score,
            averageMs: avgMs,
            maxCombo: maxCombo,
            flowTime: flowTime,
            missRate: missRate,
            missCount: missCount,
            flowHitCount: flowHitCount,
            flowEnterCount: flowEnterCount,
            flowTotalMs: flowTotalMs,
            rank: rankResult.displayName,
            rankStars: rankResult.stars
        ))
        
        // ベストスコア・ベストコンボ更新
        updateBestRecords(sessionType: sessionType, score: score, maxCombo: maxCombo)
        
        trimToOneYear()
    }
    
    // V0.5: モード別ベスト記録更新
    private func updateBestRecords(sessionType: SessionType, score: Int, maxCombo: Int) {
        let scoreKey = sessionType == .quick ? "bestScoreQuick" : "bestScoreDeep"
        let comboKey = sessionType == .quick ? "bestComboQuick" : "bestComboDeep"
        
        let currentBestScore = UserDefaults.standard.integer(forKey: scoreKey)
        let currentBestCombo = UserDefaults.standard.integer(forKey: comboKey)
        
        if score > currentBestScore {
            UserDefaults.standard.set(score, forKey: scoreKey)
        }
        if maxCombo > currentBestCombo {
            UserDefaults.standard.set(maxCombo, forKey: comboKey)
        }
    }
    
    // V0.5: モード別過去10回平均計算
    func getRecentAverage(sessionType: SessionType, field: KeyPath<RunResult, Int>) -> Int {
        let recentItems = items
            .filter { $0.sessionType == sessionType }
            .suffix(10)
        
        guard !recentItems.isEmpty else { return 0 }
        
        let sum = recentItems.map { $0[keyPath: field] }.reduce(0, +)
        return sum / recentItems.count
    }
    
    func getRecentAverageDouble(sessionType: SessionType, field: KeyPath<RunResult, Double>) -> Double {
        let recentItems = items
            .filter { $0.sessionType == sessionType }
            .suffix(10)
        
        guard !recentItems.isEmpty else { return 0.0 }
        
        let sum = recentItems.map { $0[keyPath: field] }.reduce(0.0, +)
        return sum / Double(recentItems.count)
    }

    private func trimToOneYear() {
        let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        items = items.filter { $0.date >= oneYearAgo }
        if items.count > 2000 { items.removeFirst(items.count - 2000) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: keyV4)
            print("💾 Saved \(items.count) items to ResultsStore V0.5")
        } else {
            print("❌ Failed to save ResultsStore")
        }
    }
}
