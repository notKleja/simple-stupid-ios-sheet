import UIKit

/// Passive measurement only: no recognizer competes with UIKit's sheet gestures.
@MainActor final class InteractionProbe: NSObject {
    weak var harness: Harness?
    let background = UIButton(type: .system)
    let status = UILabel()
    var activations = 0
    var probeIndex = 0
    var pendingBefore: Int?
    var pendingPhase: String?
    var delivered = 0
    var deliveredViews: [String] = []
    var lastOutcome: Bool?
    var backgroundRect: CGRect = .zero

    init(_ harness: Harness) { self.harness = harness; super.init() }

    func installPresenter() {
        guard let h = harness else { return }
        background.frame = CGRect(x: 20, y: 220, width: 250, height: 44)
        background.accessibilityIdentifier = "background.control"
        background.setTitle("Background activations: 0", for: .normal)
        background.addTarget(self, action: #selector(activate), for: .touchUpInside)
        h.view.addSubview(background)
        status.frame = CGRect(x: 20, y: 280, width: 350, height: 80)
        status.numberOfLines = 0; status.text = "Probe ready"
        status.accessibilityIdentifier = "interaction.status"
        h.view.addSubview(status)
    }

    func installSheet(_ view: UIView) {
        let controls: [(String, String, Selector)] = [
            ("sheet.select.large", "Large", #selector(large)),
            ("sheet.select.medium", "Medium", #selector(medium)),
            ("probe.begin", "Begin probe", #selector(begin)),
            ("probe.end", "End probe", #selector(end)),
            ("experiment.finish", "Finish experiment", #selector(finish)),
            ("scroll.set400", "Scroll offset 400", #selector(setOffset))]
        for (index, item) in controls.enumerated() {
            let button = UIButton(type: .system)
            button.accessibilityIdentifier = item.0
            button.setTitle(item.1, for: .normal)
            button.frame = CGRect(x: 16 + (index % 2) * 180, y: 125 + (index / 2) * 44, width: 170, height: 40)
            button.addTarget(self, action: item.2, for: .touchUpInside)
            view.addSubview(button)
        }
    }

    func observe(_ touch: UITouch, point: CGPoint) {
        guard pendingBefore != nil, backgroundRect.contains(point) else { return }
        delivered += 1
        deliveredViews.append(touch.view?.accessibilityIdentifier ?? NSStringFromClass(type(of: touch.view ?? UIView())))
    }

    @objc func activate() {
        activations += 1
        background.setTitle("Background activations: \(activations)", for: .normal)
        harness?.trace?.event("background.control.activated", ["count": activations])
    }
    @objc func large() { harness?.requestInteractionDetent(.large) }
    @objc func medium() { harness?.requestInteractionDetent(.medium) }

    @objc func begin() {
        guard let h = harness, pendingBefore == nil else { return }
        if h.definition.scrolling {
            pendingBefore = activations; pendingPhase = "scroll"; delivered = 0
            h.trace?.event("scroll.probe.requested", ["scroll_offset": h.scroll?.contentOffset.y as Any? ?? NSNull()])
        } else {
            let phases = ["medium_initial", "large", "medium_return"]
            guard probeIndex < phases.count else { return }
            backgroundRect = background.convert(background.bounds, to: h.probe)
            pendingBefore = activations; pendingPhase = phases[probeIndex]
            delivered = 0; deliveredViews = []; lastOutcome = nil
            h.trace?.event("background.probe.requested", ["phase": pendingPhase!, "activation_before": activations,
                "target_rect": rect(backgroundRect), "point": ["x": backgroundRect.midX, "y": backgroundRect.midY]])
        }
    }
    @objc func end() {
        guard let h = harness, let before = pendingBefore, let phase = pendingPhase else { return }
        if phase == "scroll" {
            h.trace?.event("scroll.probe.completed", ["scroll_offset": h.scroll?.contentOffset.y as Any? ?? NSNull()])
        } else {
            let delta = activations-before
            lastOutcome = delivered > 0 && (delta == 0 || delta == 1) ? delta == 1 : nil
            h.trace?.event("background.probe.completed", ["phase": phase, "activation_after": activations,
                "delivered_target_touch_events": delivered, "hit_views": deliveredViews])
            probeIndex += 1
        }
        pendingBefore = nil; pendingPhase = nil
        status.text = "Completed probes: \(probeIndex); background activations: \(activations)"
    }
    @objc func finish() { harness?.finishInteraction() }
    @objc func setOffset() {
        harness?.trace?.event("scroll.offset.requested", ["offset": 400])
        harness?.scroll?.setContentOffset(CGPoint(x:0,y:400),animated:false)
    }
}
