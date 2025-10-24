import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var store: ResultsStore
    let sessionType: SessionType
    let isJapanese: Bool
    
    // V0.55: 第1グラフ切り替え
    @State private var mainMetricTab: MainMetric = .score
    
    // V0.55: Deep専用の第2グラフ切り替え
    @State private var deepMetricTab: DeepMetric = .flowTime
    
    enum MainMetric: String, CaseIterable {
        case score = "Score"
        case avgResponse = "Avg Response"
        
        var displayName: String {
            switch self {
            case .score: return "Score"
            case .avgResponse: return "Avg Response"
            }
        }
        
        func displayNameJapanese() -> String {
            switch self {
            case .score: return "スコア"
            case .avgResponse: return "平均反応速度"
            }
        }
    }
    
    enum DeepMetric: String, CaseIterable {
        case flowTime = "Flow Time"
        case missRate = "Miss Rate"
        
        var displayName: String {
            switch self {
            case .flowTime: return "Flow Time"
            case .missRate: return "Miss Rate"
            }
        }
        
        func displayNameJapanese() -> String {
            switch self {
            case .flowTime: return "フロー時間"
            case .missRate: return "誤タップ率"
            }
        }
    }
    
    // V0.55: モード別データフィルタ（過去10回）
    private var filteredItems: [RunResult] {
        store.items
            .filter { $0.sessionType == sessionType }
            .sorted(by: { $0.date < $1.date })
            .suffix(10)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // V0.55: ヘッダー削除（左上「履歴/統計」、右上「最高スコア」削除）
            
            if filteredItems.isEmpty {
                // データなし表示
                VStack {
                    Text(isJapanese ? "データがありません" : "No data yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else {
                // V0.55: 第1グラフ切り替えボタン
                HStack {
                    ForEach(MainMetric.allCases, id: \.self) { metric in
                        Button {
                            mainMetricTab = metric
                        } label: {
                            Text(isJapanese ? metric.displayNameJapanese() : metric.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(mainMetricTab == metric ? Color.accentColor.opacity(0.2) : Color.clear)
                                .foregroundStyle(mainMetricTab == metric ? .primary : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                
                // V0.55: 選択されたメトリックのグラフ（高さ縮小）
                if mainMetricTab == .score {
                    Chart(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Session", index + 1),
                            y: .value("Score", item.score)
                        )
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 120)  // ← この高さをQuickとDeep両方で統一
                    .chartYScale(domain: .automatic(includesZero: true))  // 自動調整に戻す
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5))
                    }
                } else {
                    Chart(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Session", index + 1),
                            y: .value("Avg Response", item.averageMs)
                        )
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color("#8658E9"))
                    }
                    .frame(height: 120)  // V0.55: 140pt → 120pt
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5))
                    }
                }
                
                // V0.55: Deep専用の第2グラフ
                if sessionType == .deep {
                    Divider()
                    
                    // グラフ切り替えボタン
                    HStack {
                        ForEach(DeepMetric.allCases, id: \.self) { metric in
                            Button {
                                deepMetricTab = metric
                            } label: {
                                Text(isJapanese ? metric.displayNameJapanese() : metric.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(deepMetricTab == metric ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .foregroundStyle(deepMetricTab == metric ? .primary : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                    
                    // 選択されたメトリックのグラフ
                    if deepMetricTab == .flowTime {
                        Chart(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                            LineMark(
                                x: .value("Session", index + 1),
                                y: .value("Flow Time", item.flowTime)
                            )
                            .symbol(Circle())
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color("#9C6BFF"))//2つめのグラフ　ライン1
                        }
                        .frame(height: 100)
                        .chartYScale(domain: .automatic(includesZero: true))
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                    } else {
                        Chart(Array(filteredItems.enumerated()), id: \.offset) { index, item in
                            LineMark(
                                x: .value("Session", index + 1),
                                y: .value("Miss Rate", item.missRate)
                            )
                            .symbol(Circle())
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color("#8658E9"))//2つめのグラフ　ライン2
                        }
                        .frame(height: 100)
                        .chartYScale(domain: .automatic(includesZero: true))
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .padding(.vertical, 8)  // 上下の余白を小さく
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
