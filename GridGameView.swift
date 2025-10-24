import SwiftUI
import SpriteKit
import UIKit

// このファイル専用の簡易カラー（他ファイルと衝突しないよう extension は使わない）
private func C(_ hex: String) -> Color {
    var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if h.hasPrefix("#") { h.removeFirst() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255.0
    let g = Double((rgb >> 8) & 0xFF) / 255.0
    let b = Double(rgb & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}

// テーマ定義（このファイル内のみ使用）
private struct Theme {
    // ブランド
    static let mainPurple = C("#B084FF")   // メインボタン等
    static let deepPurple = C("#9C6BFF")   // 文字/数値の強調
    static let lightPurple = C("#F2EDF9")  // 淡色背景・補助
    static let bgTop = C("#FFF8FF")        // 背景グラデ上部（ごく淡い）
    static let bgBottom = C("#F2EDF9")     // 背景グラデ下部（淡いラベンダー）
    static let panelStroke = C("#B084FF").opacity(0.25)
    static let panelFill: Material = .regularMaterial
}

struct GridGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var finishedScore: Int? = nil
    @State private var finishedMaxCombo: Int? = nil
    @State private var finishedAvgMs: Int? = nil
    @State private var finishedMissCount: Int? = nil
    @State private var finishedFlowTime: Double? = nil
    @State private var rank: Rank? = nil
    @State private var quote: Quote? = nil
    @State private var showActions = false
    @State private var sessionKey = UUID()
    @EnvironmentObject var trialManager: TrialManager

    let sessionType: SessionType
    let langOverride: String?
    let debugHUD: Bool
    var onFinish: (_ score: Int, _ maxCombo: Int, _ avgMs: Int)->Void

    @StateObject private var results = ResultsStore()

    init(sessionType: SessionType,
         langOverride: String? = nil,
         debugHUD: Bool = false,
         onFinish: @escaping (_ score: Int, _ maxCombo: Int, _ avgMs: Int)->Void) {
        self.sessionType = sessionType
        self.langOverride = langOverride
        self.debugHUD = debugHUD
        self.onFinish = onFinish
    }

    private func createScene() -> GridScene {
        let s = GridScene(size: CGSize(width: 430, height: 932),
                          sessionDuration: sessionType.duration,
                          sessionType: sessionType,
                          enableFlowDetection: (sessionType == .deep),
                          enableFlowDebug: debugHUD)
        s.scaleMode = .resizeFill

        // ゲーム終了コールバック
        s.onGameEnd = { score, maxCombo, avgMs, missCount, flowHitCount, flowEnterCount, flowTotalMs in
            DispatchQueue.main.async {
                finishedScore = score
                finishedMaxCombo = maxCombo
                finishedAvgMs = avgMs
                finishedMissCount = missCount
                finishedFlowTime = flowTotalMs / 1000.0  // 秒

                rank = Ranker.rank(forAverageMs: avgMs, langOverride: langOverride)
                quote = Quotes.random(langOverride: langOverride)
                onFinish(score, maxCombo, avgMs)

                // 保存（拡張データ含む）
                results.add(
                    score: score,
                    maxCombo: maxCombo,
                    avgMs: avgMs,
                    sessionType: sessionType,
                    missCount: missCount,
                    flowHitCount: flowHitCount,
                    flowEnterCount: flowEnterCount,
                    flowTotalMs: flowTotalMs
                )

                // Analytics
                Analytics.trackGameCompleted(session: sessionType, avgMs: avgMs)

                showActions = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.25)) { showActions = true }
                }
            }
        }
        return s
    }

    var body: some View {
        ZStack {
            // 背景グラデーション（淡いパープル）
            LinearGradient(
                colors: [Theme.bgTop, Theme.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // ゲーム画面
            SpriteView(scene: createScene(), preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .id(sessionKey)
                .ignoresSafeArea()

            // 結果オーバーレイ
            if let score = finishedScore,
               let maxCombo = finishedMaxCombo,
               let avgMs = finishedAvgMs,
               let rank = rank {

                FireworksView(intensity: rank.fireworkIntensity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ResultOverlay(
                    sessionType: sessionType,
                    rank: rank,
                    score: score,
                    maxCombo: maxCombo,
                    avgMs: avgMs,
                    missCount: finishedMissCount ?? 0,
                    flowTime: finishedFlowTime ?? 0.0,
                    quote: quote,
                    showActions: showActions,
                    langOverride: langOverride,
                    resultsStore: results,
                    hasProFeatures: trialManager.isTrialActive || UserDefaults.standard.bool(forKey: "isPro"),
                    onRetry: {
                        Haptics.play(.soft)
                        finishedScore = nil
                        finishedMaxCombo = nil
                        finishedAvgMs = nil
                        finishedMissCount = nil
                        finishedFlowTime = nil
                        self.rank = nil
                        self.quote = nil
                        self.sessionKey = UUID()
                    },
                    onTop: {
                        Haptics.play(.soft)
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - 結果オーバーレイ

private struct ResultOverlay: View {
    let sessionType: SessionType
    let rank: Rank
    let score: Int
    let maxCombo: Int
    let avgMs: Int
    let missCount: Int
    let flowTime: Double
    let quote: Quote?
    let showActions: Bool
    let langOverride: String?
    let resultsStore: ResultsStore
    let hasProFeatures: Bool
    var onRetry: () -> Void
    var onTop: () -> Void

    @State private var boom = false

    private var isJapanese: Bool {
        switch langOverride {
        case "ja": return true
        case "en": return false
        default: return Locale.current.language.languageCode?.identifier == "ja"
        }
    }

    // 誤タップ率
    private var missRate: Double {
        let totalTaps = (score / 2) + missCount
        return totalTaps > 0 ? (Double(missCount) / Double(totalTaps)) * 100.0 : 0.0
    }

    var body: some View {
        VStack(spacing: 18) {
            // モード表示
            Text(sessionType == .quick ?
                 (isJapanese ? "Quick Flow" : "Quick Flow") :
                 (isJapanese ? "Deep Flow" : "Deep Flow"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // ランク名＋星（紫グラデ文字）
            HStack(spacing: 6) {
                Text(rank.displayName)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.mainPurple, Theme.deepPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                if rank.stars > 0 {
                    Text(String(repeating: "⭐️", count: rank.stars))
                        .font(.title3)
                }
            }
            .scaleEffect(boom ? 1.0 : 0.7)
            .opacity(boom ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2)) {
                    boom = true
                }
                Haptics.play(.rigid)
            }

            Text(rank.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 20)

            // スコア・平均反応・最大コンボ（共通）
            VStack(spacing: 12) {
                MetricRow(
                    title: isJapanese ? "スコア" : "Score",
                    value: "\(score) pts",
                    valueColor: Theme.deepPurple
                )
                MetricRow(
                    title: isJapanese ? "平均反応速度" : "Average Response",
                    value: "\(avgMs) ms",
                    valueColor: Theme.deepPurple
                )
                MetricRow(
                    title: isJapanese ? "最大コンボ" : "Max Combo",
                    value: "\(maxCombo)",
                    valueColor: Theme.deepPurple
                )

                // Deep専用
                if sessionType == .deep {
                    MetricRow(
                        title: isJapanese ? "誤タップ率" : "Miss Rate",
                        value: String(format: "%.1f%%", missRate),
                        valueColor: Theme.deepPurple
                    )
                    MetricRow(
                        title: isJapanese ? "フロー時間" : "Flow Time",
                        value: String(format: "%.1f秒", flowTime),
                        valueColor: Theme.deepPurple
                    )
                }
            }

            Divider().padding(.horizontal, 20)

            // 名言
            if let q = quote {
                VStack(spacing: 6) {
                    Text("\"\(q.text)\"")
                        .multilineTextAlignment(.center)
                        .font(.body)
                    Text("— \(q.author)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider().padding(.horizontal, 20)

            // 労り文（Proのみ）
            if hasProFeatures {
                ConditionReportView(
                    resultsStore: resultsStore,
                    isJapanese: isJapanese
                )
            }

            if showActions {
                HStack(spacing: 12) {
                    Button {
                        Haptics.play(.soft)
                        onRetry()
                    } label: {
                        Text(isJapanese ? "もう一度" : "Retry")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.mainPurple)           // ← メイン紫
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        Haptics.play(.soft)
                        onTop()
                    } label: {
                        Text(isJapanese ? "トップへ" : "Top")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.lightPurple)          // ← 淡紫
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 6)

                // 広告（無料版のみ）
                if !hasProFeatures {
                    AdBannerView()
                        .frame(height: 50)
                        .padding(.top, 4)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.panelStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 6)
        )
        .padding(24)
    }
}

// MARK: - メトリック行

private struct MetricRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor) // 数値をパープルで強調
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - コンディションレポート（配色をパープル系へ）

private struct ConditionReportView: View {
    let resultsStore: ResultsStore
    let isJapanese: Bool

    var body: some View {
        if let report = ConditionEvaluator.evaluateCondition(resultsStore: resultsStore, isJapanese: isJapanese) {
            VStack(spacing: 8) {
                HStack {
                    Text(isJapanese ? "コンディションレポート" : "Condition Report")
                        .font(.headline)
                    Spacer()
                    Text("Pro")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                if report.isValid {
                    HStack {
                        Text(report.fatigueLevel.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(report.fatigueLevel.statusText.0) / \(report.fatigueLevel.statusText.1)")
                                .font(.subheadline.bold())
                            Text(isJapanese ? "過去3日比 \(report.percentageChange > 0 ? "+" : "")\(report.percentageChange)%"
                                            : "vs 3-day avg \(report.percentageChange > 0 ? "+" : "")\(report.percentageChange)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Text(report.message)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(report.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .background(Theme.lightPurple.opacity(0.5)) // ← 淡紫の背景
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.panelStroke, lineWidth: 1) // ← パープル系の枠
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - 花火（そのまま）

private struct FireworksView: UIViewRepresentable {
    let intensity: CGFloat
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        for i in 0..<3 {
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width/2,
                                              y: CGFloat(120 + i*200))
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width*0.8, height: 1)

            let cell = CAEmitterCell()
            cell.birthRate = 6 * Float(max(0.3, intensity))
            cell.lifetime = Float(2.0)
            cell.velocity = 220.0 + 200.0 * CGFloat(intensity)
            cell.velocityRange = 80.0
            cell.emissionLongitude = .pi
            cell.yAcceleration = 60.0
            cell.scale = 0.02 + 0.03 * CGFloat(intensity)
            cell.scaleRange = 0.01
            cell.color = UIColor.white.cgColor
            cell.contents = UIImage(systemName: "circle.fill")?
                .withTintColor(.white, renderingMode: .alwaysOriginal).cgImage

            emitter.emitterCells = [cell]
            v.layer.addSublayer(emitter)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { emitter.birthRate = 0 }
        }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
