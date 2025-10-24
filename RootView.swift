import SwiftUI
import GoogleMobileAds

struct RootView: View {
    @State private var pushGame = false
    @State private var selectedMode: SessionType = .quick  // V0.5: 初期状態Quick
    @State private var showProPurchase = false
    @State private var showSettings = false
    @EnvironmentObject var trialManager: TrialManager

    @AppStorage("isPro") private var isPro: Bool = false
    @AppStorage("forceLang") private var forceLang: String = "auto"

    @StateObject private var results = ResultsStore()

    private var isJapanese: Bool {
        switch forceLang {
        case "ja": return true
        case "en": return false
        default: return Locale.current.language.languageCode?.identifier == "ja"
        }
    }
    
    private var hasProFeatures: Bool {
        return trialManager.isTrialActive || isPro
    }
    
    // V0.5: モード別ベストスコア
    private var bestScore: Int {
        let key = selectedMode == .quick ? "bestScoreQuick" : "bestScoreDeep"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    // V0.5: モード別平均反応速度（過去10回）
    private var avgResponse: Int {
        return results.getRecentAverage(sessionType: selectedMode, field: \.averageMs)
    }
    
    // V0.5: Deep専用統計
    private var flowTimeAvg: Double {
        guard selectedMode == .deep else { return 0.0 }
        return results.getRecentAverageDouble(sessionType: .deep, field: \.flowTime)
    }
    
    private var missRateAvg: Double {
        guard selectedMode == .deep else { return 0.0 }
        return results.getRecentAverageDouble(sessionType: .deep, field: \.missRate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.white, .white.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    // V0.5: 新キャッチコピー
                    VStack(spacing: 4) {
                        Text("FlowIn")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                        Text("Leave the noise. Enter the Zone.")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // V0.5: トライアル状況表示
                    if trialManager.isTrialActive {
                        Text(isJapanese
                             ? "トライアル中：残り\(trialManager.daysRemaining)日"
                             : "Trial: \(trialManager.daysRemaining) days left")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // V0.5: Quick/Deepセグメントタブ
                    Picker("", selection: $selectedMode) {
                        Text("Quick Flow").tag(SessionType.quick)
                        Text("Deep Flow").tag(SessionType.deep)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    
                    // V0.5: モード説明
                    Text(selectedMode == .quick ?
                         (isJapanese ? "スコアと平均反応速度を計測します。" : "Measure your score and average reaction speed.") :
                         (isJapanese ? "さらにフロータイムや誤タップ率も計測します。" : "Measure your flow time and mistake rate for deeper analysis."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // V0.55: 統計表示エリア（シンプル化）
                    VStack(spacing: 12) {
                        StatRow(title: isJapanese ? "ベストスコア" : "Best Score",
                               value: bestScore > 0 ? "\(bestScore) pts" : (isJapanese ? "未計測" : "—"))
                        
                        StatRow(title: isJapanese ? "平均反応速度" : "Average Response",
                               value: avgResponse > 0 ? "\(avgResponse) ms" : (isJapanese ? "未計測" : "—"))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // V0.5: グラフ表示（Pro版のみ）
                    if hasProFeatures {
                        HistoryView(store: results, sessionType: selectedMode, isJapanese: isJapanese)
                            .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 10) {
                            HStack {
                                Text(isJapanese ? "履歴 / 統計" : "History / Stats").font(.footnote)
                                Spacer()
                                Button {
                                    showProPurchase = true
                                } label: {
                                    Label(isJapanese ? "Proで解放" : "Unlock with Pro", systemImage: "lock.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .frame(height: 72)
                                .overlay(
                                    HStack {
                                        Image(systemName: "chart.xyaxis.line").imageScale(.large)
                                        Text(isJapanese ? "過去10回の推移グラフ（Pro）" : "Last 10 sessions graph (Pro)")
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                )
                                .opacity(0.6)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()

                    // V0.5: スタートボタン（モード連動）
                    Button {
                        Haptics.play(.soft)
                        Analytics.trackMenuSelected(session: selectedMode)
                        pushGame = true
                    } label: {
                        Text(selectedMode == .quick ?
                             (isJapanese ? "30秒で開始" : "Start 30-Second Session") :
                             (isJapanese ? "60秒で開始" : "Start 60-Second Session"))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    // V0.5: 広告バナー（無料版）
                    if !hasProFeatures {
                        AdBannerView()
                            .frame(height: 50)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.top, 30)
            }
            .navigationBarBackButtonHidden()
            .navigationDestination(isPresented: $pushGame) {
                GridGameView(
                    sessionType: selectedMode,
                    langOverride: (forceLang == "auto" ? nil : forceLang),
                    debugHUD: false,
                    onFinish: { score, maxCombo, avgMs in
                        // ベストスコア更新はResultsStore内で処理
                    }
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
#if DEBUG
                    Button {
                        isPro.toggle()
                    } label: {
                        Text(isPro ? "PRO" : "FREE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(isPro ? .black : .gray.opacity(0.2))
                            .foregroundStyle(isPro ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    Button {
                        forceLang = (forceLang == "auto" ? "ja" : (forceLang == "ja" ? "en" : "auto"))
                    } label: {
                        Text(forceLang.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.gray.opacity(0.15))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                    Menu {
                        Button("今日に戻す (0d)") { trialManager.setTrialOffset(days: 0) }
                        Button("+1日") { trialManager.bumpTrialOffset(1) }
                        Button("+3日") { trialManager.bumpTrialOffset(3) }
                        Button("+7日") { trialManager.bumpTrialOffset(7) }
                        Divider()
                        Button("-1日") { trialManager.bumpTrialOffset(-1) }
                    } label: {
                        let d = trialManager.trialOffsetDays
                        Text(d == 0 ? "TIME" : "TIME \(d > 0 ? "+\(d)d" : "\(d)d")")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
#endif
                }
            }
            .sheet(isPresented: $showProPurchase) {
                ProPurchaseView(isJapanese: isJapanese)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(isJapanese ? "トライアル期間終了" : "Trial Period Ended", isPresented: $trialManager.shouldShowTrialEndNotice) {
                Button(isJapanese ? "Pro版を購入" : "Purchase Pro") {
                    trialManager.dismissTrialEndNotice()
                    showProPurchase = true
                }
                Button(isJapanese ? "無料版で続ける" : "Continue Free") {
                    trialManager.dismissTrialEndNotice()
                }
            } message: {
                Text(isJapanese
                     ? "Pro機能をお試しいただき、ありがとうございました。引き続き無料版をお楽しみください。"
                     : "Thank you for trying Pro features. You can continue using the free version.")
            }
        }
    }
}

// MARK: - 統計行コンポーネント

private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - 広告バナー

struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = "ca-app-pub-7027928626348675/9357825001"
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            banner.rootViewController = window.rootViewController
        }
        
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
