import UIKit
import AVFoundation

class GradientBackdropController: UIViewController {
    private let gridLayer = CAShapeLayer()
    private let frameLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DraftLook.paper
        gridLayer.strokeColor = DraftLook.ink.withAlphaComponent(0.08).cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 0.6
        view.layer.insertSublayer(gridLayer, at: 0)

        frameLayer.strokeColor = DraftLook.ink.withAlphaComponent(0.35).cgColor
        frameLayer.fillColor = UIColor.clear.cgColor
        frameLayer.lineWidth = 1.2
        view.layer.insertSublayer(frameLayer, at: 1)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        redrawSheet()
    }

    private func redrawSheet() {
        let bounds = view.bounds
        gridLayer.frame = bounds
        frameLayer.frame = bounds

        let path = UIBezierPath()
        let major: CGFloat = 48
        var x: CGFloat = 0
        while x <= bounds.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: bounds.height))
            x += major
        }
        var y: CGFloat = 0
        while y <= bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
            y += major
        }
        gridLayer.path = path.cgPath

        let inset: CGFloat = 14
        frameLayer.path = UIBezierPath(rect: bounds.insetBy(dx: inset, dy: inset)).cgPath
    }

    func draftTitle(_ text: String, size: CGFloat = 34) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = DraftLook.ink
        label.font = UIFont(name: "AvenirNextCondensed-Heavy", size: size) ?? .systemFont(ofSize: size, weight: .black)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func titleLabel(_ text: String, size: CGFloat = 34) -> UILabel {
        draftTitle(text, size: size)
    }

    func actionButton(_ text: String, symbol: String? = nil) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(text, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "AvenirNextCondensed-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = DraftLook.ink
        button.layer.cornerRadius = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        if let symbol, let image = UIImage(systemName: symbol) {
            button.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
            button.tintColor = .white
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func sheetLink(_ text: String) -> UIButton {
        let button = UIButton(type: .system)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: "AvenirNextCondensed-DemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: DraftLook.ink,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: DraftLook.ink.withAlphaComponent(0.35)
            ]
        )
        button.setAttributedTitle(attributed, for: .normal)
        button.contentHorizontalAlignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    override var prefersStatusBarHidden: Bool { true }
}

final class CraneDraftView: UIView {
    private let mast = CAShapeLayer()
    private let jib = CAShapeLayer()
    private let cable = CAShapeLayer()
    private let hook = CAShapeLayer()
    private let payload = CAShapeLayer()
    private let base = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for layer in [mast, jib, cable, hook, payload, base] {
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = DraftLook.ink.cgColor
            layer.lineWidth = 2.2
            layer.lineCap = .round
            layer.lineJoin = .round
            self.layer.addSublayer(layer)
        }
        payload.fillColor = DraftLook.payload.cgColor
        payload.strokeColor = DraftLook.inkDark.cgColor
        payload.lineWidth = 1.4
        base.fillColor = DraftLook.ink.withAlphaComponent(0.06).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawCrane()
        startMotion()
    }

    private func drawCrane() {
        let w = bounds.width
        let h = bounds.height
        guard w > 10, h > 10 else { return }

        let mastX = w * 0.22
        let groundY = h * 0.88
        let topY = h * 0.12
        let jibEndX = w * 0.92
        let hookX = w * 0.68
        let hookY = h * 0.52

        let mastPath = UIBezierPath()
        mastPath.move(to: CGPoint(x: mastX - 8, y: groundY))
        mastPath.addLine(to: CGPoint(x: mastX - 4, y: topY))
        mastPath.addLine(to: CGPoint(x: mastX + 4, y: topY))
        mastPath.addLine(to: CGPoint(x: mastX + 8, y: groundY))
        mastPath.close()
        var crossY = topY + 18
        while crossY < groundY - 20 {
            mastPath.move(to: CGPoint(x: mastX - 6, y: crossY))
            mastPath.addLine(to: CGPoint(x: mastX + 6, y: crossY + 10))
            crossY += 22
        }
        mast.path = mastPath.cgPath

        let basePath = UIBezierPath(rect: CGRect(x: mastX - 28, y: groundY - 6, width: 56, height: 14))
        base.path = basePath.cgPath
        base.strokeColor = DraftLook.ink.cgColor

        let jibPath = UIBezierPath()
        jibPath.move(to: CGPoint(x: mastX - 18, y: topY + 10))
        jibPath.addLine(to: CGPoint(x: jibEndX, y: topY + 4))
        jibPath.move(to: CGPoint(x: mastX, y: topY + 28))
        jibPath.addLine(to: CGPoint(x: jibEndX - 20, y: topY + 10))
        jib.path = jibPath.cgPath

        let cablePath = UIBezierPath()
        cablePath.move(to: CGPoint(x: hookX, y: topY + 6))
        cablePath.addLine(to: CGPoint(x: hookX, y: hookY))
        cable.path = cablePath.cgPath

        let hookPath = UIBezierPath()
        hookPath.move(to: CGPoint(x: hookX - 8, y: hookY))
        hookPath.addLine(to: CGPoint(x: hookX + 8, y: hookY))
        hookPath.move(to: CGPoint(x: hookX, y: hookY))
        hookPath.addCurve(
            to: CGPoint(x: hookX, y: hookY + 16),
            controlPoint1: CGPoint(x: hookX + 10, y: hookY + 4),
            controlPoint2: CGPoint(x: hookX + 10, y: hookY + 12)
        )
        hook.path = hookPath.cgPath

        payload.path = UIBezierPath(roundedRect: CGRect(x: hookX - 18, y: hookY + 14, width: 36, height: 26), cornerRadius: 2).cgPath
    }

    private func startMotion() {
        cable.removeAllAnimations()
        payload.removeAllAnimations()
        jib.removeAllAnimations()

        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -0.035
        sway.toValue = 0.035
        sway.duration = 2.4
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let anchor = CGPoint(x: bounds.width * 0.68, y: bounds.height * 0.12)
        cable.anchorPoint = CGPoint(x: 0.5, y: 0)
        let cableFrame = cable.frame
        cable.position = CGPoint(x: anchor.x, y: cableFrame.minY)
        cable.add(sway, forKey: "sway")

        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = -4
        bob.toValue = 5
        bob.duration = 2.4
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        payload.add(bob, forKey: "bob")
        payload.add(sway, forKey: "sway")

        let jibNod = CABasicAnimation(keyPath: "transform.rotation.z")
        jibNod.fromValue = -0.008
        jibNod.toValue = 0.008
        jibNod.duration = 3.6
        jibNod.autoreverses = true
        jibNod.repeatCount = .infinity
        jib.add(jibNod, forKey: "nod")
    }
}

final class MenuViewController: GradientBackdropController {
    private let brandLine = UILabel()
    private let brandSteel = UILabel()
    private let tagline = UILabel()
    private let enterButton = UIButton(type: .system)
    private let progressMark = UILabel()
    private let bestMark = UILabel()
    private let sheetCode = UILabel()
    private let profileButton = UIButton(type: .custom)
    private let craneView = CraneDraftView()
    private let noteStack = UIStackView()
    private let titleRule = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        refresh()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .playerProfileDidChange, object: nil)
        runIntroMotion()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        navigationController?.setNavigationBarHidden(true, animated: false)
        OrientationController.shared.lockToPortrait()
    }

    private func buildInterface() {
        craneView.translatesAutoresizingMaskIntoConstraints = false
        craneView.alpha = 0.55
        view.addSubview(craneView)

        sheetCode.text = "DWG  SS-01  ·  TOWER CRANE OPS"
        sheetCode.font = UIFont(name: "AvenirNextCondensed-Medium", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        sheetCode.textColor = DraftLook.ink.withAlphaComponent(0.55)
        sheetCode.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetCode)

        brandLine.text = "STITCH"
        brandLine.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 64) ?? .systemFont(ofSize: 64, weight: .black)
        brandLine.textColor = DraftLook.ink
        brandLine.translatesAutoresizingMaskIntoConstraints = false
        brandLine.adjustsFontSizeToFitWidth = true
        brandLine.minimumScaleFactor = 0.7
        view.addSubview(brandLine)

        brandSteel.text = "& STEEL"
        brandSteel.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 52) ?? .systemFont(ofSize: 52, weight: .black)
        brandSteel.textColor = DraftLook.payload
        brandSteel.translatesAutoresizingMaskIntoConstraints = false
        brandSteel.adjustsFontSizeToFitWidth = true
        brandSteel.minimumScaleFactor = 0.7
        view.addSubview(brandSteel)

        titleRule.backgroundColor = DraftLook.ink
        titleRule.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleRule)

        tagline.text = "Hoist the deck. Kill the sway."
        tagline.font = UIFont(name: "AvenirNext-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        tagline.textColor = DraftLook.ink.withAlphaComponent(0.72)
        tagline.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagline)

        enterButton.setTitle("  ENTER YARD  →", for: .normal)
        enterButton.setTitleColor(.white, for: .normal)
        enterButton.titleLabel?.font = UIFont(name: "AvenirNextCondensed-Bold", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        enterButton.backgroundColor = DraftLook.payload
        enterButton.contentHorizontalAlignment = .left
        enterButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        enterButton.translatesAutoresizingMaskIntoConstraints = false
        enterButton.addTarget(self, action: #selector(openStages), for: .touchUpInside)
        view.addSubview(enterButton)

        progressMark.font = UIFont(name: "AvenirNextCondensed-DemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        progressMark.textColor = DraftLook.ink
        progressMark.numberOfLines = 2
        progressMark.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressMark)

        bestMark.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 13) ?? .systemFont(ofSize: 13, weight: .heavy)
        bestMark.textColor = DraftLook.ink.withAlphaComponent(0.7)
        bestMark.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bestMark)

        profileButton.clipsToBounds = true
        profileButton.layer.cornerRadius = 0
        profileButton.layer.borderWidth = 2
        profileButton.layer.borderColor = DraftLook.ink.cgColor
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        view.addSubview(profileButton)

        let profile = sheetLink("OPERATOR")
        profile.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        let stats = sheetLink("FIELD LOG")
        stats.addTarget(self, action: #selector(openStats), for: .touchUpInside)
        let guide = sheetLink("BRIEFING")
        guide.addTarget(self, action: #selector(openGuide), for: .touchUpInside)
        let settings = sheetLink("CONTROLS")
        settings.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        let privacy = sheetLink("PRIVACY")
        privacy.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)

        noteStack.axis = .vertical
        noteStack.alignment = .leading
        noteStack.spacing = 10
        noteStack.translatesAutoresizingMaskIntoConstraints = false
        [profile, stats, guide, settings, privacy].forEach { noteStack.addArrangedSubview($0) }
        view.addSubview(noteStack)

        let margin: CGFloat = 28
        NSLayoutConstraint.activate([
            sheetCode.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            sheetCode.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            profileButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            profileButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            profileButton.widthAnchor.constraint(equalToConstant: 52),
            profileButton.heightAnchor.constraint(equalToConstant: 52),

            craneView.topAnchor.constraint(equalTo: profileButton.bottomAnchor, constant: 8),
            craneView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            craneView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.58),
            craneView.bottomAnchor.constraint(equalTo: enterButton.topAnchor, constant: -24),

            brandLine.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            brandLine.trailingAnchor.constraint(lessThanOrEqualTo: craneView.leadingAnchor, constant: 40),
            brandLine.topAnchor.constraint(equalTo: sheetCode.bottomAnchor, constant: 28),

            brandSteel.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            brandSteel.trailingAnchor.constraint(lessThanOrEqualTo: craneView.leadingAnchor, constant: 48),
            brandSteel.topAnchor.constraint(equalTo: brandLine.bottomAnchor, constant: -6),

            titleRule.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            titleRule.topAnchor.constraint(equalTo: brandSteel.bottomAnchor, constant: 12),
            titleRule.widthAnchor.constraint(equalToConstant: 72),
            titleRule.heightAnchor.constraint(equalToConstant: 3),

            tagline.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            tagline.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -margin),
            tagline.topAnchor.constraint(equalTo: titleRule.bottomAnchor, constant: 12),

            noteStack.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            noteStack.topAnchor.constraint(equalTo: tagline.bottomAnchor, constant: 28),

            progressMark.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            progressMark.trailingAnchor.constraint(lessThanOrEqualTo: view.centerXAnchor, constant: 40),
            progressMark.bottomAnchor.constraint(equalTo: bestMark.topAnchor, constant: -4),

            bestMark.leadingAnchor.constraint(equalTo: brandLine.leadingAnchor),
            bestMark.bottomAnchor.constraint(equalTo: enterButton.topAnchor, constant: -16),

            enterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            enterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            enterButton.heightAnchor.constraint(equalToConstant: 58),
            enterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])
    }

    private func runIntroMotion() {
        brandLine.alpha = 0
        brandSteel.alpha = 0
        tagline.alpha = 0
        noteStack.alpha = 0
        enterButton.transform = CGAffineTransform(translationX: 0, y: 24)
        enterButton.alpha = 0
        craneView.transform = CGAffineTransform(translationX: 30, y: 0)

        UIView.animate(withDuration: 0.55, delay: 0.05, options: [.curveEaseOut]) {
            self.brandLine.alpha = 1
            self.craneView.transform = .identity
        }
        UIView.animate(withDuration: 0.55, delay: 0.14, options: [.curveEaseOut]) {
            self.brandSteel.alpha = 1
        }
        UIView.animate(withDuration: 0.5, delay: 0.24, options: [.curveEaseOut]) {
            self.tagline.alpha = 1
            self.noteStack.alpha = 1
        }
        UIView.animate(withDuration: 0.55, delay: 0.32, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4, options: []) {
            self.enterButton.alpha = 1
            self.enterButton.transform = .identity
        }
    }

    @objc private func refresh() {
        let opened = PlayerStore.shared.stagesOpened
        let total = LiftStage.all.count
        let stage = LiftStage.all[PlayerStore.shared.selectedStage]
        progressMark.text = "DECK  \(opened)/\(total)\nNEXT  \(stage.name.uppercased())"
        bestMark.text = "BEST SET  \(PlayerStore.shared.best)"

        if let image = ProfileManager.shared.portrait() {
            profileButton.setImage(image, for: .normal)
            profileButton.backgroundColor = .clear
            profileButton.tintColor = nil
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            profileButton.setImage(UIImage(systemName: "person.fill", withConfiguration: config), for: .normal)
            profileButton.tintColor = DraftLook.ink
            profileButton.backgroundColor = DraftLook.ink.withAlphaComponent(0.06)
        }
    }

    @objc private func openStages() {
        navigationController?.pushViewController(StageSelectViewController(), animated: true)
    }

    @objc private func openProfile() {
        navigationController?.pushViewController(ProfileViewController(), animated: true)
    }

    @objc private func openStats() {
        navigationController?.pushViewController(StatisticsViewController(), animated: true)
    }

    @objc private func openGuide() {
        navigationController?.pushViewController(GuideViewController(), animated: true)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func openPrivacy() {
        let privacy = PrivacyPolicyViewController(addressString: AppConstants.privacyPolicyAddress)
        let nav = UINavigationController(rootViewController: privacy)
        present(nav, animated: true)
    }
}

final class StageSelectViewController: GradientBackdropController {
    private let stack = UIStackView()
    private let header = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        header.text = "FLOOR SCHEDULE"
        header.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 34) ?? .systemFont(ofSize: 34, weight: .black)
        header.textColor = DraftLook.ink
        header.translatesAutoresizingMaskIntoConstraints = false

        let mark = UILabel()
        mark.text = "CLEAR A DECK TO OPEN THE NEXT"
        mark.font = UIFont(name: "AvenirNextCondensed-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        mark.textColor = DraftLook.ink.withAlphaComponent(0.55)
        mark.translatesAutoresizingMaskIntoConstraints = false

        let back = sheetLink("← RETURN TO SHEET")
        back.addTarget(self, action: #selector(close), for: .touchUpInside)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false

        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(mark)
        view.addSubview(back)
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            mark.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            mark.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            back.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            scroll.topAnchor.constraint(equalTo: mark.bottomAnchor, constant: 18),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: back.topAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
        rebuildRows()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuildRows()
    }

    private func rebuildRows() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, stage) in LiftStage.all.enumerated() {
            stack.addArrangedSubview(makeRow(index: index, stage: stage))
        }
    }

    private func makeRow(index: Int, stage: LiftStage) -> UIView {
        let unlocked = PlayerStore.shared.isUnlocked(index)
        let best = PlayerStore.shared.bestScore(for: index)

        let row = UIControl()
        row.tag = index
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addTarget(self, action: #selector(pickStage(_:)), for: .touchUpInside)

        let topRule = UIView()
        topRule.backgroundColor = DraftLook.ink.withAlphaComponent(index == 0 ? 0.45 : 0.18)
        topRule.translatesAutoresizingMaskIntoConstraints = false

        let indexLabel = UILabel()
        indexLabel.text = String(format: "%02d", index + 1)
        indexLabel.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 22) ?? .monospacedDigitSystemFont(ofSize: 22, weight: .heavy)
        indexLabel.textColor = unlocked ? DraftLook.payload : DraftLook.ink.withAlphaComponent(0.35)
        indexLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = stage.name.uppercased()
        nameLabel.font = UIFont(name: "AvenirNextCondensed-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = unlocked ? DraftLook.ink : DraftLook.ink.withAlphaComponent(0.4)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let detail = UILabel()
        if unlocked {
            let bestText = best > 0 ? "  ·  BEST \(best)" : ""
            detail.text = "\(stage.caption)  ·  \(stage.goalText)\(bestText)"
        } else {
            detail.text = "LOCKED  ·  CLEAR PREVIOUS DECK"
        }
        detail.font = UIFont(name: "AvenirNextCondensed-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        detail.textColor = DraftLook.ink.withAlphaComponent(unlocked ? 0.55 : 0.35)
        detail.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(topRule)
        row.addSubview(indexLabel)
        row.addSubview(nameLabel)
        row.addSubview(detail)
        row.heightAnchor.constraint(equalToConstant: 72).isActive = true

        NSLayoutConstraint.activate([
            topRule.topAnchor.constraint(equalTo: row.topAnchor),
            topRule.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            topRule.heightAnchor.constraint(equalToConstant: 1),
            indexLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            indexLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
            detail.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detail.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detail.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -8)
        ])
        row.alpha = unlocked ? 1 : 0.7
        return row
    }

    @objc private func pickStage(_ sender: UIControl) {
        let index = sender.tag
        guard PlayerStore.shared.isUnlocked(index) else {
            let alert = UIAlertController(
                title: "Stage Locked",
                message: "Reach the goal on the previous stage to open this one.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        PlayerStore.shared.selectedStage = index
        navigationController?.pushViewController(GameViewController(stageIndex: index), animated: true)
    }

    @objc private func close() {
        navigationController?.popViewController(animated: true)
    }
}

final class ProfileViewController: GradientBackdropController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    private let portrait = UIImageView()
    private let nameField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        let title = draftTitle("OPERATOR", size: 34)
        let back = sheetLink("← RETURN TO SHEET")
        back.addTarget(self, action: #selector(close), for: .touchUpInside)

        portrait.contentMode = .scaleAspectFill
        portrait.clipsToBounds = true
        portrait.layer.cornerRadius = 0
        portrait.layer.borderWidth = 2
        portrait.layer.borderColor = DraftLook.ink.cgColor
        portrait.translatesAutoresizingMaskIntoConstraints = false

        nameField.text = ProfileManager.shared.displayName
        nameField.textColor = DraftLook.ink
        nameField.font = UIFont(name: "AvenirNextCondensed-Bold", size: 22) ?? .systemFont(ofSize: 22, weight: .bold)
        nameField.textAlignment = .left
        nameField.backgroundColor = .clear
        nameField.borderStyle = .none
        nameField.attributedPlaceholder = NSAttributedString(
            string: "Operator name",
            attributes: [.foregroundColor: DraftLook.ink.withAlphaComponent(0.35)]
        )
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false

        let underline = UIView()
        underline.backgroundColor = DraftLook.ink.withAlphaComponent(0.35)
        underline.translatesAutoresizingMaskIntoConstraints = false

        let camera = sheetLink("TAKE PHOTO")
        camera.addTarget(self, action: #selector(useCamera), for: .touchUpInside)
        let library = sheetLink("CHOOSE PHOTO")
        library.addTarget(self, action: #selector(useLibrary), for: .touchUpInside)
        let remove = sheetLink("REMOVE PHOTO")
        remove.addTarget(self, action: #selector(removePhoto), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [camera, library, remove])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(back)
        view.addSubview(portrait)
        view.addSubview(nameField)
        view.addSubview(underline)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            back.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            back.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            portrait.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            portrait.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 28),
            portrait.widthAnchor.constraint(equalToConstant: 148),
            portrait.heightAnchor.constraint(equalToConstant: 148),
            nameField.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            nameField.topAnchor.constraint(equalTo: portrait.bottomAnchor, constant: 24),
            nameField.heightAnchor.constraint(equalToConstant: 40),
            underline.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),
            underline.topAnchor.constraint(equalTo: nameField.bottomAnchor),
            underline.heightAnchor.constraint(equalToConstant: 1.5),
            stack.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            stack.topAnchor.constraint(equalTo: underline.bottomAnchor, constant: 28)
        ])
        updatePortrait()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        ProfileManager.shared.displayName = textField.text ?? ""
        textField.resignFirstResponder()
        return true
    }

    @objc private func useCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentMessage("Camera is not available on this device.")
            return
        }
        requestCameraThenPick()
    }

    private func requestCameraThenPick() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showPicker(.camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showPicker(.camera)
                    } else {
                        self?.presentMessage("Camera access is required to take a portrait.")
                    }
                }
            }
        default:
            presentMessage("Camera access is required to take a portrait.")
        }
    }

    @objc private func useLibrary() {
        showPicker(.photoLibrary)
    }

    private func showPicker(_ source: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
            _ = ProfileManager.shared.savePortrait(image)
        }
        picker.dismiss(animated: true)
        updatePortrait()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    @objc private func removePhoto() {
        ProfileManager.shared.removePortrait()
        updatePortrait()
    }

    private func updatePortrait() {
        portrait.image = ProfileManager.shared.portrait() ?? UIImage(systemName: "person.crop.square.fill")
        portrait.tintColor = DraftLook.payload
        portrait.backgroundColor = DraftLook.ink.withAlphaComponent(0.06)
    }

    private func presentMessage(_ text: String) {
        let alert = UIAlertController(title: "Notice", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func close() {
        ProfileManager.shared.displayName = nameField.text ?? ""
        navigationController?.popViewController(animated: true)
    }
}

final class StatisticsViewController: GradientBackdropController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let data = PlayerStore.shared
        let title = draftTitle("FIELD LOG", size: 34)
        let back = sheetLink("← RETURN TO SHEET")
        back.addTarget(self, action: #selector(close), for: .touchUpInside)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let rows: [(String, String)] = [
            ("BEST SCORE", "\(data.best)"),
            ("LIFTS", "\(data.runs)"),
            ("SETS", "\(data.totalHits)"),
            ("DECKS OPEN", "\(data.stagesOpened)/\(LiftStage.all.count)")
        ]
        for (i, item) in rows.enumerated() {
            stack.addArrangedSubview(logRow(index: i, label: item.0, value: item.1))
        }

        view.addSubview(title)
        view.addSubview(stack)
        view.addSubview(back)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            back.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            back.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func logRow(index: Int, label: String, value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let rule = UIView()
        rule.backgroundColor = DraftLook.ink.withAlphaComponent(index == 0 ? 0.45 : 0.18)
        rule.translatesAutoresizingMaskIntoConstraints = false
        let left = UILabel()
        left.text = label
        left.font = UIFont(name: "AvenirNextCondensed-DemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold)
        left.textColor = DraftLook.ink.withAlphaComponent(0.65)
        left.translatesAutoresizingMaskIntoConstraints = false
        let right = UILabel()
        right.text = value
        right.font = UIFont(name: "AvenirNextCondensed-Heavy", size: 28) ?? .monospacedDigitSystemFont(ofSize: 28, weight: .heavy)
        right.textColor = DraftLook.ink
        right.textAlignment = .right
        right.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(rule)
        row.addSubview(left)
        row.addSubview(right)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 72),
            rule.topAnchor.constraint(equalTo: row.topAnchor),
            rule.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),
            left.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            left.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            right.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            right.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    @objc private func close() { navigationController?.popViewController(animated: true) }
}

final class GuideViewController: GradientBackdropController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let title = draftTitle("BRIEFING", size: 34)
        let body = UILabel()
        body.numberOfLines = 0
        body.textColor = DraftLook.ink
        body.font = UIFont(name: "AvenirNext-Medium", size: 17) ?? .systemFont(ofSize: 17, weight: .medium)
        body.text = "PLAN VIEW\nAlign the trolley to the colored pin on the floor sheet.\n\nGROUND VIEW\nThe cable carries wind. Swipe against the sway, then lower the hoist to set.\n\nHAZARD\nA drop onto yard vehicles costs a life and score. Clear the deck goal to open the next floor."
        body.translatesAutoresizingMaskIntoConstraints = false

        let back = UIButton(type: .system)
        back.setTitle("GOT IT", for: .normal)
        back.setTitleColor(.white, for: .normal)
        back.titleLabel?.font = UIFont(name: "AvenirNextCondensed-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        back.backgroundColor = DraftLook.payload
        back.translatesAutoresizingMaskIntoConstraints = false
        back.addTarget(self, action: #selector(close), for: .touchUpInside)

        view.addSubview(title)
        view.addSubview(body)
        view.addSubview(back)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            back.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            back.heightAnchor.constraint(equalToConstant: 54),
            back.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    @objc private func close() { navigationController?.popViewController(animated: true) }
}

final class SettingsViewController: GradientBackdropController {
    private let soundSwitch = UISwitch()
    private let hapticsSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        let title = draftTitle("CONTROLS", size: 34)
        let sound = settingRow("SOUND", control: soundSwitch, action: #selector(soundChanged(_:)))
        let haptics = settingRow("HAPTICS", control: hapticsSwitch, action: #selector(hapticsChanged(_:)))
        let stack = UIStackView(arrangedSubviews: [sound, haptics])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        let back = sheetLink("← RETURN TO SHEET")
        back.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(title)
        view.addSubview(stack)
        view.addSubview(back)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 28),
            back.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            back.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        reloadSwitches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadSwitches()
    }

    private func reloadSwitches() {
        soundSwitch.isOn = PlayerStore.shared.soundEnabled
        hapticsSwitch.isOn = PlayerStore.shared.hapticsEnabled
    }

    private func settingRow(_ text: String, control: UISwitch, action: Selector) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let rule = UIView()
        rule.backgroundColor = DraftLook.ink.withAlphaComponent(0.2)
        rule.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = text
        label.textColor = DraftLook.ink
        label.font = UIFont(name: "AvenirNextCondensed-Bold", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        control.onTintColor = DraftLook.payload
        control.addTarget(self, action: action, for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rule)
        container.addSubview(label)
        container.addSubview(control)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 68),
            rule.topAnchor.constraint(equalTo: container.topAnchor),
            rule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func soundChanged(_ sender: UISwitch) {
        PlayerStore.shared.soundEnabled = sender.isOn
        if sender.isOn {
            FeedbackService.shared.previewSound()
        }
    }

    @objc private func hapticsChanged(_ sender: UISwitch) {
        PlayerStore.shared.hapticsEnabled = sender.isOn
        if sender.isOn {
            FeedbackService.shared.previewHaptics()
        }
    }

    @objc private func close() { navigationController?.popViewController(animated: true) }
}
