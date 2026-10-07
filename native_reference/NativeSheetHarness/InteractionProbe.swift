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
    private var dynamicsActive = false
    private var dynamicsLink: CADisplayLink?
    private var landmarkTimers: [DispatchSourceTimer] = []
    private var priorTouches: [ObjectIdentifier: (point: CGPoint, time_ns: Int64, id: String)] = [:]
    private var touchSequence = 0
    private var dynamicsRecipe: [String: Any]?
    private var dynamicsLifetime: DynamicsObserverLifetime?

    init(_ harness: Harness) {
        self.harness = harness; super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(invalidateDynamics),
            name: UIApplication.willTerminateNotification, object: nil)
    }

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
        observeDynamics(touch, point: point)
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
        if h.definition.dynamics { beginDynamics(); return }
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
        if harness?.definition.dynamics == true { endDynamics(); return }
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
    @objc func finish() {
        if dynamicsActive { endDynamics() }
        harness?.finishInteraction()
    }
    @objc func setOffset() {
        harness?.trace?.event("scroll.offset.requested", ["offset": 400])
        harness?.scroll?.setContentOffset(CGPoint(x:0,y:400),animated:false)
    }

    private func dynamicsEvent(_ name: String, _ data: [String: Any]) {
        guard requireLiveDynamics() else { return }
        // Do not synchronously fsync each delivered touch/display observation.
        if harness?.trace?.record("event", ["name": name, "data": data]) != true { invalidateDynamics() }
    }

    private func beginDynamics() {
        guard !dynamicsActive, let h = harness, let trace = h.trace, !trace.invalidated else { return }
        let json = ProcessInfo.processInfo.environment["NATIVE_DYNAMICS_RECIPE"] ?? ""
        if let data = json.data(using: .utf8),
           let recipe = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           recipe["contract_version"] as? Int == 2, recipe["scenario_id"] as? String == h.definition.id {
            dynamicsRecipe = recipe
        } else {
            h.trace?.fail("dynamics_recipe_missing_or_mismatched"); return
        }
        dynamicsLifetime = DynamicsObserverLifetime(runID: trace.id)
        dynamicsActive = true; priorTouches = [:]; touchSequence = 0
        dynamicsEvent("dynamics.session", ["contract_version": 2, "recipe": dynamicsRecipe!,
            "scope": "public_observations_not_achieved_recipe_or_physics",
            "fixture_capability_revision": 1,
            "unsupported_fixture_axes": ["nested", "pager", "phase_bound_interruptions", "restricted_detent_pairs"]])
        dynamicsEvent("dynamics.input.requested", ["recipe_id": dynamicsRecipe!["id"] as Any? ?? NSNull()])
        sampleDynamics()
        dynamicsLink = CADisplayLink(target: self, selector: #selector(sampleDynamics))
        dynamicsLink?.add(to: .main, forMode: .common)
        scheduleRequestLandmarks()
    }

    private func scheduleRequestLandmarks() {
        // Both deadlines use one origin. The callback is a REQUEST landmark:
        // no UIKit input or animation-phase onset is inferred from its timing.
        let origin = DispatchTime.now()
        let anchor = Int64(CACurrentMediaTime() * 1e9)
        for delay in [100, 200] {
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
            timer.schedule(deadline: origin + .milliseconds(delay), leeway: .nanoseconds(0))
            timer.setEventHandler { [weak self] in
                timer.setEventHandler {}; timer.cancel()
                guard let self, self.requireLiveDynamics() else { return }
                self.dynamicsEvent("dynamics.landmark.requested", ["delay_ms": delay,
                    "anchor_t_ns": anchor, "deadline_t_ns": anchor + Int64(delay)*1_000_000,
                    "anchor_kind": "probe.begin.request", "phase": self.dynamicsRecipe?["interruption_phase"] as Any? ?? NSNull(),
                    "unavailable": ["observed_phase_onset": "No opening/detent/dismissal observer anchor in this fixture"]])
            }
            landmarkTimers.append(timer); timer.resume()
        }
    }

    private func observeDynamics(_ touch: UITouch, point: CGPoint) {
        guard requireLiveDynamics() else { return }
        // Exclude probe-control taps, not sheet-content input. The window
        // callback observes only one UITouch per event; multitouch is unresolved.
        var view = touch.view
        while let current = view {
            if let id = current.accessibilityIdentifier,
               id.hasPrefix("probe.") || id.hasPrefix("experiment.") || id.hasPrefix("sheet.select.") || id == "scroll.set400" { return }
            view = current.superview
        }
        let key = ObjectIdentifier(touch)
        let prior = priorTouches[key]
        if prior == nil { touchSequence += 1 }
        let id = prior?.id ?? "touch-\(touchSequence)"
        // Compute from the SAME integer timestamp serialized below, so an
        // offline reader can reproduce the exact finite difference.
        let inputTime = Int64(touch.timestamp * 1e9)
        let dt = prior.map { Double(inputTime - $0.time_ns)/1e9 } ?? 0
        let velocity = dt > 0 ? prior.map { Double(point.y - $0.point.y)/dt } : nil
        let phase: String
        switch touch.phase {
        case .began: phase = "began"
        case .moved: phase = "moved"
        case .ended: phase = "ended"
        case .cancelled: phase = "cancelled"
        case .stationary: phase = "stationary"
        default: phase = "unavailable"
        }
        dynamicsEvent("dynamics.input.delivered", ["touch_id": id, "phase": phase,
            "input_t_ns": inputTime, "position": ["x": point.x, "y": point.y],
            "velocity_y": velocity as Any? ?? NSNull(), "velocity_source": "consecutive_delivered_position_time_finite_difference",
            "unavailable": velocity == nil ? ["velocity_y": prior == nil ? "first delivered sample has no preceding sample" : "nonpositive delivered time delta"] : [:]])
        if touch.phase == .ended || touch.phase == .cancelled { priorTouches[key] = nil }
        else { priorTouches[key] = (point, inputTime, id) }
    }

    @objc private func sampleDynamics() {
        guard requireLiveDynamics(), let h = harness else { return }
        let sampled = Int64(CACurrentMediaTime() * 1e9)
        var recognizers: [[String: Any]] = []
        func walk(_ view: UIView, _ relationship: String) {
            for (index, recognizer) in (view.gestureRecognizers ?? []).enumerated() {
                let state: String
                switch recognizer.state {
                case .possible: state = "possible"
                case .began: state = "began"
                case .changed: state = "changed"
                case .ended: state = "ended"
                case .cancelled: state = "cancelled"
                case .failed: state = "failed"
                @unknown default: state = "unavailable"
                }
                recognizers.append(["relationship": "\(relationship)/recognizer/\(index)", "state": state])
            }
            for (index, child) in view.subviews.enumerated() { walk(child, "\(relationship)/child/\(index)") }
        }
        if let container = h.sheet?.presentationController?.containerView { walk(container, "presentation.container") }
        let view = h.sheet?.view
        // Reuse the accepted snapshot + common model-ancestry walk, not
        // direct CALayer.convert between detached presentation snapshots.
        let samples = coherentLayerSamples(h.probe.layer)
        let y = view.flatMap { sampledWindowRect($0.layer, window: h.probe.layer, samples: samples)?.minY }
        let source = y == nil ? "unavailable" : "sampledWindowRect.coherent_common_ancestry"
        var reasons: [String: String] = [:]
        if y == nil {
            reasons["sheet_position_y"] = "No coherent presentation snapshot/common affine ancestry"
            reasons["sheet_position_source"] = "Coordinate observation unavailable; no model/direct-convert fallback"
        }
        if h.scroll == nil { reasons["scroll_offset"] = "No observable scroll view" }
        if recognizers.isEmpty { reasons["recognizers"] = "No public relationship recognizer observations" }
        dynamicsEvent("dynamics.frame.observed", ["sample_t_ns": sampled,
            "sheet_position_y": y as Any? ?? NSNull(), "sheet_position_source": source,
            "scroll_offset": h.scroll?.contentOffset.y as Any? ?? NSNull(), "recognizers": recognizers,
            "unavailable": reasons])
    }

    private func endDynamics() {
        guard requireLiveDynamics() else { return }
        sampleDynamics()
        let selected = harness?.sheet?.sheetPresentationController?.selectedDetentIdentifier?.rawValue
        dynamicsEvent("dynamics.final.observed", ["final_detent": canonicalDetentID(selected) as Any? ?? NSNull(),
            "raw_uikit_identifier": selected as Any? ?? NSNull(), "source": "public.selectedDetentIdentifier",
            "unavailable": selected == nil ? ["final_detent": "No public selected detent at observation", "raw_uikit_identifier": "No public selected detent at observation"] : [:],
            "limitation": "Selected identifier is not a physical settling or release-target claim"])
        invalidateDynamics()
    }

    private func requireLiveDynamics() -> Bool {
        guard dynamicsActive else { return false }
        guard let h = harness, let lifetime = dynamicsLifetime,
              !lifetime.mustStop(currentRunID: h.trace?.id, running: h.running,
                  sheetPresent: h.sheet != nil, invalidated: h.trace?.invalidated ?? true) else {
            invalidateDynamics(); return false
        }
        return true
    }

    /// Cleanup only: no fabricated final detent and no post-terminal record.
    /// App calls this immediately on dismissal/terminal paths; every observer
    /// callback additionally enforces the pure run-lifetime guard.
    @objc func invalidateDynamics() {
        dynamicsActive = false; dynamicsLifetime = nil
        dynamicsLink?.invalidate(); dynamicsLink = nil
        landmarkTimers.forEach { $0.setEventHandler {}; $0.cancel() }
        landmarkTimers.removeAll(); priorTouches.removeAll()
    }
}
