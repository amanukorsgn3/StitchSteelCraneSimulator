import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private let stageIndex: Int

    init(stageIndex: Int) {
        self.stageIndex = stageIndex
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.stageIndex = 0
        super.init(coder: coder)
    }

    private var didPresentScene = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DraftLook.paper
        let skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        view.addSubview(skView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view.subviews.first as? SKView else { return }
        if !didPresentScene {
            didPresentScene = true
            presentScene()
        } else if let scene = skView.scene as? GameScene {
            if scene.size != view.bounds.size {
                scene.size = view.bounds.size
            }
            scene.relayoutForSafeArea()
        }
    }

    private func currentStage() -> LiftStage {
        let index = min(max(stageIndex, 0), LiftStage.all.count - 1)
        return LiftStage.all[index]
    }

    private func presentScene(animated: Bool = false) {
        guard let skView = view.subviews.first as? SKView else { return }
        let stage = currentStage()
        let scene = GameScene(size: view.bounds.size, stage: stage, stageIndex: stageIndex)
        scene.onExit = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        scene.onFinish = { [weak self] score, hits, cleared in
            self?.showResult(score: score, hits: hits, cleared: cleared)
        }
        if animated {
            skView.presentScene(scene, transition: .crossFade(withDuration: 0.25))
        } else {
            skView.presentScene(scene)
        }
    }

    private func showResult(score: Int, hits: Int, cleared: Bool) {
        let stage = currentStage()
        let hasNext = cleared && stageIndex + 1 < LiftStage.all.count
        let title = cleared ? "Deck Clear" : "Lift Halted"
        var message = "\(stage.name)\nScore \(score)\nSets \(hits)/\(stage.targetSets)"
        if cleared && hasNext {
            message += "\nNext stage is now open."
        } else if cleared {
            message += "\nEvery stage is open."
        } else {
            message += "\nReach \(stage.targetSets) sets to open the next stage."
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if hasNext {
            alert.addAction(UIAlertAction(title: "Next Stage", style: .default) { [weak self] _ in
                guard let self else { return }
                let next = GameViewController(stageIndex: self.stageIndex + 1)
                var stack = self.navigationController?.viewControllers.filter { !($0 is GameViewController) } ?? []
                stack.append(next)
                self.navigationController?.setViewControllers(stack, animated: true)
            })
        }
        alert.addAction(UIAlertAction(title: "Again", style: .default) { [weak self] _ in
            self?.presentScene(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Menu", style: .cancel) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OrientationController.shared.lockToPortrait()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}
