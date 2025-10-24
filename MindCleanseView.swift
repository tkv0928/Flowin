import SwiftUI
import SpriteKit
import UIKit

// MARK: - 共有状態（SwiftUI ↔︎ SpriteKit）
final class MindCleanseState: ObservableObject {
    @Published var clearedCount: Int = 0
    @Published var activeCount: Int = 0
    @Published var progress: CGFloat = 0.0   // 0.0 → 1.0（静寂ゲージ）
    @Published var isCleared: Bool = false
}

struct MindCleanseView: View {
    @StateObject private var state = MindCleanseState()

    private var scene: MindCleanseScene {
        let s = MindCleanseScene(size: CGSize(width: 390, height: 844)) // 適当サイズ、実行時にリサイズされる
        s.scaleMode = .resizeFill
        s.gameState = state
        return s
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            // HUD：静寂ゲージ + カウント
            VStack {
                HStack {
                    Text("静寂ゲージ")
                        .font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(state.progress), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.mint)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                HStack(spacing: 16) {
                    Label("\(state.activeCount)", systemImage: "circle.grid.3x3.fill")
                    Label("\(state.clearedCount)", systemImage: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }

            // クリア演出
            if state.isCleared {
                VStack(spacing: 12) {
                    Text("精神ノイズキャンセリング完了")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 8)
                    Text("頭の中、シーン。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Button {
                        // ここで本編の集中タイマー画面へ遷移させる（呼び出し側で差し替えOK）
                        // e.g., Dismiss / Navigation / Callback など
                    } label: {
                        Text("集中モードへ")
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(.mint.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 12)
            }
        }
    }
}

// MARK: - SpriteKit Scene
final class MindCleanseScene: SKScene {

    weak var gameState: MindCleanseState?

    // チューニング用パラメータ
    private let totalTargetToClear: Int = 120       // 最終的に消したい総数
    private let initialMaxActive: Int = 40          // 開始時の同時出現上限（カオス）
    private let finalMaxActive: Int = 4             // 終盤の同時出現上限（静寂）
    private let minSpeed: CGFloat = 80              // 終盤の低速
    private let maxSpeed: CGFloat = 320             // 序盤の高速
    private let spawnInterval: TimeInterval = 0.10  // 出現チェック頻度

    private var lastSpawnTime: TimeInterval = 0
    private var hapticLight = UIImpactFeedbackGenerator(style: .light)
    private var hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0) // ほぼ黒に近い濃紺
        physicsWorld.gravity = .zero
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame.insetBy(dx: 2, dy: 2))
        physicsBody?.categoryBitMask = 0x1 << 1
        hapticLight.prepare()
        hapticMedium.prepare()

        // 進行に合わせて背景を少しずつ暗く（静寂の演出）
        run(.repeatForever(.sequence([
            .wait(forDuration: 0.25),
            .run { [weak self] in self?.updateBackgroundTone() }
        ])))
    }

    // リサイズ時にも壁を更新
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame.insetBy(dx: 2, dy: 2))
    }

    // フレーム更新
    override func update(_ currentTime: TimeInterval) {
        guard let state = gameState, !state.isCleared else { return }

        // スポーン（現在のアクティブ数が動的上限未満なら生成）
        if currentTime - lastSpawnTime > spawnInterval {
            lastSpawnTime = currentTime
            spawnIfNeeded()
        }

        // 終了条件：十分に消して、かつ画面から消えたらクリア
        if state.clearedCount >= totalTargetToClear && children.filter({ $0.name == "panel" }).isEmpty {
            state.isCleared = true
            // 余韻のために全体を薄暗く
            let fade = SKAction.colorize(with: .black, colorBlendFactor: 0.6, duration: 0.6)
            run(fade)
        }
    }

    // MARK: - 生成と演出
    private func spawnIfNeeded() {
        guard let state = gameState, !state.isCleared else { return }

        let t = CGFloat(min(1.0, max(0.0, Double(state.clearedCount) / Double(totalTargetToClear))))
        let dynamicMaxActive = Int(lerp(from: CGFloat(initialMaxActive), to: CGFloat(finalMaxActive), t: t).rounded())
        let currentActive = children.filter { $0.name == "panel" }.count
        state.activeCount = currentActive

        if currentActive >= dynamicMaxActive { return }

        // 追加生成：一度に複数発生して「カオス感」をキープ
        let toSpawn = max(1, min(3, dynamicMaxActive - currentActive))
        for _ in 0..<toSpawn {
            addPanel(progressT: t)
        }
        state.activeCount = children.filter { $0.name == "panel" }.count
    }

    private func addPanel(progressT t: CGFloat) {
        // サイズとHP：序盤は大きく壊れやすい、終盤は小さく＆硬いを少し混ぜる
        let minR: CGFloat = 12
        let maxR: CGFloat = 36
        let radius = lerp(from: maxR, to: minR, t: t) + CGFloat.random(in: -4...8)

        let node = SKShapeNode(circleOfRadius: max(radius, 8))
        node.name = "panel"
        node.fillColor = panelColor(for: t)
        node.strokeColor = node.fillColor.withAlphaComponent(0.8)
        node.lineWidth = 1.0
        node.alpha = 0.95

        // 位置（画面内ランダム）
        let inset: CGFloat = radius + 8
        let x = CGFloat.random(in: (frame.minX + inset)...(frame.maxX - inset))
        let y = CGFloat.random(in: (frame.minY + inset)...(frame.maxY - inset))
        node.position = CGPoint(x: x, y: y)

        // 物理（バウンド移動）
        node.physicsBody = SKPhysicsBody(circleOfRadius: max(radius, 8))
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.linearDamping = 0.0
        node.physicsBody?.restitution = 1.0
        node.physicsBody?.friction = 0.0

        // 速度：進行に合わせて減速
        let speed = lerp(from: maxSpeed, to: minSpeed, t: t)
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        let vx = cos(angle) * speed
        let vy = sin(angle) * speed
        node.physicsBody?.velocity = CGVector(dx: vx, dy: vy)

        // HP（終盤はたまに硬い）
        let baseHP = (t < 0.7) ? 1 : (Bool.random() ? 1 : 2)
        node.userData = NSMutableDictionary(dictionary: ["hp": baseHP])

        // 点滅（カオス演出 → 進行で緩む）
        let flashDur = Double(lerp(from: 0.12, to: 0.32, t: t))
        let flash = SKAction.sequence([
            .fadeAlpha(to: 0.6, duration: flashDur),
            .fadeAlpha(to: 1.0, duration: flashDur)
        ])
        node.run(.repeatForever(flash), withKey: "flash")

        addChild(node)
    }

    // MARK: - タップ処理
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let state = gameState, !state.isCleared else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location).first { $0.name == "panel" } as? SKShapeNode
        guard let node = tapped else { return }

        // HP処理
        let hp = (node.userData?["hp"] as? Int) ?? 1
        if hp > 1 {
            node.userData?["hp"] = hp - 1
            pulse(node, strong: false)
            hapticLight.impactOccurred()
        } else {
            // 破壊
            explode(node)
            hapticMedium.impactOccurred()
            state.clearedCount += 1
            state.activeCount = children.filter { $0.name == "panel" }.count
            // 進捗（静寂ゲージ）
            let t = CGFloat(min(1.0, max(0.0, Double(state.clearedCount) / Double(totalTargetToClear))))
            state.progress = t
        }
    }

    // MARK: - 演出
    private func pulse(_ node: SKShapeNode, strong: Bool) {
        let s: CGFloat = strong ? 1.2 : 1.08
        let d = strong ? 0.08 : 0.06
        node.run(.sequence([
            .scale(to: s, duration: d),
            .scale(to: 1.0, duration: d)
        ]))
    }

    private func explode(_ node: SKShapeNode) {
        node.removeAction(forKey: "flash")

        // 光のリング
        let ring = SKShapeNode(circleOfRadius: max(node.frame.width, node.frame.height) * 0.6)
        ring.position = node.position
        ring.strokeColor = .white.withAlphaComponent(0.8)
        ring.lineWidth = 2.0
        ring.alpha = 0.9
        addChild(ring)

        let ringAnim = SKAction.group([
            .scale(to: 1.8, duration: 0.18),
            .fadeOut(withDuration: 0.18)
        ])
        ring.run(.sequence([ringAnim, .removeFromParent()]))

        // 粒子もどき（5〜9個の点をランダムに散らす）
        let count = Int.random(in: 5...9)
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: 2.0)
            dot.fillColor = .white.withAlphaComponent(0.9)
            dot.strokeColor = .clear
            dot.position = node.position
            addChild(dot)
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let r = CGFloat.random(in: 40...90)
            let dest = CGPoint(x: node.position.x + cos(a) * r, y: node.position.y + sin(a) * r)
            let move = SKAction.move(to: dest, duration: 0.25)
            dot.run(.sequence([move, .fadeOut(withDuration: 0.1), .removeFromParent()]))
        }

        node.run(.sequence([
            .group([
                .scale(to: 0.6, duration: 0.08),
                .fadeOut(withDuration: 0.08)
            ]),
            .removeFromParent()
        ]))
    }

    private func updateBackgroundTone() {
        guard let state = gameState else { return }
        let t = CGFloat(min(1.0, max(0.0, Double(state.clearedCount) / Double(totalTargetToClear))))
        // 進行に合わせて背景を暗く・青く
        let base = CGFloat(0.08)
        let darken = base + 0.12 * t
        backgroundColor = SKColor(red: darken * 0.7, green: darken * 0.8, blue: darken + 0.05, alpha: 1.0)
        state.progress = t
    }

    private func panelColor(for t: CGFloat) -> SKColor {
        // 序盤：派手目、中盤以降：落ち着いた寒色へ
        let r = lerp(from: 0.95, to: 0.20, t: t)
        let g = lerp(from: 0.65, to: 0.80, t: t)
        let b = lerp(from: 0.30, to: 0.95, t: t)
        return SKColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    // 線形補間
    private func lerp(from a: CGFloat, to b: CGFloat, t: CGFloat) -> CGFloat {
        return a + (b - a) * min(max(t, 0), 1)
    }
}
