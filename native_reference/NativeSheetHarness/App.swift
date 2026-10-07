import UIKit
import QuartzCore
import Darwin
import SwiftUI

func rect(_ r: CGRect) -> [String: Double] {
    ["x": Double(r.minX), "y": Double(r.minY), "width": Double(r.width), "height": Double(r.height)]
}
func insets(_ i: UIEdgeInsets) -> [String: Double] {
    ["top": Double(i.top), "left": Double(i.left), "bottom": Double(i.bottom), "right": Double(i.right)]
}
func osBuild() -> String {
    if let build = ProcessInfo.processInfo.environment["NATIVE_OS_BUILD"] { return build }
    #if targetEnvironment(simulator)
    return "unresolved-simulator-host-kernel-build-excluded"
    #else
    if let plist = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist"), let build = plist["ProductBuildVersion"] as? String { return build }
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var bytes = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &bytes, &size, nil, 0)
    return String(cString: bytes)
    #endif
}

func deviceModel() -> String {
    if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return model }
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var bytes = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &bytes, &size, nil, 0)
    return String(cString: bytes)
}

/// Walk the stable model hierarchy, sampling each node's presentation properties.
/// CALayer.convert between a detached presentation layer and a model window can
/// lose the ancestor offset for one frame during animation removal.
func sampledWindowRect(_ model: CALayer, window: CALayer, samples: [ObjectIdentifier: CALayer]) -> CGRect? {
    guard let first = samples[ObjectIdentifier(model)] else { return nil }
    let initial = first.bounds
    var corners = [CGPoint(x: initial.minX, y: initial.minY), CGPoint(x: initial.maxX, y: initial.minY),
                   CGPoint(x: initial.minX, y: initial.maxY), CGPoint(x: initial.maxX, y: initial.maxY)]
    var current: CALayer? = model
    while let node = current, node !== window {
        guard let s = samples[ObjectIdentifier(node)] else { return nil }
        guard CATransform3DIsAffine(s.transform) else { return nil }
        let anchor = CGPoint(x: s.bounds.minX + s.anchorPoint.x * s.bounds.width, y: s.bounds.minY + s.anchorPoint.y * s.bounds.height)
        corners = corners.map { p in
            let transformed = CGPoint(x: p.x - anchor.x, y: p.y - anchor.y).applying(s.affineTransform())
            return CGPoint(x: transformed.x + s.position.x, y: transformed.y + s.position.y)
        }
        current = node.superlayer
        if let parent = current, let sample = samples[ObjectIdentifier(parent)], !CATransform3DIsIdentity(sample.sublayerTransform) { return nil }
    }
    guard current === window else { return nil }
    let xs = corners.map(\.x), ys = corners.map(\.y)
    return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
}

func coherentLayerSamples(_ window: CALayer) -> [ObjectIdentifier: CALayer] {
    guard let root = window.presentation() else { return [:] }
    var samples: [ObjectIdentifier: CALayer] = [:]
    func walk(_ layer: CALayer) {
        samples[ObjectIdentifier(layer.model())] = layer
        layer.sublayers?.forEach(walk)
    }
    walk(root)
    return samples
}

/// No gesture recognizer is added: record actual delivered touches without changing arbitration.
@MainActor final class ProbeWindow: UIWindow {
    var trace: Trace?
    var finger: CGPoint?
    var fingerVelocity: Double?
    var touchObserver: ((UITouch, CGPoint) -> Void)?
    private var prior: (CGPoint, TimeInterval)?
    override func sendEvent(_ event: UIEvent) {
        if let touch = event.allTouches?.first {
            let point = touch.location(in: self)
            let dt = prior.map { touch.timestamp - $0.1 } ?? 0
            fingerVelocity = dt > 0 ? Double(point.y - prior!.0.y) / dt : nil
            finger = point
            touchObserver?(touch, point)
            trace?.record("event", ["name": "input.touch", "data": [
                "phase": touch.phase.rawValue, "x": point.x, "y": point.y,
                "hit_view": touch.view?.accessibilityIdentifier ?? NSStringFromClass(type(of: touch.view ?? UIView())),
                "velocity_y": fingerVelocity as Any? ?? NSNull(), "input_t_ns": Int64(touch.timestamp * 1e9)
            ]])
            prior = (point, touch.timestamp)
            if touch.phase == .ended || touch.phase == .cancelled { prior = nil; finger = nil }
        }
        super.sendEvent(event)
    }
}

@MainActor final class CalibrationView: UIView {
    let label = UILabel()
    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = .white; isOpaque = true
        label.text = title; label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        label.textColor = .black; label.numberOfLines = 0
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = CGRect(x: 20, y: 40, width: bounds.width - 40, height: 90); setNeedsDisplay() }
    override func draw(_ r: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        c.setStrokeColor(UIColor.black.cgColor); c.setLineWidth(1)
        for y in stride(from: CGFloat(0.5), to: bounds.height, by: 20) {
            c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: 12, y: y))
            c.move(to: CGPoint(x: bounds.width - 12, y: y)); c.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        c.move(to: CGPoint(x: 0, y: bounds.midY)); c.addLine(to: CGPoint(x: bounds.width, y: bounds.midY))
        c.move(to: CGPoint(x: bounds.midX, y: 0)); c.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
        c.strokePath()
        c.setFillColor(UIColor.red.cgColor); c.fill(CGRect(x: 0, y: bounds.height - 10, width: bounds.width, height: 10))
    }
}

@MainActor final class Harness: UIViewController, UISheetPresentationControllerDelegate {
    var probe: ProbeWindow { view.window as! ProbeWindow }
    var trace: Trace?
    var sheet: UIViewController?
    var link: CADisplayLink?
    var phase = "idle"
    var target: String?
    var previousY: (Double, Double)?
    var scenario = "native.medium_large.programmatic"
    var trials = 10
    var trial = 0
    var scroll: UIScrollView?
    var keyboardFrame = CGRect.zero
    var running = false
    var firstVisibleRecorded = false
    var resolvedDetents: [UISheetPresentationController.Detent.Identifier: CGFloat] = [:]
    var definition = NativeScenario.definitions["native.medium_large.programmatic"]!
    var interaction: InteractionProbe?
    var trialOffset = 0
    var strictTimers: [UUID: DispatchSourceTimer] = [:]
    var priorScrollMotion: (Double, Double)?
    var replayRequest: [String: Any] = [:]
    var animationProbe: AnimationProbe?
    var animationObjectsOnly: Bool {
        replayRequest["capture_mode"] as? String == "animation_objects" ||
        ProcessInfo.processInfo.environment["NATIVE_CAPTURE_MODE"] == "animation_objects"
    }
    override func loadView() { view = CalibrationView(title: "Native Sheet Reference\nOpaque calibration surface") }
    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 150, width: 260, height: 50)
        button.setTitle("Run native scenarios", for: .normal)
        button.addTarget(self, action: #selector(startDefault), for: .touchUpInside)
        view.addSubview(button)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(), { _, observer, _, _, _ in
            guard let observer else { return }
            let harness = Unmanaged<Harness>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async { harness.startFromNotification() }
        }, "dev.notkleja.native-sheet.start" as CFString, nil, .deliverImmediately)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ProcessInfo.processInfo.environment["NATIVE_AUTORUN"] == "1" && !running {
            scenario = ProcessInfo.processInfo.environment["NATIVE_SCENARIO"] ?? scenario
            trials = Int(ProcessInfo.processInfo.environment["NATIVE_TRIALS"] ?? "10") ?? 10
            trialOffset = Int(ProcessInfo.processInfo.environment["NATIVE_TRIAL_OFFSET"] ?? "0") ?? 0
            start()
        }
    }
    @objc func startDefault() { start() }
    func startFromNotification() {
        let request = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("interaction_request.json")
        if let data = try? Data(contentsOf:request), let fields = try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
            replayRequest = fields
            scenario = fields["scenario_id"] as? String ?? "invalid_missing_scenario"
            trials = fields["trials"] as? Int ?? 1
            trialOffset = (fields["trial"] as? Int ?? 1)-1
        }
        start()
    }
    @objc func keyboard(_ note: Notification) {
        keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        trace?.event("keyboard.frame", ["frame": rect(keyboardFrame)])
    }
    func open(_ url: URL) {
        guard !running else { return }
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        scenario = parts?.queryItems?.first(where: { $0.name == "scenario" })?.value ?? scenario
        trials = Int(parts?.queryItems?.first(where: { $0.name == "trials" })?.value ?? "10") ?? 10
        start()
    }
    func start() {
        guard !running else { return }
        do {
            definition = try NativeScenario.resolve(scenario, major: Int(UIDevice.current.systemVersion.split(separator: ".")[0]) ?? 0)
            guard (1...100).contains(trials) else { throw ScenarioError.invalid("Trial count must be 1...100") }
        } catch {
            let rejected = Trace(scenario: scenario, clock: CACurrentMediaTime)
            rejected.record("session", ["scenario_id": scenario, "configuration": ["status": "invalid_scenario"]])
            rejected.fail("invalid_scenario", ["error": String(describing: error)])
            return
        }
        if definition.manual && interaction == nil {
            interaction = InteractionProbe(self); interaction?.installPresenter()
            probe.touchObserver = { [weak self] touch, point in self?.interaction?.observe(touch, point: point) }
        }
        interaction?.invalidateDynamics()
        trace = nil; running = true; trial = trialOffset; next()
    }
    func after(_ seconds: Double, from origin: DispatchTime? = nil, _ work: @escaping () -> Void) {
        let caStart = CACurrentMediaTime()
        let dispatchStart = DispatchTime.now().uptimeNanoseconds
        let callback = {
            if ProcessInfo.processInfo.environment["NATIVE_IO_AUDIT"] == "1" {
                self.trace?.record("event", ["name": "scheduler.audit", "data": ["requested_ms": seconds*1000,
                    "ca_elapsed_ms": (CACurrentMediaTime()-caStart)*1000,
                    "dispatch_elapsed_ms": Double(DispatchTime.now().uptimeNanoseconds-dispatchStart)/1e6]])
            }
            work()
        }
        if ProcessInfo.processInfo.environment["NATIVE_TIMER_MODE"] != "coalesced" {
            let key = UUID()
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
            strictTimers[key] = timer
            timer.schedule(deadline: (origin ?? .now())+seconds, leeway: .nanoseconds(0))
            timer.setEventHandler { timer.cancel(); self.strictTimers[key] = nil; callback() }
            timer.resume()
        } else { DispatchQueue.main.asyncAfter(deadline: .now()+seconds, execute: callback) }
    }
    func next() {
        animationProbe?.stop(); animationProbe = nil
        guard trial < trials + trialOffset else {
            interaction?.invalidateDynamics()
            running = false; trace?.event("batch.completed", ["trials": trials]); return
        }
        trial += 1
        guard trace?.invalidated != true else { interaction?.invalidateDynamics(); running = false; return }
        let t = Trace(scenario: scenario, clock: CACurrentMediaTime); trace = t; probe.trace = t
        let vc = UIViewController(); vc.view = CalibrationView(title: "\(scenario)\nTrial \(trial)/\(trials)")
        vc.modalPresentationStyle = definition.style == "form_sheet" ? .formSheet : .pageSheet
        vc.preferredContentSize = CGSize(width: 320, height: 320)
        guard let config = vc.sheetPresentationController else { fatalError("Missing native sheet") }
        let fixed = UISheetPresentationController.Detent.custom(identifier: .init("fixed320")) { context in
            self.resolvedDetents[.medium] = UISheetPresentationController.Detent.medium().resolvedValue(in: context)
            self.resolvedDetents[.large] = UISheetPresentationController.Detent.large().resolvedValue(in: context)
            self.resolvedDetents[.init("fixed320")] = 320
            t.event("detent.resolved", ["maximum": context.maximumDetentValue,
                "medium": UISheetPresentationController.Detent.medium().resolvedValue(in: context) as Any? ?? NSNull(),
                "large": UISheetPresentationController.Detent.large().resolvedValue(in: context) as Any? ?? NSNull(), "fixed": 320])
            return 320
        }
        // A custom resolver probes native medium/large resolvedValue without changing those detents.
        // The measured iOS26 regular-width 320pt form resolves medium below320.
        // Native requires ascending detents; do not reuse the page-sheet order.
        let narrow26Form = definition.style == "form_sheet" && UIDevice.current.systemVersion.hasPrefix("26.") && traitCollection.horizontalSizeClass == .regular
        config.detents = narrow26Form ? [.medium(), fixed, .large()] : [fixed, .medium(), .large()]
        config.selectedDetentIdentifier = definition.initial == "fixed320" ? .init("fixed320") : (definition.initial == "large" ? .large : .medium)
        target = definition.initial
        config.prefersGrabberVisible = true
        config.prefersPageSizing = definition.style == "page_sheet"
        config.prefersEdgeAttachedInCompactHeight = definition.compactEdge
        config.widthFollowsPreferredContentSizeWhenEdgeAttached = definition.preferredWidth
        config.prefersScrollingExpandsWhenScrolledToEdge = definition.expandsOnScroll
        config.largestUndimmedDetentIdentifier = definition.undimmed ? .medium : nil
        vc.isModalInPresentation = definition.dismissalLocked
        if #available(iOS 27.0, *), definition.placement == "leading" { config.preferredPlacement = .leading }
        if #available(iOS 27.0, *), definition.placement == "trailing" { config.preferredPlacement = .trailing }
        config.delegate = self
        if definition.scrolling {
            let s = UIScrollView(frame: vc.view.bounds); s.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            s.accessibilityIdentifier = "sheet.scroll"
            let content = CalibrationView(title: "Long scroll\nKnown extent 2400 pt"); content.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 2400)
            s.addSubview(content); s.contentSize = content.bounds.size; vc.view.addSubview(s); scroll = s
        } else { scroll = nil }
        if definition.manual { interaction?.installSheet(vc.view) }
        if definition.keyboard {
            let field = UITextField(frame: CGRect(x: 20, y: 150, width: 280, height: 50))
            field.borderStyle = .roundedRect; field.placeholder = "Keyboard reference"; vc.view.addSubview(field)
            after(1.5) { field.becomeFirstResponder() }
        }
        sheet = vc; phase = "present"; previousY = nil; firstVisibleRecorded = false
        priorScrollMotion = nil
        let screen = probe.screen
        var effectiveConfiguration = definition.configuration(trial: trial, detents: config.detents.map { canonicalDetentID($0.identifier.rawValue)! })
        effectiveConfiguration["presentation_style"] = vc.modalPresentationStyle == .formSheet ? "form_sheet" : "page_sheet"
        effectiveConfiguration["preferred_content_size"] = ["width": vc.preferredContentSize.width, "height": vc.preferredContentSize.height]
        effectiveConfiguration["page_sizing"] = config.prefersPageSizing
        effectiveConfiguration["edge_attached_in_compact_height"] = config.prefersEdgeAttachedInCompactHeight
        effectiveConfiguration["width_follows_preferred_content_size"] = config.widthFollowsPreferredContentSizeWhenEdgeAttached
        effectiveConfiguration["scroll_expansion"] = config.prefersScrollingExpandsWhenScrolledToEdge
        effectiveConfiguration["modal_in_presentation"] = vc.isModalInPresentation
        effectiveConfiguration["largest_undimmed"] = canonicalDetentID(config.largestUndimmedDetentIdentifier?.rawValue) as Any? ?? NSNull()
        effectiveConfiguration["grabber"] = config.prefersGrabberVisible
        if #available(iOS 27.0, *) {
            effectiveConfiguration["placement"] = config.preferredPlacement == .leading ? "leading" : (config.preferredPlacement == .trailing ? "trailing" : (config.preferredPlacement == .center ? "center" : "automatic"))
        }
        var session: [String:Any] = ["scenario_id": scenario, "implementation": "native", "evidence_kind": "runtime",
            "os": ["version": UIDevice.current.systemVersion, "build": osBuild()],
            "device": ["model": deviceModel(),
                "logical_size": ["width": screen.bounds.width, "height": screen.bounds.height],
                "physical_size": ["width": screen.nativeBounds.width, "height": screen.nativeBounds.height],
                "scale": screen.scale, "refresh_hz": screen.maximumFramesPerSecond, "refresh_hz_source": "UIScreen.maximumFramesPerSecond; measured cadence is per-frame",
                "runtime_kind": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] != nil ? "simulator" : (deviceModel().hasPrefix("iPhone99") ? "virtual_device" : "physical_device")],
            "environment": ["orientation": view.window?.windowScene?.interfaceOrientation.isLandscape == true ? "landscape" : "portrait",
                "safe_area": insets(view.safeAreaInsets), "size_classes": ["horizontal": traitCollection.horizontalSizeClass.rawValue == 1 ? "compact" : "regular", "vertical": traitCollection.verticalSizeClass.rawValue == 1 ? "compact" : "regular"],
                "status_bar": ["hidden": probe.windowScene?.statusBarManager?.isStatusBarHidden as Any? ?? NSNull()], "keyboard": ["visible": false, "frame": rect(keyboardFrame)],
                "system_settings": ["reduce_motion": UIAccessibility.isReduceMotionEnabled, "voice_over": UIAccessibility.isVoiceOverRunning, "content_size_category": traitCollection.preferredContentSizeCategory.rawValue]],
            "configuration": effectiveConfiguration,
            "provenance": ["attempt_id": replayRequest["attempt_id"] as? String ?? ProcessInfo.processInfo.environment["NATIVE_ATTEMPT_ID"] ?? UUID().uuidString,
                "role": replayRequest["role"] as? String ?? ProcessInfo.processInfo.environment["NATIVE_ROLE"] ?? "training",
                "native_source_revision": replayRequest["source_revision"] as? String ?? ProcessInfo.processInfo.environment["NATIVE_SOURCE_REVISION"] ?? "working_tree_uncommitted"]]
        if scenario == "native.geometry.smoke" {
            session["geometry_probe"] = ["schema_version":1,"accepted":false,"scope":"public_geometry_diagnostic_not_contour"]
            if let json=ProcessInfo.processInfo.environment["NATIVE_GEOMETRY_SOURCE_HASHES"],
               let data=json.data(using:.utf8), let hashes=try? JSONSerialization.jsonObject(with:data) as? [String:String] {
                var provenance=session["provenance"] as! [String:Any]
                provenance["source_hashes"]=hashes;session["provenance"]=provenance
            }
        }
        if animationObjectsOnly { session["capture_mode"] = "animation_objects" }
        t.record("session", session)
        link?.invalidate(); link = nil
        if animationObjectsOnly {
            let observer = AnimationProbe(runID: t.id, trial: trial) { row in
                if row["type"] as? String == "animation_probe.error" { t.fail("animation_probe_failed", row) }
                else { t.record("animation_install", row, time: row["transaction_time"] as? Double) }
            }
            animationProbe = observer
            do { try observer.start(phase: "presentation") }
            catch { t.fail("animation_probe_start_failed", ["error": String(describing: error)]); running = false; return }
        } else {
            link = CADisplayLink(target: self, selector: #selector(sample(_:))); link!.add(to: .main, forMode: .common)
        }
        let replayOrigin = DispatchTime.now()
        t.event("present.requested")
        present(vc, animated: true) {
            t.event("present.completed") // Completion callback does not establish physical settling.
            self.phase = "idle"
        }
        // Manual gesture scenarios intentionally stay open for external input replay.
        guard !definition.manual else { return }
        for request in definition.programmaticRequests {
            after(request.after, from: replayOrigin) {
                self.animationProbe?.setPhase("\(self.target ?? "unknown")_to_\(request.target)")
                self.target=request.target;self.phase="detent"
                t.event("detent.requested",["target":request.target])
                config.animateChanges { config.selectedDetentIdentifier=request.target == "large" ? .large : .medium }
            }
        }
        after(definition.dismissAfter, from: replayOrigin) {
            self.animationProbe?.setPhase("dismissal")
            self.phase = "dismiss"; self.target = nil; t.event("dismiss.requested")
            vc.dismiss(animated: true) {
                self.interaction?.invalidateDynamics()
                t.event("dismiss.completed", terminal: true); self.link?.invalidate(); self.sheet = nil
                self.animationProbe?.stop()
                self.after(0.4) { self.next() }
            }
        }
    }
    func requestInteractionDetent(_ id: UISheetPresentationController.Detent.Identifier) {
        guard let config = sheet?.sheetPresentationController else { return }
        target = canonicalDetentID(id.rawValue)
        trace?.event("detent.requested", ["target": target!])
        config.animateChanges { config.selectedDetentIdentifier = id }
    }
    func finishInteraction() {
        guard let sheet, let trace else { return }
        phase = "dismiss"; target = nil; trace.event("dismiss.requested")
        sheet.dismiss(animated: true) {
            self.interaction?.invalidateDynamics()
            trace.event("dismiss.completed", terminal: true)
            self.link?.invalidate(); self.sheet = nil; self.running = false
            self.interaction?.status.text = "Experiment complete"
        }
    }
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ controller: UISheetPresentationController) {
        let raw = controller.selectedDetentIdentifier?.rawValue
        target = canonicalDetentID(raw)
        trace?.record("event", ["name": "detent.changed", "data": ["selected": canonicalDetentID(raw) as Any? ?? NSNull()], "raw_uikit_identifier": raw as Any? ?? NSNull()])
    }
    func presentationControllerDidDismiss(_ controller: UIPresentationController) {
        interaction?.invalidateDynamics()
        trace?.event("dismiss.interactive_completed"); link?.invalidate(); sheet = nil; running = false
    }
    func layerInfo(_ view: UIView, in window: UIWindow, samples: [ObjectIdentifier: CALayer]) -> [String: Any] {
        let layer = samples[ObjectIdentifier(view.layer)] ?? view.layer
        let target = window.layer.presentation() ?? window.layer
        let animations: [[String: Any]] = (view.layer.animationKeys() ?? []).compactMap { key in
            guard let a = view.layer.animation(forKey: key) else { return nil }
            var value: [String: Any] = ["key": key, "class": NSStringFromClass(type(of: a)), "duration": a.duration, "begin_time": a.beginTime, "speed": a.speed]
            if let spring = a as? CASpringAnimation { value["spring"] = ["mass": spring.mass, "stiffness": spring.stiffness, "damping": spring.damping, "initial_velocity": spring.initialVelocity, "settling_duration": spring.settlingDuration] }
            if let basic = a as? CABasicAnimation { value["key_path"] = basic.keyPath as Any? ?? NSNull() }
            return value
        }
        return ["class": NSStringFromClass(type(of: view)), "frame_window": sampledWindowRect(view.layer, window: window.layer, samples: samples).map(rect) as Any? ?? NSNull(),
            "legacy_mixed_tree_frame": rect(layer.convert(layer.bounds, to: target)),
            "sampled_position": ["x": layer.position.x, "y": layer.position.y], "model_position": ["x": view.layer.position.x, "y": view.layer.position.y],
            "presentation_has_parent": layer.superlayer != nil, "sample_source": samples[ObjectIdentifier(view.layer)] == nil ? "model_not_in_snapshot" : "coherent_presentation_tree",
            "bounds": rect(layer.bounds), "corner_radius": layer.cornerRadius, "corner_curve": layer.cornerCurve.rawValue,
            "opacity": layer.opacity, "hidden": layer.isHidden, "clips": layer.masksToBounds,
            "background_alpha": layer.backgroundColor?.alpha as Any? ?? NSNull(), "masked_corners": layer.maskedCorners.rawValue,
            "mask_class": layer.mask.map { NSStringFromClass(type(of: $0)) } as Any? ?? NSNull(), "animations": animations,
            "background": layer.backgroundColor.map { UIColor(cgColor: $0).description } as Any? ?? NSNull(),
            "gesture_recognizers": (view.gestureRecognizers ?? []).map { recognizer -> [String: Any] in
                var value: [String: Any] = ["class": NSStringFromClass(type(of:recognizer)), "state": recognizer.state.rawValue, "enabled": recognizer.isEnabled, "touches": recognizer.numberOfTouches]
                if let pan = recognizer as? UIPanGestureRecognizer {
                    value["translation_y"] = pan.translation(in:window).y; value["velocity_y"] = pan.velocity(in:window).y
                }
                return value
            },
            "transform": [layer.transform.m11, layer.transform.m12, layer.transform.m21, layer.transform.m22, layer.transform.m41, layer.transform.m42]]
    }
    @objc func sample(_ display: CADisplayLink) {
        guard let trace, let sheet else { return }
        defer { if trace.invalidated { interaction?.invalidateDynamics() } }
        let container = sheet.presentationController?.presentedView ?? sheet.view!
        let l = container.layer.presentation() ?? container.layer
        let windowLayer = probe.layer.presentation() ?? probe.layer
        let samples = coherentLayerSamples(probe.layer)
        let geometryDiagnostic: [String:Any]? = scenario == "native.geometry.smoke" ?
            GeometryProbe.observe(presentedView:container,presentingView:view,window:probe,
                presentationSamples:samples,presentationWindowRect:{ sampledWindowRect($0,window:self.probe.layer,samples:samples) }) : nil
        guard let r = sampledWindowRect(container.layer, window: probe.layer, samples: samples) else {
            var frame: [String:Any] = ["metrics": ["sheet.x": NSNull(), "sheet.y": NSNull(), "sheet.width": NSNull(), "sheet.height": NSNull()],
                "state": ["phase": phase], "unavailable": ["sheet.y": "No coherent presentation ancestry or unsupported nonaffine transform"], "coherent_layer_count": samples.count]
            if let geometryDiagnostic { frame["geometry_probe"] = geometryDiagnostic }
            trace.record("frame",frame)
            return
        }
        let legacy = l.convert(l.bounds, to: windowLayer)
        let pl = samples[ObjectIdentifier(view.layer)] ?? view.layer
        let t = CACurrentMediaTime()
        if !firstVisibleRecorded && r.intersection(probe.bounds).height > 0 {
            firstVisibleRecorded = true
            trace.record("event", ["name": "present.first_visible", "data": ["detector": "first sampled positive visible height"]], time: t)
        }
        let velocity = previousY.map { (Double(r.minY) - $0.0) / (t - $0.1) }
        previousY = (Double(r.minY), t)
        var metrics: [String: Any] = ["sheet.x": r.minX, "sheet.y": r.minY, "sheet.width": r.width, "sheet.height": r.height,
            "sheet.visible_height": r.intersection(probe.bounds).height, "sheet.top": r.minY, "sheet.bottom": r.maxY,
            "sheet.left_inset": r.minX, "sheet.right_inset": probe.bounds.maxX - r.maxX, "sheet.bottom_inset": probe.bounds.maxY - r.maxY,
            "sheet.detent_height": sheet.sheetPresentationController?.selectedDetentIdentifier.flatMap { resolvedDetents[$0] } as Any? ?? NSNull(), "sheet.radius": NSNull(), "barrier.alpha": NSNull(),
            "presenter.scale_x": pl.transform.m11, "presenter.scale_y": pl.transform.m22,
            "presenter.translation_x": pl.transform.m41, "presenter.translation_y": pl.transform.m42,
            "presenter.radius": NSNull(), "sheet.velocity_y": velocity as Any? ?? NSNull(),
            "finger.y": probe.finger?.y as Any? ?? NSNull(), "finger.velocity_y": probe.fingerVelocity as Any? ?? NSNull(),
            "scroll.offset": scroll?.contentOffset.y as Any? ?? NSNull()]
        var movementConsumer: String?
        if let scroll {
            let offset = Double(scroll.contentOffset.y)
            metrics["scroll.pan_translation_y"] = scroll.panGestureRecognizer.translation(in:probe).y
            metrics["scroll.pan_velocity_y"] = scroll.panGestureRecognizer.velocity(in:probe).y
            if let prior = priorScrollMotion {
                let scrollMoved = offset != prior.0, sheetMoved = Double(r.minY) != prior.1
                movementConsumer = scrollMoved && sheetMoved ? "both" : (scrollMoved ? "scroll" : (sheetMoved ? "sheet" : "none"))
                metrics["scroll.offset_delta"] = offset-prior.0
                metrics["sheet.position_delta"] = Double(r.minY)-prior.1
            }
            priorScrollMotion = (offset,Double(r.minY))
        }
        for (key, value) in metrics { if let n = value as? Double, !n.isFinite { metrics[key] = NSNull() } }
        var layers: [[String: Any]] = []
        func walk(_ node: UIView, _ depth: Int) {
            if depth > 6 { return }; var info = layerInfo(node, in: probe, samples: samples); info["depth"] = depth; layers.append(info)
            node.subviews.forEach { walk($0, depth + 1) }
        }
        probe.subviews.forEach { walk($0, 0) }
        var frame: [String:Any] = ["metrics": metrics,
            "state": ["phase": phase, "selected_detent": canonicalDetentID(sheet.sheetPresentationController?.selectedDetentIdentifier?.rawValue) as Any? ?? NSNull(),
                "target_detent": target as Any? ?? NSNull(), "gesture": probe.finger == nil ? "none" : "touch", "scroll_owner": NSNull(), "underlying_hit_test": interaction?.lastOutcome as Any? ?? NSNull(),
                "scroll_pan_state": scroll?.panGestureRecognizer.state.rawValue as Any? ?? NSNull(), "observed_movement_consumer": movementConsumer as Any? ?? NSNull()],
            "unavailable": ["sheet.radius": "Container scalar may not represent visible clipping shape; inspect raw layers",
                "presenter.radius": "Root scalar does not identify wrapper clipping shape", "barrier.alpha": "Unclassified system layer", "underlying_hit_test": "Requires actual background touch",
                "target_detent": "Dismissal has no configured detent target", "scroll_owner": "Native scroll arbitration instrumentation unavailable",
                "sheet.detent_height": "Resolver context has not supplied the selected detent value", "sheet.velocity_y": "No consecutive valid geometry samples",
                "finger.y": "No active delivered touch when null", "finger.velocity_y": "No consecutive delivered touch samples when null", "scroll.offset": "No scroll view in this scenario when null"],
            "raw_uikit_identifier": ["selected_detent": sheet.sheetPresentationController?.selectedDetentIdentifier?.rawValue as Any? ?? NSNull()],
            "display": ["timestamp": display.timestamp, "target_timestamp": display.targetTimestamp, "duration": display.duration],
            "geometry_source": "coherent window presentation tree with stable model ancestry", "coherent_layer_count": samples.count,
            "legacy_mixed_tree_sheet_frame": rect(legacy), "raw_layers": layers, "keyboard_frame": rect(keyboardFrame),
            "provenance": ["movement_consumer": "derived from consecutive observed offset/position deltas; not private gesture ownership"]]
        if let geometryDiagnostic { frame["geometry_probe"] = geometryDiagnostic }
        trace.record("frame",frame,time:t)
    }
}

@main @MainActor final class App: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

@MainActor final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let harness = Harness()
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = ProbeWindow(windowScene: ws)
        w.rootViewController = ProcessInfo.processInfo.environment["NATIVE_SWIFTUI"] == "1" ? UIHostingController(rootView: SwiftUIReference()) : harness
        w.makeKeyAndVisible(); window = w
        if let url = options.urlContexts.first?.url { DispatchQueue.main.async { self.harness.open(url) } }
    }
    func scene(_ scene: UIScene, openURLContexts urls: Set<UIOpenURLContext>) { if let url = urls.first?.url { harness.open(url) } }
}
