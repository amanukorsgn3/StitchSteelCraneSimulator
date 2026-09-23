import UIKit

final class NoInternetViewController: UIViewController {
    private let gridLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DraftLook.paper

        gridLayer.strokeColor = DraftLook.inkSoft.cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        view.layer.insertSublayer(gridLayer, at: 0)

        let title = UILabel()
        title.text = "NO CONNECTION"
        title.font = .systemFont(ofSize: 28, weight: .black)
        title.textColor = DraftLook.ink
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let message = UILabel()
        message.text = "Turn on the internet and open the app again."
        message.font = .systemFont(ofSize: 17, weight: .medium)
        message.textColor = DraftLook.ink.withAlphaComponent(0.72)
        message.textAlignment = .center
        message.numberOfLines = 0
        message.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(message)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -24),
            message.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gridLayer.frame = view.bounds
        let path = UIBezierPath()
        let step: CGFloat = 28
        var x: CGFloat = 0
        while x <= view.bounds.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: view.bounds.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= view.bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: view.bounds.width, y: y))
            y += step
        }
        gridLayer.path = path.cgPath
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
