import SpriteKit
import UIKit

enum PayloadKind {
    case slab
    case girder
}

struct PinSlot {
    var plan: CGPoint
    var tint: UIColor
    var occupied: Bool
}

struct FleetMark {
    var plan: CGPoint
}

struct LiftJob {
    var kind: PayloadKind
    var tint: UIColor
    var slotIndex: Int
}

final class GameScene: SKScene {
    var onFinish: ((Int, Int, Bool) -> Void)?
    var onExit: (() -> Void)?

    private let stage: LiftStage
    private let stageIndex: Int

    private var planRect = CGRect.zero
    private var yardRect = CGRect.zero
    private var hudRect = CGRect.zero

    private let world = SKNode()
    private let planLayer = SKNode()
    private let yardLayer = SKNode()
    private let hudLayer = SKNode()

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let goalLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let swayLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let stageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let backHit = SKShapeNode()

    private var lastTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var score = 0
    private var combo = 0
    private var hits = 0
    private var lives = 3
    private var finished = false

    private var trolley = CGPoint(x: 0.42, y: 0.50)
    private var lastTrolley = CGPoint(x: 0.42, y: 0.50)
    private var hoist: CGFloat = 0.86
    private var swingX: CGFloat = 0
    private var swingZ: CGFloat = 0
    private var omegaX: CGFloat = 0
    private var omegaZ: CGFloat = 0

    private var dragMode = 0
    private var lastTouch = CGPoint.zero
    private var swipeTrail: [CGPoint] = []

    private var slots: [PinSlot] = []
    private var fleet: [FleetMark] = []
    private var queue: [LiftJob] = []
    private var currentJob: LiftJob?
    private var lockHold: TimeInterval = 0
    private var flashText: String?
    private var flashAge: TimeInterval = 0

    private let towerPlan = CGPoint(x: 0.12, y: 0.50)

    init(size: CGSize, stage: LiftStage, stageIndex: Int) {
        self.stage = stage
        self.stageIndex = stageIndex
        super.init(size: size)
        scaleMode = .resizeFill
        lives = stage.lives
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = DraftLook.paper
        addChild(world)
        world.addChild(planLayer)
        world.addChild(yardLayer)
        addChild(hudLayer)
        layoutPanes()
        buildDeck()
        buildJobs()
        createHUD()
        attachNextJob()
        hintLabel.text = "Top: move trolley. Ground: hoist. Swipe against the sway."
        hintLabel.alpha = 1
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayoutForSafeArea()
    }

    func relayoutForSafeArea() {
        layoutPanes()
        refreshHUDLayout()
    }

    private var topSafe: CGFloat {
        max(view?.safeAreaInsets.top ?? 0, 20)
    }

    private var bottomSafe: CGFloat {
        max(view?.safeAreaInsets.bottom ?? 0, 8)
    }

    private func layoutPanes() {
        let hudBand: CGFloat = 64
        let topBar = topSafe + hudBand
        let gap: CGFloat = 8
        let bottomPad = bottomSafe
        let usable = max(120, size.height - topBar - bottomPad - 4)
        let planH = usable * 0.52
        let yardH = usable - planH - gap
        hudRect = CGRect(x: 0, y: size.height - topBar, width: size.width, height: topBar)
        planRect = CGRect(x: 14, y: bottomPad + yardH + gap, width: size.width - 28, height: planH)
        yardRect = CGRect(x: 14, y: bottomPad, width: size.width - 28, height: yardH)
    }

    private func pinTints() -> [UIColor] {
        [
            UIColor(red: 0.10, green: 0.72, blue: 0.92, alpha: 1),
            UIColor(red: 0.86, green: 0.18, blue: 0.62, alpha: 1),
            UIColor(red: 0.28, green: 0.78, blue: 0.22, alpha: 1),
            UIColor(red: 0.98, green: 0.78, blue: 0.12, alpha: 1),
            UIColor(red: 0.55, green: 0.32, blue: 0.95, alpha: 1)
        ]
    }

    private func buildDeck() {
        let tints = pinTints()
        let cols = 3
        let rows = 2
        slots.removeAll()
        for row in 0..<rows {
            for col in 0..<cols {
                let px = 0.34 + CGFloat(col) * 0.22
                let py = 0.28 + CGFloat(row) * 0.34
                let tint = tints[(row * cols + col) % tints.count]
                slots.append(PinSlot(plan: CGPoint(x: px, y: py), tint: tint, occupied: false))
            }
        }
        fleet.removeAll()
        var placed = 0
        var guardCount = 0
        while placed < stage.fleetCount && guardCount < 40 {
            guardCount += 1
            let p = CGPoint(x: CGFloat.random(in: 0.22...0.90), y: CGFloat.random(in: 0.12...0.88))
            let farFromTower = hypot(p.x - towerPlan.x, p.y - towerPlan.y) > 0.18
            let farFromPins = slots.allSatisfy { hypot($0.plan.x - p.x, $0.plan.y - p.y) > 0.14 }
            if farFromTower && farFromPins {
                fleet.append(FleetMark(plan: p))
                placed += 1
            }
        }
    }

    private func buildJobs() {
        queue.removeAll()
        let tints = pinTints()
        for i in 0..<stage.targetSets {
            let slotIndex = i % slots.count
            let kind: PayloadKind = CGFloat.random(in: 0...1) < stage.girderShare ? .girder : .slab
            queue.append(LiftJob(kind: kind, tint: tints[slotIndex % tints.count], slotIndex: slotIndex))
        }
    }

    private func attachNextJob() {
        lockHold = 0
        hoist = 0.88
        swingX = CGFloat.random(in: -0.08...0.08)
        swingZ = CGFloat.random(in: -0.08...0.08)
        omegaX = 0
        omegaZ = 0
        trolley = CGPoint(x: 0.28, y: 0.50)
        lastTrolley = trolley
        if queue.isEmpty {
            currentJob = nil
            return
        }
        currentJob = queue.removeFirst()
        if let job = currentJob {
            slots[job.slotIndex].occupied = false
            slots[job.slotIndex].tint = job.tint
        }
    }

    private func createHUD() {
        stageLabel.fontSize = 15
        stageLabel.fontColor = DraftLook.ink
        stageLabel.horizontalAlignmentMode = .left
        stageLabel.verticalAlignmentMode = .center
        stageLabel.text = stage.name.uppercased()
        hudLayer.addChild(stageLabel)

        scoreLabel.fontSize = 18
        scoreLabel.fontColor = DraftLook.ink
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .center
        hudLayer.addChild(scoreLabel)

        goalLabel.fontSize = 13
        goalLabel.fontColor = DraftLook.ink.withAlphaComponent(0.85)
        goalLabel.horizontalAlignmentMode = .left
        goalLabel.verticalAlignmentMode = .center
        hudLayer.addChild(goalLabel)

        livesLabel.fontSize = 13
        livesLabel.fontColor = DraftLook.payload
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.verticalAlignmentMode = .center
        hudLayer.addChild(livesLabel)

        swayLabel.fontSize = 12
        swayLabel.fontColor = DraftLook.ink
        swayLabel.horizontalAlignmentMode = .center
        swayLabel.verticalAlignmentMode = .center
        hudLayer.addChild(swayLabel)

        hintLabel.fontSize = 11
        hintLabel.fontColor = DraftLook.ink.withAlphaComponent(0.7)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.numberOfLines = 2
        hudLayer.addChild(hintLabel)

        backHit.path = CGPath(roundedRect: CGRect(x: -36, y: -16, width: 72, height: 32), cornerWidth: 8, cornerHeight: 8, transform: nil)
        backHit.fillColor = DraftLook.ink.withAlphaComponent(0.08)
        backHit.strokeColor = DraftLook.ink
        backHit.lineWidth = 1.5
        let backText = SKLabelNode(fontNamed: "AvenirNext-Bold")
        backText.text = "EXIT"
        backText.fontSize = 12
        backText.fontColor = DraftLook.ink
        backText.verticalAlignmentMode = .center
        backHit.addChild(backText)
        hudLayer.addChild(backHit)
        refreshHUDLayout()
    }

    private func refreshHUDLayout() {
        let yTop = size.height - topSafe - 20
        backHit.position = CGPoint(x: 50, y: yTop)
        stageLabel.position = CGPoint(x: 92, y: yTop)
        scoreLabel.position = CGPoint(x: size.width - 18, y: yTop)
        goalLabel.position = CGPoint(x: 18, y: yTop - 26)
        livesLabel.position = CGPoint(x: size.width - 18, y: yTop - 26)
        swayLabel.position = CGPoint(x: size.width / 2, y: yTop - 26)
        let hintY = min(planRect.maxY + 14, yTop - 48)
        hintLabel.position = CGPoint(x: size.width / 2, y: hintY)
        hintLabel.preferredMaxLayoutWidth = size.width - 36
    }

    private func planPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: planRect.minX + p.x * planRect.width,
            y: planRect.minY + p.y * planRect.height
        )
    }

    private func payloadPlan() -> CGPoint {
        let cable = 0.22 + hoist * 0.55
        return CGPoint(
            x: trolley.x + sin(swingX) * cable * 0.45,
            y: trolley.y + sin(swingZ) * cable * 0.45
        )
    }

    private func swayAmount() -> CGFloat {
        hypot(omegaX, omegaZ) + hypot(swingX, swingZ) * 1.4
    }

    override func update(_ currentTime: TimeInterval) {
        if finished { return }
        let dt = lastTime == 0 ? 1.0 / 60.0 : min(currentTime - lastTime, 1.0 / 30.0)
        lastTime = currentTime
        elapsed += dt
        stepPhysics(dt: CGFloat(dt))
        if flashAge > 0 {
            flashAge -= dt
            if flashAge <= 0 { flashText = nil }
        }
        checkLock(dt: dt)
        redraw()
        refreshHUDText()
        if hintLabel.alpha > 0 {
            hintLabel.alpha = max(0, hintLabel.alpha - CGFloat(dt) * 0.12)
        }
    }

    private func stepPhysics(dt: CGFloat) {
        let accelX = (trolley.x - lastTrolley.x) / max(dt, 0.001)
        let accelZ = (trolley.y - lastTrolley.y) / max(dt, 0.001)
        lastTrolley = trolley

        let length = 0.35 + hoist * 0.85
        let gravity: CGFloat = 9.4
        omegaX += (-gravity / length) * sin(swingX) * dt
        omegaZ += (-gravity / length) * sin(swingZ) * dt
        omegaX += -accelX * stage.swayGain * dt
        omegaZ += -accelZ * stage.swayGain * dt
        let gust = sin(elapsed * (1.1 + Double(stage.gustRate))) * Double(stage.wind)
        omegaX += CGFloat(gust) * dt
        omegaZ += CGFloat(cos(elapsed * 0.87)) * stage.wind * 0.65 * dt
        omegaX *= (1 - 0.18 * dt)
        omegaZ *= (1 - 0.18 * dt)
        swingX += omegaX * dt
        swingZ += omegaZ * dt
        swingX = max(-1.1, min(1.1, swingX))
        swingZ = max(-1.1, min(1.1, swingZ))

        if hoist < 0.08 {
            let dropRisk = swayAmount() > stage.stableLimit * 1.65 || hypot(omegaX, omegaZ) > 2.4
            if dropRisk {
                dropPayload(reason: .sway)
            }
        }
    }

    private enum DropKind {
        case sway
        case fleet
    }

    private func checkLock(dt: TimeInterval) {
        guard let job = currentJob else { return }
        let payload = payloadPlan()
        let slot = slots[job.slotIndex]
        let dist = hypot(payload.x - slot.plan.x, payload.y - slot.plan.y)
        let stable = swayAmount() < stage.stableLimit
        let low = hoist < 0.16
        if dist < stage.placeRadius && stable && low {
            lockHold += dt
            if lockHold > 0.35 {
                placeCurrent()
            }
        } else {
            lockHold = max(0, lockHold - dt * 0.6)
        }
    }

    private func placeCurrent() {
        guard let job = currentJob else { return }
        slots[job.slotIndex].occupied = true
        hits += 1
        combo += 1
        let bonus = Int((1 - min(1, swayAmount())) * 40) + combo * 8
        score += 100 + bonus
        flash("SET  +\(100 + bonus)", hold: 0.9)
        currentJob = nil
        if hits >= stage.targetSets {
            FeedbackService.shared.playClear()
            endLift(cleared: true)
        } else {
            FeedbackService.shared.playSet()
            attachNextJob()
        }
    }

    private func dropPayload(reason: DropKind) {
        guard currentJob != nil else { return }
        let payload = payloadPlan()
        let hitFleet = fleet.contains { hypot($0.plan.x - payload.x, $0.plan.y - payload.y) < 0.10 }
        lives -= 1
        combo = 0
        if hitFleet || reason == .fleet {
            score = max(0, score - 50)
            flash("FLEET HIT  -50", hold: 1.1)
            shake()
        } else {
            score = max(0, score - 20)
            flash("PAYLOAD LOST  -20", hold: 1.0)
        }
        FeedbackService.shared.playDrop()
        currentJob = nil
        if lives <= 0 {
            endLift(cleared: false)
        } else {
            attachNextJob()
        }
    }

    private func endLift(cleared: Bool) {
        guard !finished else { return }
        finished = true
        PlayerStore.shared.finish(stageIndex: stageIndex, score: score, hits: hits, cleared: cleared)
        onFinish?(score, hits, cleared)
    }

    private func shake() {
        let move = SKAction.sequence([
            SKAction.moveBy(x: 6, y: 0, duration: 0.04),
            SKAction.moveBy(x: -12, y: 0, duration: 0.06),
            SKAction.moveBy(x: 6, y: 0, duration: 0.04)
        ])
        world.run(move)
    }

    private func flash(_ text: String, hold: TimeInterval) {
        flashText = text
        flashAge = hold
    }

    private func refreshHUDText() {
        scoreLabel.text = "SCORE  \(score)"
        goalLabel.text = "SETS  \(hits)/\(stage.targetSets)"
        livesLabel.text = "LIVES  \(lives)"
        let sway = swayAmount()
        if sway < stage.stableLimit * 0.7 {
            swayLabel.text = "SWAY  STEADY"
            swayLabel.fontColor = UIColor(red: 0.12, green: 0.62, blue: 0.28, alpha: 1)
        } else if sway < stage.stableLimit * 1.2 {
            swayLabel.text = "SWAY  LIVE"
            swayLabel.fontColor = DraftLook.payload
        } else {
            swayLabel.text = "SWAY  WILD"
            swayLabel.fontColor = DraftLook.hazard
        }
    }

    private func redraw() {
        planLayer.removeAllChildren()
        yardLayer.removeAllChildren()
        drawBlueprintPane()
        drawYardPane()
        if let flashText {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = flashText
            label.fontSize = 18
            label.fontColor = DraftLook.payload
            label.position = CGPoint(x: size.width / 2, y: planRect.midY)
            label.zPosition = 40
            planLayer.addChild(label)
        }
    }

    private func strokeRect(_ rect: CGRect, parent: SKNode, line: CGFloat = 1.6, fill: UIColor = .clear) {
        let node = SKShapeNode(rect: rect, cornerRadius: 10)
        node.fillColor = fill
        node.strokeColor = DraftLook.inkLine
        node.lineWidth = line
        parent.addChild(node)
    }

    private func drawGrid(in rect: CGRect, parent: SKNode, step: CGFloat) {
        let path = CGMutablePath()
        var x = rect.minX
        while x <= rect.maxX + 0.5 {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY + 0.5 {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        let grid = SKShapeNode(path: path)
        grid.strokeColor = DraftLook.ink.withAlphaComponent(0.12)
        grid.lineWidth = 0.8
        parent.addChild(grid)
    }

    private func drawBlueprintPane() {
        strokeRect(planRect, parent: planLayer, fill: UIColor.white)
        drawGrid(in: planRect.insetBy(dx: 8, dy: 8), parent: planLayer, step: 22)

        let caption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        caption.text = "PLAN VIEW  ·  \(stage.caption)"
        caption.fontSize = 11
        caption.fontColor = DraftLook.ink
        caption.horizontalAlignmentMode = .left
        caption.position = CGPoint(x: planRect.minX + 12, y: planRect.maxY - 18)
        planLayer.addChild(caption)

        let deck = SKShapeNode(rect: CGRect(
            x: planRect.minX + planRect.width * 0.28,
            y: planRect.minY + planRect.height * 0.16,
            width: planRect.width * 0.62,
            height: planRect.height * 0.68
        ), cornerRadius: 4)
        deck.fillColor = DraftLook.ink.withAlphaComponent(0.03)
        deck.strokeColor = DraftLook.inkLine
        deck.lineWidth = 1.4
        planLayer.addChild(deck)

        for slot in slots {
            let p = planPoint(slot.plan)
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.position = p
            ring.strokeColor = slot.tint
            ring.fillColor = slot.occupied ? slot.tint.withAlphaComponent(0.55) : slot.tint.withAlphaComponent(0.12)
            ring.lineWidth = 2.4
            planLayer.addChild(ring)
            let pin = SKShapeNode(circleOfRadius: 4)
            pin.position = p
            pin.fillColor = slot.tint
            pin.strokeColor = .clear
            planLayer.addChild(pin)
        }

        for mark in fleet {
            let p = planPoint(mark.plan)
            let truck = SKShapeNode(rectOf: CGSize(width: 22, height: 12), cornerRadius: 2)
            truck.position = p
            truck.fillColor = DraftLook.ink.withAlphaComponent(0.08)
            truck.strokeColor = DraftLook.hazard.withAlphaComponent(0.7)
            truck.lineWidth = 1.2
            planLayer.addChild(truck)
        }

        let tower = planPoint(towerPlan)
        let mast = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 1)
        mast.position = tower
        mast.fillColor = DraftLook.paper
        mast.strokeColor = DraftLook.ink
        mast.lineWidth = 2
        planLayer.addChild(mast)

        let trolleyScreen = planPoint(trolley)
        let jib = SKShapeNode()
        let jibPath = CGMutablePath()
        jibPath.move(to: tower)
        jibPath.addLine(to: trolleyScreen)
        jib.path = jibPath
        jib.strokeColor = DraftLook.ink
        jib.lineWidth = 2
        planLayer.addChild(jib)

        let trolleyMark = SKShapeNode(circleOfRadius: 6)
        trolleyMark.position = trolleyScreen
        trolleyMark.fillColor = DraftLook.ink
        trolleyMark.strokeColor = .clear
        planLayer.addChild(trolleyMark)

        if let job = currentJob {
            let payload = planPoint(payloadPlan())
            let size = job.kind == .girder ? CGSize(width: 34, height: 12) : CGSize(width: 22, height: 22)
            let body = SKShapeNode(rectOf: size, cornerRadius: 2)
            body.position = payload
            body.fillColor = DraftLook.payload
            body.strokeColor = DraftLook.inkDark
            body.lineWidth = 1.4
            planLayer.addChild(body)
            let pin = SKShapeNode(circleOfRadius: 4)
            pin.position = payload
            pin.fillColor = job.tint
            pin.strokeColor = UIColor.white
            pin.lineWidth = 1
            planLayer.addChild(pin)

            let cable = SKShapeNode()
            let cpath = CGMutablePath()
            cpath.move(to: trolleyScreen)
            cpath.addLine(to: payload)
            cable.path = cpath
            cable.strokeColor = DraftLook.ink.withAlphaComponent(0.55)
            cable.lineWidth = 1
            planLayer.addChild(cable)

            let target = planPoint(slots[job.slotIndex].plan)
            let guide = SKShapeNode()
            let gpath = CGMutablePath()
            gpath.move(to: payload)
            gpath.addLine(to: target)
            guide.path = gpath
            guide.strokeColor = job.tint.withAlphaComponent(0.35)
            guide.lineWidth = 1
            planLayer.addChild(guide)
        }
    }

    private func drawYardPane() {
        strokeRect(yardRect, parent: yardLayer, fill: UIColor.white)
        drawGrid(in: yardRect.insetBy(dx: 8, dy: 8), parent: yardLayer, step: 18)

        let caption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        caption.text = "GROUND VIEW  ·  HOIST + SWAY"
        caption.fontSize = 11
        caption.fontColor = DraftLook.ink
        caption.horizontalAlignmentMode = .left
        caption.position = CGPoint(x: yardRect.minX + 12, y: yardRect.maxY - 18)
        yardLayer.addChild(caption)

        let groundY = yardRect.minY + 22
        let ground = SKShapeNode()
        let gpath = CGMutablePath()
        gpath.move(to: CGPoint(x: yardRect.minX + 8, y: groundY))
        gpath.addLine(to: CGPoint(x: yardRect.maxX - 8, y: groundY))
        ground.path = gpath
        ground.strokeColor = DraftLook.inkLine
        ground.lineWidth = 2
        yardLayer.addChild(ground)

        let mastX = yardRect.minX + 36
        let mastTop = yardRect.maxY - 28
        let mast = SKShapeNode(rect: CGRect(x: mastX - 7, y: groundY, width: 14, height: mastTop - groundY))
        mast.fillColor = DraftLook.ink.withAlphaComponent(0.06)
        mast.strokeColor = DraftLook.ink
        mast.lineWidth = 1.6
        yardLayer.addChild(mast)

        let jibY = mastTop - 4
        let jib = SKShapeNode()
        let jpath = CGMutablePath()
        jpath.move(to: CGPoint(x: mastX, y: jibY))
        jpath.addLine(to: CGPoint(x: yardRect.maxX - 24, y: jibY))
        jib.path = jpath
        jib.strokeColor = DraftLook.ink
        jib.lineWidth = 2.2
        yardLayer.addChild(jib)

        let hookX = yardRect.minX + 70 + trolley.x * (yardRect.width - 110)
        let hookY = groundY + 36 + hoist * (jibY - groundY - 70)
        let swayPx = sin(swingX) * (40 + hoist * 50)

        for (index, mark) in fleet.enumerated() {
            let fx = yardRect.minX + 50 + mark.plan.x * (yardRect.width - 90)
            let truck = SKShapeNode(rectOf: CGSize(width: 28, height: 14), cornerRadius: 2)
            truck.position = CGPoint(x: fx + CGFloat(index % 2) * 6, y: groundY + 10)
            truck.fillColor = DraftLook.hazard.withAlphaComponent(0.18)
            truck.strokeColor = DraftLook.hazard
            truck.lineWidth = 1.2
            yardLayer.addChild(truck)
        }

        let cable = SKShapeNode()
        let cpath = CGMutablePath()
        cpath.move(to: CGPoint(x: hookX, y: jibY))
        cpath.addLine(to: CGPoint(x: hookX + swayPx, y: hookY))
        cable.path = cpath
        cable.strokeColor = DraftLook.ink
        cable.lineWidth = 1.4
        yardLayer.addChild(cable)

        if let job = currentJob {
            let size = job.kind == .girder ? CGSize(width: 48, height: 16) : CGSize(width: 28, height: 24)
            let body = SKShapeNode(rectOf: size, cornerRadius: 2)
            body.position = CGPoint(x: hookX + swayPx, y: hookY - size.height * 0.35)
            body.fillColor = DraftLook.payload
            body.strokeColor = DraftLook.inkDark
            body.lineWidth = 1.5
            body.zRotation = swingX * 0.35
            yardLayer.addChild(body)
            let pin = SKShapeNode(circleOfRadius: 5)
            pin.position = CGPoint(x: hookX + swayPx, y: hookY - 2)
            pin.fillColor = job.tint
            pin.strokeColor = UIColor.white
            pin.lineWidth = 1
            yardLayer.addChild(pin)
        }

        let trolleyMark = SKShapeNode(rectOf: CGSize(width: 16, height: 8), cornerRadius: 1)
        trolleyMark.position = CGPoint(x: hookX, y: jibY)
        trolleyMark.fillColor = DraftLook.ink
        trolleyMark.strokeColor = .clear
        yardLayer.addChild(trolleyMark)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        if backHit.contains(convert(p, to: hudLayer)) || backHit.frame.insetBy(dx: -10, dy: -10).contains(convert(p, to: hudLayer)) {
            onExit?()
            return
        }
        let local = convert(p, to: hudLayer)
        if hypot(local.x - backHit.position.x, local.y - backHit.position.y) < 44 {
            onExit?()
            return
        }
        lastTouch = p
        swipeTrail = [p]
        if planRect.contains(p) {
            dragMode = 1
        } else if yardRect.contains(p) {
            dragMode = 2
        } else {
            dragMode = 0
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        let dx = p.x - lastTouch.x
        let dy = p.y - lastTouch.y
        lastTouch = p
        swipeTrail.append(p)
        if swipeTrail.count > 8 { swipeTrail.removeFirst() }

        if dragMode == 1 {
            trolley.x = min(0.92, max(0.18, trolley.x + dx / planRect.width))
            trolley.y = min(0.90, max(0.12, trolley.y + dy / planRect.height))
            applyCounterSway(dx: dx, dy: dy)
        } else if dragMode == 2 {
            hoist = min(0.96, max(0.04, hoist + dy / yardRect.height))
            applyCounterSway(dx: dx, dy: 0)
            if hoist < 0.07 && swayAmount() > stage.stableLimit * 1.4 {
                let payload = payloadPlan()
                if fleet.contains(where: { hypot($0.plan.x - payload.x, $0.plan.y - payload.y) < 0.10 }) {
                    dropPayload(reason: .fleet)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if swipeTrail.count >= 2 {
            let first = swipeTrail.first!
            let last = swipeTrail.last!
            let vx = last.x - first.x
            let vy = last.y - first.y
            applyCounterSway(dx: vx * 0.35, dy: vy * 0.35)
        }
        dragMode = 0
        swipeTrail.removeAll()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragMode = 0
        swipeTrail.removeAll()
    }

    private func applyCounterSway(dx: CGFloat, dy: CGFloat) {
        let impulseX = dx * 0.012
        let impulseZ = dy * 0.012
        if impulseX * omegaX < 0 {
            omegaX += impulseX
            omegaX *= 0.82
            swingX *= 0.92
        } else {
            omegaX += impulseX * 0.22
        }
        if impulseZ * omegaZ < 0 {
            omegaZ += impulseZ
            omegaZ *= 0.82
            swingZ *= 0.92
        } else {
            omegaZ += impulseZ * 0.22
        }
    }
}
