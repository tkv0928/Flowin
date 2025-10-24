import SwiftUI
import SpriteKit

final class ReactionScene: SKScene {
    var onFinish: ((Int, Int)->Void)?
    private var round = 0
    private let totalRounds = 10
    private var canTap = false
    private var startTime: CFTimeInterval = 0
    private var results: [Int] = []

    private var flashNode: SKSpriteNode!
    private var tapHere: SKLabelNode!

    override func didMove(to view: SKView) {
        backgroundColor = .black

        flashNode = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: size.height))
        flashNode.alpha = 0
        flashNode.zPosition = 10
        addChild(flashNode)

        tapHere = SKLabelNode(text: "フラッシュ後にタップ")
        tapHere.fontSize = 28
        tapHere.fontName = "Helvetica-Bold"
        tapHere.position = CGPoint(x: size.width/2, y: size.height/2)
        tapHere.fontColor = .white
        addChild(tapHere)

        runRound()
    }

    private func runRound() {
        canTap = false
        round += 1
        let wait = Double.random(in: 0.8...2.0)

        addSpeedLines()

        let seq = SKAction.sequence([
            SKAction.wait(forDuration: wait),
            SKAction.run { [weak self] in self?.flash() }
        ])
        run(seq)
    }

    private func flash() {
        let up = SKAction.fadeAlpha(to: 0.9, duration: 0.05)
        let down = SKAction.fadeOut(withDuration: 0.12)
        flashNode.run(.sequence([up, down]))
        Haptics.play(.rigid)
        startTime = CACurrentMediaTime()
        canTap = true
    }

    private func endRound(with ms: Int) {
        results.append(ms)
        shake(intensity: 8, duration: 0.12)
        Sound.shared.play(.ping)

        if round < totalRounds {
            runRound()
        } else {
            let avg = Int(Double(results.reduce(0,+)) / Double(results.count))
            let best = results.min() ?? avg
            onFinish?(avg, best)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if canTap {
            canTap = false
            let elapsed = CACurrentMediaTime() - startTime
            let ms = Int(elapsed * 1000.0)
            endRound(with: ms)
        } else {
            desaturateFlash()
            Haptics.play(.error)
            Sound.shared.play(.buzz)
        }
    }

    // ===== エフェクト群 =====
    private func shake(intensity: CGFloat, duration: CGFloat) {
        let left = SKAction.moveBy(x: -intensity, y: 0, duration: duration/4)
        let right = left.reversed()
        let seq = SKAction.sequence([left, right, right, left, .moveTo(x: size.width/2, duration: 0)])
        tapHere.run(seq)
    }

    private func desaturateFlash() {
        let gray = SKSpriteNode(color: .darkGray, size: CGSize(width: size.width, height: size.height))
        gray.alpha = 0.0; gray.zPosition = 9; addChild(gray)
        gray.run(.sequence([
            .fadeAlpha(to: 0.6, duration: 0.05),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    private func addSpeedLines() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(image: speedLineImage())
        emitter.particleBirthRate = 220
        emitter.particleLifetime = 0.35
        emitter.particleSpeed = 900
        emitter.particleSpeedRange = 200
        emitter.particleScale = 0.5
        emitter.particleAlpha = 0.5
        emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0.2, 0.7, 0.0], times: [0, 0.6, 1])
        emitter.emissionAngle = .pi
        emitter.position = CGPoint(x: size.width + 10, y: size.height/2)
        emitter.particlePositionRange = CGVector(dx: 0, dy: size.height)
        emitter.zPosition = -1
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
    }

    private func speedLineImage() -> UIImage {
        let w = 4, h = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: w, height: h)).fill()
        }
    }
}

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var averageMs: Int?
    @State private var bestMsInRun: Int?

    var onFinish: ((Int, Int)->Void)?

    var scene: SKScene {
        let s = ReactionScene()
        s.size = CGSize(width: 430, height: 932)
        s.scaleMode = .resizeFill
        s.onFinish = { avg, best in
            averageMs = avg
            bestMsInRun = best
        }
        return s
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            if let avg = averageMs, let best = bestMsInRun {
                ResultSheet(average: avg, best: best) {
                    onFinish?(avg, best)
                    dismiss()
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct ResultSheet: View {
    let average: Int
    let best: Int
    var onClose: ()->Void

    @AppStorage("bestMs") private var bestAll: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("結果")
                .font(.title.bold())
            HStack {
                VStack { Text("平均"); Text("\(average) ms").font(.title3.bold()) }
                Divider().frame(height: 48)
                VStack { Text("ベスト"); Text("\(best) ms").font(.title3.bold()) }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if bestAll > 0 {
                let diff = bestAll - best
                Text(diff > 0 ? "自己ベスト更新: \(diff)ms 短縮！" : "自己ベスト: \(bestAll)ms")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Haptics.play(.soft)
                onClose()
            } label: {
                Text("閉じる")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)   // 視認性UP
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        )
        .padding(24)
    }
}
