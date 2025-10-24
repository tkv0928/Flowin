import SpriteKit
import UIKit

final class GridScene: SKScene {

    // ====== 設定 ======
    private let gridRows = 3
    private let gridCols = 3
    private var sessionDuration: TimeInterval
    private var currentOnTime: TimeInterval = 0.7  // V0.5: 固定700ms
    private let cellSpacing: CGFloat = 12
    
    // V0.5: 固定サイクル（Quick/Deep共通）
    private let fixedOnTimeMs: TimeInterval = 0.7
    private var sessionType: SessionType

    // ミス許容度
    private var consecutiveMissLimit: Int = 6
    private var totalMissLimit: Int = 12
    
    private var consecutiveMissStreak = 0
    private var totalMissCount = 0

    // V0.5: フロー検出（V3継続）
    private let enableFlowDetection: Bool
    private let enableFlowDebug: Bool
    private var successTimes: [(t: TimeInterval, rt: TimeInterval)] = []
    private var isInFlow = false
    private var flowBanner: SKLabelNode?
    private var flowPattern: SKSpriteNode?
    private var flowLinesEmitter: SKEmitterNode?
    
    // V0.5: フロー記録
    private var flowEnterCount = 0
    private var flowHitCount = 0
    private var flowTotalMs: Double = 0
    private var flowEnterTime: TimeInterval = 0
    
    // V0.5: EWMA + WindowAvg
    private var ewma: Double = 0
    private let ewmaAlpha: Double = 0.2
    private let windowSize = 30

    // ====== 状態 ======
    var onGameEnd: ((Int, Int, Int, Int, Int, Int, Double)->Void)?

    private var cells: [SKSpriteNode] = []
    private var activeIndex: Int? = nil
    private var activeStartTime: TimeInterval = 0
    private var lastSpawnTime: TimeInterval = 0
    private var gameStartTime: TimeInterval = 0

    private var score = 0
    private var combo = 0
    private var bestCombo = 0
    private var reactions: [TimeInterval] = []

    // HUD
    private var scoreLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var debugLabel: SKLabelNode?

    // MARK: - Init
    init(size: CGSize, sessionDuration: TimeInterval, sessionType: SessionType, enableFlowDetection: Bool, enableFlowDebug: Bool) {
        self.sessionDuration = sessionDuration
        self.sessionType = sessionType
        self.enableFlowDetection = enableFlowDetection
        self.enableFlowDebug = enableFlowDebug
        super.init(size: size)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupGrid()
        setupHUD()
        startGame()
    }

    private func startGame() {
        score = 0; combo = 0; bestCombo = 0
        reactions.removeAll()
        consecutiveMissStreak = 0
        totalMissCount = 0
        successTimes.removeAll()
        isInFlow = false
        flowEnterCount = 0
        flowHitCount = 0
        flowTotalMs = 0
        ewma = 0
        removeFlowUI()
        
        // V0.5: 固定サイクル統一
        currentOnTime = fixedOnTimeMs
        
        gameStartTime = CACurrentMediaTime()
        spawnNextCell(force: true)
    }

    // ====== セットアップ ======
    private func setupGrid() {
        cells.forEach { $0.removeFromParent() }
        cells.removeAll()

        let area = CGSize(width: size.width * 0.84, height: size.width * 0.84)
        let cellSize = (min(area.width, area.height) - cellSpacing * 2) / 3.0
        let startX = (size.width - (cellSize * 3 + cellSpacing * 2)) / 2 + cellSize / 2
        let startY = size.height * 0.56

        for r in 0..<gridRows {
            for c in 0..<gridCols {
                let node = SKSpriteNode(color: .darkGray, size: CGSize(width: cellSize, height: cellSize))
                node.position = CGPoint(
                    x: startX + CGFloat(c) * (cellSize + cellSpacing),
                    y: startY - CGFloat(r) * (cellSize + cellSpacing)
                )
                node.alpha = 0.85
                node.zPosition = 1
                node.run(.sequence([.scale(to: 0.98, duration: 0), .scale(to: 1.0, duration: 0.2)]))
                addChild(node)
                cells.append(node)
            }
        }
    }

    private func setupHUD() {
        scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreLabel.fontSize = 28; scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 20, y: size.height - 100)
        scoreLabel.zPosition = 10; addChild(scoreLabel)

        timeLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        timeLabel.fontSize = 28; timeLabel.fontColor = .white
        timeLabel.horizontalAlignmentMode = .right
        timeLabel.position = CGPoint(x: size.width - 20, y: size.height - 100)
        timeLabel.zPosition = 10; addChild(timeLabel)

        comboLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        comboLabel.fontSize = 24; comboLabel.fontColor = .white
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.14)
        comboLabel.zPosition = 10; addChild(comboLabel)

        if enableFlowDebug {
            let dbg = SKLabelNode(fontNamed: "Menlo")
            dbg.fontSize = 12; dbg.fontColor = .white.withAlphaComponent(0.9)
            dbg.horizontalAlignmentMode = .left
            dbg.verticalAlignmentMode = .top
            dbg.position = CGPoint(x: 12, y: size.height - 130)
            dbg.zPosition = 50
            addChild(dbg)
            debugLabel = dbg
        }

        updateHUD()
    }

    private func updateHUD() {
        scoreLabel.text = "Score \(score)"
        let elapsed = CACurrentMediaTime() - gameStartTime
        let remain = max(0, sessionDuration - elapsed)
        timeLabel.text = String(format: "%.0f", ceil(remain))
        comboLabel.text = combo > 0 ? "Combo ×\(combo)" : ""
    }

    // ====== ループ ======
    override func update(_ currentTime: TimeInterval) {
        updateHUD()
        if CACurrentMediaTime() - gameStartTime >= sessionDuration { endGame(); return }

        if let idx = activeIndex, (currentTime - activeStartTime) >= currentOnTime {
            registerMissAndContinue(at: cells[idx].position)
        }
        if activeIndex == nil, (currentTime - lastSpawnTime) > 0.03 {
            spawnNextCell(force: true)
        }

        if enableFlowDetection { evaluateFlowState(now: currentTime) }
        if enableFlowDebug { updateDebugHUD(now: currentTime) }
    }

    private func endGame() {
        let validReactions = sanitizeRTs(reactions)
        let avgMs: Int = {
            guard isValidSession(validTapCount: validReactions.count) else {
                return -1
            }
            let avg = validReactions.reduce(0.0, +) / Double(validReactions.count)
            return Int((avg * 1000.0).rounded())
        }()
        
        // V0.5: 終了時集計
        onGameEnd?(score, bestCombo, avgMs, totalMissCount, flowHitCount, flowEnterCount, flowTotalMs)
        isPaused = true
    }

    // ====== 進行 ======
    private func spawnNextCell(force: Bool = false) {
        let available = (0..<cells.count).filter { $0 != activeIndex }
        guard let pick = available.randomElement() else { return }
        activeIndex = pick
        activeStartTime = CACurrentMediaTime()
        lastSpawnTime = CACurrentMediaTime()

        let node = cells[pick]
        node.color = .systemYellow
        node.alpha = 1.0
        node.removeAllActions()
        node.run(.sequence([
            .scale(to: 1.03, duration: 0.06),
            .scale(to: 1.00, duration: 0.10)
        ]))
        addSpeedLines(at: node.position)
    }

    private func clearActiveCell() {
        if let idx = activeIndex {
            let node = cells[idx]
            node.removeAllActions()
            node.color = .darkGray
            node.alpha = 0.85
        }
        activeIndex = nil
    }

    // ====== 入力 ======
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if enableFlowDebug, let p = touches.first?.location(in: self) {
            if p.x < size.width * 0.2 && p.y > size.height * 0.8 {
                if !isInFlow { enterFlowUI() } else { exitFlowUI() }
                return
            }
        }

        guard let t = touches.first else { return }
        let p = t.location(in: self)
        guard let hitIndex = cells.firstIndex(where: { $0.contains(p) }) else { return }

        if let active = activeIndex, active == hitIndex {
            let react = CACurrentMediaTime() - activeStartTime
            registerSuccess(at: cells[active], reaction: react)
        } else {
            registerMiss(at: p)
        }
    }

    // ====== 成功 / 失敗 ======
    private func registerSuccess(at node: SKSpriteNode, reaction: TimeInterval) {
        reactions.append(reaction)
        successTimes.append((t: CACurrentMediaTime(), rt: reaction))

        // V0.5: スコアリング - V3継続
        var gained = 1 + ((combo - 1) / 3)
        if isInFlow {
            gained += 5
            flowHitCount += 1
        }
        score += gained

        combo += 1; bestCombo = max(bestCombo, combo)
        consecutiveMissStreak = 0

        // 演出
        let intense = (reaction <= 0.30)
        burst(at: node.position, intense: intense)
        shockWave(at: node.position, intense: intense)
        scorePop(at: node.position, value: gained)
        if intense { pulseBackground(intense: true) }
        Haptics.play(intense ? .rigid : .soft)
        Sound.shared.play(.ping)

        node.run(.sequence([
            .group([.scale(to: 0.95, duration: 0.05), .fadeAlpha(to: 0.8, duration: 0.05)]),
            .group([.scale(to: 1.00, duration: 0.08), .fadeAlpha(to: 1.0, duration: 0.08)])
        ]))

        clearActiveCell()
        spawnNextCell()
    }

    private func registerMissAndContinue(at pos: CGPoint) {
        combo = 0
        consecutiveMissStreak += 1
        totalMissCount += 1
        
        if isInFlow {
            exitFlowUI()
        }

        let gray = SKSpriteNode(color: .darkGray, size: CGSize(width: 24, height: 24))
        gray.position = pos; gray.zPosition = 5; gray.alpha = 0
        addChild(gray)
        gray.run(.sequence([
            .fadeAlpha(to: 0.6, duration: 0.05),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
        
        Haptics.play(.error)
        Sound.shared.play(.buzz)
        
        clearActiveCell()

        if consecutiveMissStreak >= consecutiveMissLimit || totalMissCount >= totalMissLimit {
            endGame()
        } else {
            spawnNextCell()
        }
    }

    private func registerMiss(at pos: CGPoint) {
        combo = 0
        consecutiveMissStreak += 1
        totalMissCount += 1
        
        if isInFlow {
            exitFlowUI()
        }

        let n = SKSpriteNode(color: .red, size: CGSize(width: 20, height: 20))
        n.position = pos; n.alpha = 0.6; n.zPosition = 6
        addChild(n)
        n.run(.sequence([.scale(to: 1.7, duration: 0.12), .fadeOut(withDuration: 0.18), .removeFromParent()]))
        
        Haptics.play(.error)
        Sound.shared.play(.buzz)

        if consecutiveMissStreak >= consecutiveMissLimit || totalMissCount >= totalMissLimit {
            endGame()
        }
    }

    // ====== V0.5: フロー評価（V3継続） ======
    private func evaluateFlowState(now: TimeInterval) {
        let windowSec: TimeInterval = 6.0
        let minCount = 6
        
        let recentSuccesses = successTimes.filter { now - $0.t <= windowSec }
        let validRTs = sanitizeRTs(recentSuccesses.map { $0.rt })
        
        guard validRTs.count >= minCount else { return }
        
        let windowRTs = Array(validRTs.suffix(windowSize))
        let windowAvg = (windowRTs.reduce(0, +) / Double(windowRTs.count)) * 1000.0
        
        if ewma == 0 {
            ewma = windowAvg
        } else {
            ewma = ewmaAlpha * windowAvg + (1.0 - ewmaAlpha) * ewma
        }
        
        let enterThreshold1 = ewma * 0.90
        let enterThreshold2 = 350.0
        let exitThreshold1 = ewma * 0.95
        let exitThreshold2 = 380.0
        
        let shouldEnter = (windowAvg <= enterThreshold1) || (windowAvg <= enterThreshold2)
        let shouldExit = (windowAvg > exitThreshold1) && (windowAvg > exitThreshold2)
        
        if !isInFlow && shouldEnter && consecutiveMissStreak == 0 {
            enterFlowUI()
        } else if isInFlow && shouldExit {
            exitFlowUI()
        }
    }

    private func enterFlowUI() {
        isInFlow = true
        flowEnterCount += 1
        flowEnterTime = CACurrentMediaTime()
        
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Black")
        label.text = Locale.current.language.languageCode?.identifier == "ja" ? "フロー状態！" : "Flow State!"
        label.fontSize = 44
        label.fontColor = .white
        label.position = CGPoint(x: size.width/2, y: size.height*0.78)
        label.zPosition = 30
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .group([.fadeAlpha(to: 1.0, duration: 0.2), .scale(to: 1.05, duration: 0.2)]),
            .scale(to: 1.0, duration: 0.15)
        ]))
        flowBanner = label

        let pattern = SKSpriteNode(color: .clear, size: CGSize(width: size.width, height: size.height))
        pattern.position = CGPoint(x: size.width/2, y: size.height/2)
        pattern.zPosition = 0
        pattern.alpha = 0.0
        addChild(pattern)
        flowPattern = pattern
        pattern.texture = SKTexture(image: patternImage())
        pattern.run(.fadeAlpha(to: 0.22, duration: 0.25))

        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: speedLineImage())
        e.particleBirthRate = 240
        e.particleLifetime = 0.35
        e.particleSpeed = 820
        e.particleSpeedRange = 220
        e.particleScale = 0.45
        e.particleAlpha = 0.5
        e.emissionAngle = .pi * 2
        e.particlePositionRange = CGVector(dx: size.width*0.5, dy: size.height*0.5)
        e.position = CGPoint(x: size.width/2, y: size.height/2)
        e.zPosition = 0
        addChild(e)
        flowLinesEmitter = e

        Haptics.play(.rigid)
        Sound.shared.play(.ping)
    }

    private func exitFlowUI() {
        if isInFlow {
            let duration = CACurrentMediaTime() - flowEnterTime
            flowTotalMs += duration * 1000.0
        }
        
        isInFlow = false
        flowBanner?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        flowPattern?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        flowLinesEmitter?.run(.sequence([.wait(forDuration: 0.0), .removeFromParent()]))
        flowBanner = nil; flowPattern = nil; flowLinesEmitter = nil
    }

    private func removeFlowUI() {
        flowBanner?.removeFromParent()
        flowPattern?.removeFromParent()
        flowLinesEmitter?.removeFromParent()
        flowBanner = nil; flowPattern = nil; flowLinesEmitter = nil
    }

    private func updateDebugHUD(now: TimeInterval) {
        guard let dbg = debugLabel else { return }
        let validRTs = sanitizeRTs(reactions)
        let recentRTs = validRTs.suffix(windowSize).map { $0 * 1000.0 }
        let windowAvg = recentRTs.isEmpty ? 0 : (recentRTs.reduce(0,+) / Double(recentRTs.count))
        
        dbg.text = String(format: "FLOW: win:%.0f ema:%.0f enter:%d hits:%d %@",
                         windowAvg, ewma, flowEnterCount, flowHitCount, isInFlow ? "IN" : "OUT")
    }

    private func sanitizeRTs(_ rawRTs: [TimeInterval]) -> [TimeInterval] {
        return rawRTs.filter { $0 >= 0.120 && $0 <= 1.500 }
    }
    
    private func isValidSession(validTapCount: Int) -> Bool {
        return validTapCount >= 5
    }

    // ====== エフェクト ======
    private func burst(at pos: CGPoint, intense: Bool) {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: circleImage(radius: intense ? 10 : 6))
        e.particleBirthRate = intense ? 900 : 500
        e.particleLifetime = 0.35
        e.particleSpeed = intense ? 600 : 420
        e.particleSpeedRange = intense ? 250 : 160
        e.particleScale = intense ? 0.7 : 0.45
        e.particleAlpha = 0.9
        e.particleColor = .white
        e.position = pos; e.zPosition = 8
        addChild(e)
        e.run(.sequence([.wait(forDuration: 0.25), .removeFromParent()]))
    }

    private func shockWave(at pos: CGPoint, intense: Bool) {
        let radius: CGFloat = intense ? 22 : 16
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = pos
        ring.strokeColor = .white
        ring.lineWidth = intense ? 6 : 4
        ring.fillColor = .clear
        ring.alpha = 0.9
        ring.zPosition = 9
        addChild(ring)
        let scale: CGFloat = intense ? 4.0 : 3.0
        ring.run(.sequence([
            .group([.scale(to: scale, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }

    private func scorePop(at pos: CGPoint, value: Int) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = "+\(value)"
        label.fontSize = (value >= 2) ? 28 : 24
        label.fontColor = .white
        label.position = pos
        label.zPosition = 9
        label.alpha = 0.0
        addChild(label)
        let dy: CGFloat = 34
        label.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.06),
                .moveBy(x: 0, y: dy, duration: 0.4)
            ]),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    private func addSpeedLines(at pos: CGPoint) {
        let e = SKEmitterNode()
        e.particleTexture = SKTexture(image: speedLineImage())
        e.particleBirthRate = 260
        e.particleLifetime = 0.25
        e.particleSpeed = 900
        e.particleSpeedRange = 200
        e.particleScale = 0.5
        e.particleAlpha = 0.6
        e.emissionAngle = .pi * 2
        e.particlePositionRange = CGVector(dx: 40, dy: 40)
        e.position = pos; e.zPosition = 0
        addChild(e)
        e.run(.sequence([.wait(forDuration: 0.2), .removeFromParent()]))
    }

    private func pulseBackground(intense: Bool) {
        let n = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: size.height))
        n.alpha = 0; n.zPosition = 0
        addChild(n)
        n.run(.sequence([
            .fadeAlpha(to: intense ? 0.25 : 0.15, duration: 0.05),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func circleImage(radius: CGFloat) -> UIImage {
        let d = radius * 2
        let r = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        return r.image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: d, height: d)).fill()
        }
    }
    
    private func speedLineImage() -> UIImage {
        let w = 3.0, h = 26.0
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return r.image { _ in
            UIColor.white.withAlphaComponent(0.8).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: w, height: h)).fill()
        }
    }
    
    private func patternImage() -> UIImage {
        let w = Int(size.width), h = Int(size.height)
        let r = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return r.image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0.06).cgColor,
                          UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0,1])!
            ctx.cgContext.drawLinearGradient(grad,
                                             start: CGPoint(x: 0, y: 0),
                                             end: CGPoint(x: 0, y: CGFloat(h)),
                                             options: [])
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            ctx.cgContext.setLineWidth(1)
            let step: CGFloat = 16
            var x: CGFloat = -CGFloat(h)
            while x < CGFloat(w) {
                ctx.cgContext.move(to: CGPoint(x: x, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: x + CGFloat(h), y: CGFloat(h)))
                ctx.cgContext.strokePath()
                x += step
            }
        }
    }
}
