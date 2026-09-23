import UIKit

final class LaunchLoaderViewController: UIViewController {
    private let indicator = UIActivityIndicatorView(style: .large)
    private var indicatorCenterY: NSLayoutConstraint?
    private let gridLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DraftLook.paper

        gridLayer.strokeColor = DraftLook.inkSoft.cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        view.layer.insertSublayer(gridLayer, at: 0)

        indicator.color = DraftLook.ink
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        let centerY = indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        indicatorCenterY = centerY

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY
        ])

        indicator.startAnimating()
        updateIndicatorPosition(for: view.bounds.size)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        drawGrid()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateIndicatorPosition(for: size)
        coordinator.animate(alongsideTransition: { _ in
            self.drawGrid(in: CGRect(origin: .zero, size: size))
        })
    }

    private func drawGrid(in bounds: CGRect? = nil) {
        let rect = bounds ?? view.bounds
        gridLayer.frame = rect
        let path = UIBezierPath()
        let step: CGFloat = 28
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        gridLayer.path = path.cgPath
    }

    private func updateIndicatorPosition(for size: CGSize) {
        let isLandscape = size.width > size.height
        indicatorCenterY?.constant = isLandscape ? 70 : 0
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
