import UIKit

@MainActor final class SynchronizedNativeDemoController: UIViewController {
    private let timeline: SynchronizedDemoTimeline
    private let startEpochMs: Int
    private var displayLink: CADisplayLink?
    private var previousMs = -1
    private var currentSceneID = ""
    private var elapsedMs = -1
    private var pulse = 0
    private var toggleValue = false
    private var sheet: UIViewController?
    private var sheetController: UISheetPresentationController?
    private var scrollView: UIScrollView?
    private var componentSwitch: UISwitch?
    private let header = UILabel()
    private let backgroundTitle = UILabel()
    private let stateLabel = UILabel()

    init(timeline: SynchronizedDemoTimeline, startEpochMs: Int) {
        self.timeline = timeline
        self.startEpochMs = startEpochMs
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(red: 0.957, green: 0.969, blue: 0.984, alpha: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        header.numberOfLines = 0
        header.textColor = .white
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        header.layer.cornerRadius = 14
        header.layer.masksToBounds = true
        header.frame = CGRect(x: 12, y: 70, width: 378, height: 110)
        view.addSubview(header)

        let icon = UIImageView(image: UIImage(systemName: "square.stack.3d.up.fill"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 160, y: 255, width: 82, height: 82)
        view.addSubview(icon)

        backgroundTitle.numberOfLines = 0
        backgroundTitle.textAlignment = .center
        backgroundTitle.font = .systemFont(ofSize: 22, weight: .semibold)
        backgroundTitle.frame = CGRect(x: 28, y: 355, width: 346, height: 90)
        view.addSubview(backgroundTitle)

        stateLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        stateLabel.textAlignment = .center
        stateLabel.frame = CGRect(x: 28, y: 445, width: 346, height: 50)
        view.addSubview(stateLabel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        tick()
    }

    @objc private func tick() {
        let raw = Int(Date().timeIntervalSince1970 * 1000) - startEpochMs
        elapsedMs = min(max(raw, 0), timeline.durationMs)
        let scene = timeline.scene(at: elapsedMs)
        if scene.id != currentSceneID { currentSceneID = scene.id; updateScene(scene) }
        updateHeader(scene, rawElapsed: raw)
        let due = timeline.actions(fromExclusive: previousMs, through: elapsedMs)
        previousMs = elapsedMs
        due.forEach(perform)
        if raw > timeline.durationMs + 500 { displayLink?.invalidate(); displayLink = nil }
    }

    private func updateScene(_ scene: SynchronizedDemoScene) {
        let rtl = scene.direction == "rtl"
        view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        header.textAlignment = rtl ? .right : .left
        backgroundTitle.text = rtl ? "خلفية التطبيق الأصلية\nقابلة للملاحظة" : "Live native application background"
        stateLabel.text = "pulse=\(pulse)  toggle=\(toggleValue ? "on" : "off")"
    }

    private func updateHeader(_ scene: SynchronizedDemoScene, rawElapsed: Int) {
        let shown = max(rawElapsed, 0), seconds = shown / 1000, millis = shown % 1000
        let implementation = scene.language == "ar" ? "أصلي" : "NATIVE"
        header.text = "  \(implementation)  •  \(scene.language.uppercased())  •  \(String(format: "%02d.%03d", seconds, millis)) s\n  \(scene.title)\n  \(scene.subtitle)\n  \(scene.id)"
        if scene.kind == "intro" {
            let colors = [
                UIColor(red: 0.957, green: 0.969, blue: 0.984, alpha: 1),
                UIColor(red: 0.902, green: 0.961, blue: 0.933, alpha: 1),
                UIColor(red: 1, green: 0.949, blue: 0.851, alpha: 1),
            ]
            view.backgroundColor = colors[(shown / 1000) % colors.count]
        }
    }

    private func perform(_ scheduled: SynchronizedScheduledAction) {
        switch scheduled.action.type {
        case "present": presentSheet(scene: scheduled.scene, initial: scheduled.action.detent ?? "medium")
        case "select": select(scheduled.action.detent ?? "medium")
        case "scroll": scroll(to: scheduled.action.offset ?? 0)
        case "background_pulse":
            pulse += 1
            UIView.animate(withDuration: 0.25, animations: { self.view.backgroundColor = .systemYellow.withAlphaComponent(0.25) }) { _ in
                UIView.animate(withDuration: 0.5) { self.view.backgroundColor = UIColor(red: 0.957, green: 0.969, blue: 0.984, alpha: 1) }
            }
            stateLabel.text = "pulse=\(pulse)  toggle=\(toggleValue ? "on" : "off")"
        case "toggle":
            toggleValue.toggle(); componentSwitch?.setOn(toggleValue, animated: true)
            stateLabel.text = "pulse=\(pulse)  toggle=\(toggleValue ? "on" : "off")"
        case "dismiss_attempt":
            stateLabel.text = scheduled.scene.language == "ar" ? "محاولة السحب محظورة" : "interactive dismissal blocked"
        case "dismiss": dismissSheet()
        default: break
        }
    }

    private func detents(for scene: SynchronizedDemoScene) -> [UISheetPresentationController.Detent] {
        if scene.configuration?.detents == "custom" {
            return [.custom(identifier: .init("small")) { _ in 240 }, .custom(identifier: .init("middle")) { _ in 420 }, .large()]
        }
        return [.custom(identifier: .init("fixed320")) { _ in 320 }, .medium(), .large()]
    }

    private func identifier(_ value: String) -> UISheetPresentationController.Detent.Identifier {
        switch value { case "medium": return .medium; case "large": return .large; default: return .init(value) }
    }

    private func presentSheet(scene: SynchronizedDemoScene, initial: String) {
        if let existing = sheet { existing.dismiss(animated: false) }
        let controller = UIViewController()
        controller.view = contentView(for: scene)
        controller.modalPresentationStyle = .pageSheet
        controller.isModalInPresentation = scene.configuration?.dismissalLocked == true
        guard let presentation = controller.sheetPresentationController else { return }
        presentation.detents = detents(for: scene)
        presentation.selectedDetentIdentifier = identifier(initial)
        presentation.prefersGrabberVisible = true
        if let undimmed = scene.configuration?.largestUndimmed { presentation.largestUndimmedDetentIdentifier = identifier(undimmed) }
        presentation.prefersScrollingExpandsWhenScrolledToEdge = scene.configuration?.scrollExpansion ?? true
        sheet = controller; sheetController = presentation
        present(controller, animated: true)
    }

    private func select(_ value: String) {
        sheetController?.animateChanges { self.sheetController?.selectedDetentIdentifier = self.identifier(value) }
    }

    private func scroll(to offset: Double) {
        guard let scrollView else { return }
        UIView.animate(withDuration: 0.9, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) { scrollView.contentOffset = CGPoint(x: 0, y: offset) }
    }

    private func dismissSheet() {
        sheet?.dismiss(animated: true)
        sheet = nil; sheetController = nil; scrollView = nil; componentSwitch = nil
    }

    private func contentView(for scene: SynchronizedDemoScene) -> UIView {
        if scene.configuration?.content == "long_scroll" { return scrollingContent(scene) }
        if scene.configuration?.content == "components" { return componentContent(scene) }
        return CalibrationView(title: scene.language == "ar" ? "علامة المنتصف\n\(scene.id)" : "Calibration center\n\(scene.id)")
    }

    private func scrollingContent(_ scene: SynchronizedDemoScene) -> UIView {
        let scroll = UIScrollView(); scroll.backgroundColor = .white
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 8; stack.frame = CGRect(x: 18, y: 42, width: 366, height: 30 * 62)
        for index in 1...30 {
            let label = UILabel(); label.numberOfLines = 2
            label.backgroundColor = UIColor.systemBlue.withAlphaComponent(index % 2 == 0 ? 0.08 : 0.13)
            label.layer.cornerRadius = 12; label.layer.masksToBounds = true
            label.text = scene.language == "ar" ? "   عنصر القائمة \(index)\n   محتوى قابل للتمرير" : "   List row \(index)\n   Scrollable content"
            stack.addArrangedSubview(label); label.heightAnchor.constraint(equalToConstant: 54).isActive = true
        }
        scroll.addSubview(stack); scroll.contentSize = CGSize(width: 402, height: stack.frame.maxY + 30); scrollView = scroll
        return scroll
    }

    private func componentContent(_ scene: SynchronizedDemoScene) -> UIView {
        let scroll = UIScrollView(); scroll.backgroundColor = .white
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 12; stack.frame = CGRect(x: 20, y: 42, width: 362, height: 620)
        let title = UILabel(); title.font = .systemFont(ofSize: 24, weight: .semibold); title.text = scene.language == "ar" ? "معرض المكونات" : "Component gallery"; stack.addArrangedSubview(title)
        let button = UIButton(type: .system); button.configuration = .filled(); button.setTitle(scene.language == "ar" ? "زر أساسي" : "Primary button", for: .normal); stack.addArrangedSubview(button)
        let switchRow = UIStackView(); switchRow.axis = .horizontal
        let switchTitle = UILabel(); switchTitle.text = scene.language == "ar" ? "مفتاح تبديل" : "Toggle switch"
        let toggle = UISwitch(); toggle.isOn = toggleValue; componentSwitch = toggle
        switchRow.addArrangedSubview(switchTitle); switchRow.addArrangedSubview(toggle); stack.addArrangedSubview(switchRow)
        let segmented = UISegmentedControl(items: scene.language == "ar" ? ["الأول", "الثاني"] : ["First", "Second"]); segmented.selectedSegmentIndex = toggleValue ? 1 : 0; stack.addArrangedSubview(segmented)
        let field = UITextField(); field.borderStyle = .roundedRect; field.placeholder = scene.language == "ar" ? "حقل نص" : "Text field"; stack.addArrangedSubview(field)
        for index in 1...3 {
            let block = UILabel(); block.textAlignment = .center; block.text = scene.language == "ar" ? "كتلة \(index)" : "Fixed block \(index)"
            block.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05 + CGFloat(index) * 0.05); block.layer.cornerRadius = 12; block.layer.masksToBounds = true
            block.heightAnchor.constraint(equalToConstant: 54).isActive = true; stack.addArrangedSubview(block)
        }
        scroll.addSubview(stack); scroll.contentSize = CGSize(width: 402, height: stack.frame.maxY + 30)
        return scroll
    }
}
