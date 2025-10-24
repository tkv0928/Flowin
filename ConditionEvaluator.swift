import Foundation

enum FatigueLevel {
    case good
    case mild    // 20%以上遅い
    case severe  // 30%以上遅い
    
    var emoji: String {
        switch self {
        case .good: return "🟢"
        case .mild: return "🟡"
        case .severe: return "🔴"
        }
    }
    
    var statusText: (japanese: String, english: String) {
        switch self {
        case .good:
            return ("好調", "Good")
        case .mild:
            return ("軽度疲労", "Mild Fatigue")
        case .severe:
            return ("要休息", "Need Rest")
        }
    }
}

struct ConditionReport {
    let todayAverage: Double
    let baselineAverage: Double
    let fatigueLevel: FatigueLevel
    let percentageChange: Int
    let message: String
    let isValid: Bool
}

class ConditionEvaluator {
    static func evaluateCondition(resultsStore: ResultsStore, isJapanese: Bool) -> ConditionReport? {
        let today = Calendar.current.startOfDay(for: Date())
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today) ?? today
        
        // 今日のデータ（有効なもののみ）
        let todayResults = resultsStore.items.filter { result in
            Calendar.current.isDate(result.date, inSameDayAs: today) && result.averageMs > 120 && result.averageMs < 1500
        }
        
        // 過去3日間のデータ（今日を除く）
        let pastResults = resultsStore.items.filter { result in
            result.date >= threeDaysAgo && result.date < today && result.averageMs > 120 && result.averageMs < 1500
        }
        
        // 最低試行数チェック
        guard todayResults.count >= 5 else {
            return ConditionReport(
                todayAverage: 0,
                baselineAverage: 0,
                fatigueLevel: .good,
                percentageChange: 0,
                message: isJapanese ? "本日5試行でレポート表示されます" : "Complete 5 sessions for today's report",
                isValid: false
            )
        }
        
        guard pastResults.count >= 3 else {
            return ConditionReport(
                todayAverage: 0,
                baselineAverage: 0,
                fatigueLevel: .good,
                percentageChange: 0,
                message: isJapanese ? "データ収集中..." : "Collecting baseline data...",
                isValid: false
            )
        }
        
        // 平均計算
        let todayAvg = Double(todayResults.map { $0.averageMs }.reduce(0, +)) / Double(todayResults.count)
        let pastAvg = Double(pastResults.map { $0.averageMs }.reduce(0, +)) / Double(pastResults.count)
        
        // 疲労レベル判定
        let changePercentage = ((todayAvg - pastAvg) / pastAvg) * 100
        let fatigueLevel: FatigueLevel
        
        if changePercentage >= 30 {
            fatigueLevel = .severe
        } else if changePercentage >= 20 {
            fatigueLevel = .mild
        } else {
            fatigueLevel = .good
        }
        
        // メッセージ選択
        let message = selectMessage(for: fatigueLevel, isJapanese: isJapanese)
        
        return ConditionReport(
            todayAverage: todayAvg,
            baselineAverage: pastAvg,
            fatigueLevel: fatigueLevel,
            percentageChange: Int(changePercentage.rounded()),
            message: message,
            isValid: true
        )
    }
    
    private static func selectMessage(for level: FatigueLevel, isJapanese: Bool) -> String {
        let messages: [String]
        
        switch level {
        case .good:
            messages = isJapanese ? goodMessagesJA : goodMessagesEN
        case .mild:
            messages = isJapanese ? mildMessagesJA : mildMessagesEN
        case .severe:
            messages = isJapanese ? severeMessagesJA : severeMessagesEN
        }
        
        // ハッシュベース固定選択（同じ日は同じメッセージ）
        let today = Calendar.current.startOfDay(for: Date())
        let dayHash = Int(today.timeIntervalSince1970 / 86400) // 日単位のハッシュ
        let messageIndex = abs(dayHash) % messages.count
        
        return messages[messageIndex]
    }
    
    // メッセージ配列（好調時用）
    private static let goodMessagesJA = [
        "今日の集中力は絶好調です！",
        "反応速度が安定しています。",
        "集中状態を維持できています。",
        "良いリズムで進んでいます。",
        "今日は調子が良いようです。"
    ]
    
    private static let goodMessagesEN = [
        "Your focus is excellent today!",
        "Reaction speed is stable.",
        "Maintaining good concentration.",
        "You're in a good rhythm.",
        "Performance looks great today."
    ]
    
    // 軽度疲労メッセージ
    private static let mildMessagesJA = [
        "集中が少し落ちていますね。休憩も力になりますよ。",
        "今日は反応がわずかに遅めです。気分転換してみましょう。",
        "集中力が揺らぎ始めています。軽く体を動かしてみませんか。",
        "リズムが少し乱れています。深呼吸で整えてみましょう。",
        "反応が落ち着いてきました。次の試行に向けて休息を。",
        "小さな疲労の兆しがあります。短い休憩がおすすめです。",
        "集中の波が下がり気味です。切り替えのタイミングかもしれません。",
        "少し視界がぼやけているようです。目を閉じて休んでみては？",
        "反応の速さが安定していません。リフレッシュしましょう。",
        "集中が持続しにくくなっています。休憩で回復できます。",
        "頭の回転がゆるやかになっています。水分補給をどうぞ。",
        "集中ゾーンから少し外れています。無理に続けなくても大丈夫。",
        "軽い疲れを感知しました。ストレッチで整えましょう。",
        "思考がわずかに重いようです。気分転換を。",
        "集中のリズムが崩れかけています。短時間の休息を。",
        "反応が少し遅れています。落ち着いて次へ進みましょう。",
        "小休止でまた集中力を取り戻せます。",
        "集中が散りやすい状態です。5分だけ休んでみましょう。",
        "集中度が低下傾向です。切り替えが有効です。",
        "疲れが積み重なり始めています。ここで一度休憩を。"
    ]
    
    private static let mildMessagesEN = [
        "Your focus is slightly lower today. A short break can help.",
        "Reaction time is a bit slower. Try refreshing yourself.",
        "Concentration is wavering. Stretch your body for a moment.",
        "Rhythm is a little off. Deep breaths might restore balance.",
        "Responses are calming down. Pause before the next attempt.",
        "Early signs of fatigue detected. A brief rest is recommended.",
        "Focus is dipping. This could be a good time to reset.",
        "Vision may feel tired. Close your eyes briefly to recover.",
        "Reaction speed is unstable. Time to refresh.",
        "Concentration is harder to sustain. Rest will bring it back.",
        "Thinking feels slower. Hydration might help.",
        "You're slipping out of the flow. Don't push yourself.",
        "Light fatigue detected. Stretching may restore energy.",
        "Thoughts seem heavy. Take a short break.",
        "Focus rhythm is off. Quick rest advised.",
        "Reactions are delayed. Stay calm and proceed.",
        "A short pause can reset your concentration.",
        "Focus scatters easily now. Try a 5-minute rest.",
        "Your focus is declining. Switching gears can help.",
        "Accumulating fatigue detected. Rest before continuing."
    ]
    
    // 重度疲労メッセージ
    private static let severeMessagesJA = [
        "反応が大きく遅れています。今日はゆっくり休みましょう。",
        "明らかな疲労が見られます。体と心をいたわる時間を。",
        "集中が大きく落ちています。深い休息をおすすめします。",
        "反応の精度が崩れています。今日はここまでにしましょう。",
        "疲労度が高いようです。睡眠をしっかりと。",
        "集中力の限界が近いです。無理をせず休養を。",
        "今日はもう十分です。おつかれさまでした。",
        "集中ゾーンから遠ざかっています。明日に備えましょう。",
        "疲れが顕著です。リカバリーを優先してください。",
        "反応が追いついていません。ここは休息のサインです。",
        "頭と体の両方に疲労が溜まっています。ゆっくり過ごしましょう。",
        "集中の限界を超えています。今日は無理しないで。",
        "疲労度が高い状態です。あたたかい飲み物でリラックスを。",
        "集中力が持続していません。休息が必要です。",
        "反応速度が大幅に低下しています。深呼吸と休養を。",
        "疲れがはっきりと表れています。お大事にしてください。",
        "集中が乱れています。今日はしっかり休みましょう。",
        "疲労が蓄積しています。リカバリーが最優先です。",
        "大きな疲れが見られます。ここで区切って休養を。",
        "集中の限界を越えました。今は休むことが成果に繋がります。"
    ]
    
    private static let severeMessagesEN = [
        "Your reactions slowed significantly. Time to rest.",
        "Clear fatigue is showing. Take care of your mind and body.",
        "Focus has dropped noticeably. Deep rest is recommended.",
        "Accuracy is breaking down. End the session here.",
        "High fatigue detected. A good night's sleep is best.",
        "Focus is near its limit. Rest instead of pushing.",
        "You've done enough for today. Well done.",
        "Far from the flow state. Prepare for tomorrow.",
        "Fatigue is evident. Prioritize recovery.",
        "Reactions can't keep up. This is a sign to rest.",
        "Mental and physical fatigue both appear. Relax gently.",
        "Focus limit reached. Don't push further.",
        "High fatigue levels detected. A warm drink may help.",
        "Concentration no longer sustained. Rest is necessary.",
        "Reaction speed is greatly reduced. Take deep breaths and rest.",
        "Fatigue is very clear. Take good care of yourself.",
        "Focus is unstable. Rest fully today.",
        "Fatigue is accumulating. Recovery comes first.",
        "Heavy tiredness observed. Stop here and rest.",
        "Focus has exceeded its limit. Rest now to perform better later."
    ]
}
