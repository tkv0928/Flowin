import Foundation

class TrialManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let installDateKey = "install_date_v1"
    private let trialEndNoticeShownKey = "trial_notice_shown_v1"
    private let trialDays = 3
    
    @Published var shouldShowTrialEndNotice = false
    private func currentDate() -> Date {
        #if DEBUG
        let key = "dev.trialOffsetDays"
        let off = UserDefaults.standard.integer(forKey: key) // 未設定なら0
        return Calendar.current.date(byAdding: .day, value: off, to: Date())!
        #else
        return Date()
        #endif
    }
    var isTrialActive: Bool {
        guard let installDate = installDate else {
            // 初回起動時は現在日時を保存
            self.installDate = currentDate()
            return true
        }
        
        let daysPassed = Calendar.current.dateComponents([.day], from: installDate, to: currentDate()).day ?? 0
        return daysPassed < trialDays
    }
    
    var daysRemaining: Int {
        guard let installDate = installDate else { return trialDays }
        let daysPassed = Calendar.current.dateComponents([.day], from: installDate, to: currentDate()).day ?? 0
        return max(0, trialDays - daysPassed)
    }
    
    private var installDate: Date? {
        get {
            let timestamp = userDefaults.double(forKey: installDateKey)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                userDefaults.set(date.timeIntervalSince1970, forKey: installDateKey)
            }
        }
    }
    
    func checkTrialStatus() {
        if !isTrialActive && !hasShownTrialEndNotice {
            shouldShowTrialEndNotice = true
        }
    }
    
    func dismissTrialEndNotice() {
        shouldShowTrialEndNotice = false
        userDefaults.set(true, forKey: trialEndNoticeShownKey)
    }
    
    private var hasShownTrialEndNotice: Bool {
        userDefaults.bool(forKey: trialEndNoticeShownKey)
    }
    
    func endTrial() {
        // 無料版に自動切り替え
        UserDefaults.standard.set(false, forKey: "isPro")
    }
#if DEBUG
func setTrialOffset(days: Int) {
    UserDefaults.standard.set(days, forKey: "dev.trialOffsetDays")
    checkTrialStatus() // その場で反映
}
func bumpTrialOffset(_ delta: Int) {
    let key = "dev.trialOffsetDays"
    let now = UserDefaults.standard.integer(forKey: key)
    setTrialOffset(days: now + delta)
}
var trialOffsetDays: Int { UserDefaults.standard.integer(forKey: "dev.trialOffsetDays") }
#endif
}
