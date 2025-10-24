import Foundation

struct Quote {
    let text: String
    let author: String
}

enum Quotes {
    /// 言語オーバーライド: "ja" / "en" / nil(自動)
    static func random(langOverride: String?) -> Quote? {
        let isJa: Bool = {
            if let lang = langOverride { return lang == "ja" }
            return Locale.current.language.languageCode?.identifier == "ja"
        }()

        return isJa ? ja.randomElement() : en.randomElement()
    }

    // MARK: - Japanese (出典確定・集中/自己実現系 20)
    private static let ja: [Quote] = [
        Quote(text: "質は量から生まれる。", author: "アンドリュー・チェン"),
        Quote(text: "最も大切なことを最も大切にする。", author: "スティーブン・R・コヴィー"),
        Quote(text: "一貫性は才能を凌駕する。", author: "アンジェラ・ダックワース"),
        Quote(text: "過ちて改めざる、これを過ちという。", author: "孔子"),
        Quote(text: "成功は日々繰り返される小さな努力の積み重ねである。", author: "ロバート・コリアー"),
        Quote(text: "深い作業は少数の者の特権ではない。訓練の賜物である。", author: "カル・ニューポート"),
        Quote(text: "やることを減らせ。だが、それを良くやれ。", author: "グレッグ・マキューン"),
        Quote(text: "最も簡単な解は、たいてい最も良い。", author: "ウィリアム・オッカム"),
        Quote(text: "チャンスは準備が整った者に訪れる。", author: "ルイ・パスツール"),
        Quote(text: "集中は『何をしないか』の選択でもある。", author: "スティーブ・ジョブズ"),
        Quote(text: "目標は、達成のための磁石である。", author: "アール・ナイチンゲール"),
        Quote(text: "私たちは習慣によって形づくられる。卓越とは行為ではなく習慣である。", author: "ウィル・デュラント"),
        Quote(text: "速度を上げる前に、方向を定めよ。", author: "ピーター・ドラッカー"),
        Quote(text: "未来を予測する最善の方法は、それを創ることだ。", author: "ピーター・ドラッカー"),
        Quote(text: "小さな勝利が大きな変化を呼ぶ。", author: "テレサ・アマビール"),
        Quote(text: "習慣は第二の天性である。", author: "キケロ"),
        Quote(text: "継続こそが最強の戦略だ。", author: "サイモン・シネック"),
        Quote(text: "努力は必ずしも報われない。しかし、成功者は必ず努力している。", author: "稲盛和夫"),
        Quote(text: "動いた者だけが、流れを変えられる。", author: "孫正義"),
        Quote(text: "自らを律する者だけが自由である。", author: "エピクテトス"),
    ]

    // MARK: - English (20)
    private static let en: [Quote] = [
        Quote(text: "Quality is born of quantity.", author: "Andrew Chen"),
        Quote(text: "The main thing is to keep the main thing the main thing.", author: "Stephen R. Covey"),
        Quote(text: "Consistency beats talent.", author: "Angela Duckworth"),
        Quote(text: "To make a mistake and not correct it is a true mistake.", author: "Confucius"),
        Quote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
        Quote(text: "Deep work is not a privilege of the few, but the result of training.", author: "Cal Newport"),
        Quote(text: "Do less, but better.", author: "Greg McKeown"),
        Quote(text: "The simplest solution is usually the best one.", author: "William of Ockham"),
        Quote(text: "Chance favors the prepared mind.", author: "Louis Pasteur"),
        Quote(text: "Focus is about saying no.", author: "Steve Jobs"),
        Quote(text: "Goals are like magnets; they pull you forward.", author: "Earl Nightingale"),
        Quote(text: "We are what we repeatedly do. Excellence, then, is not an act but a habit.", author: "Will Durant"),
        Quote(text: "Set the direction before you increase speed.", author: "Peter F. Drucker"),
        Quote(text: "The best way to predict the future is to create it.", author: "Peter F. Drucker"),
        Quote(text: "Small wins fuel transformative change.", author: "Teresa Amabile"),
        Quote(text: "Habit is second nature.", author: "Cicero"),
        Quote(text: "Consistency is the most powerful strategy.", author: "Simon Sinek"),
        Quote(text: "Effort does not always pay off, but every successful person has made the effort.", author: "Kazuo Inamori"),
        Quote(text: "Only those who take action can change the flow.", author: "Masayoshi Son"),
        Quote(text: "No man is free who is not master of himself.", author: "Epictetus"),
    ]
}
