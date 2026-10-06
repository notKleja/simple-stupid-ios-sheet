import UIKit
import QuartzCore
import Darwin

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
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var bytes = [CChar](repeating: 0, count: size)
    sysctlbyname("kern.osversion", &bytes, &size, nil, 0)
    return String(cString: bytes)
    #endif
}

@MainActor final class Trace {
    let id = UUID().uuidString
    private var seq = 0
    private let handle: FileHandle
    let path: URL
    init(scenario: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        path = dir.appendingPathComponent("\(scenario)-\(id).jsonl")
        FileManager.default.createFile(atPath: path.path, contents: nil)
        handle = try! FileHandle(forWritingTo: path)
    }
    func record(_ type: String, _ fields: [String: Any], time: Double = CACurrentMediaTime()) {
        var row = fields
        row.merge(["schema_version": 1, "type": type, "run_id": id,
                   "seq": seq, "t_ns": Int64(time * 1_000_000_000)]) { _, n in n }
        seq += 1
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) {
            handle.write(data); handle.write(Data([10]))
        }
    }
    func event(_ name: String, _ data: [String: Any] = [:]) {
        record("event", ["name": name, "data": data])
        try? handle.synchronize()
    }
}

/// No gesture recognizer is added: record actual delivered touches without changing arbitration.
@MainActor final class ProbeWindow: UIWindow {
    var trace: Trace?
    var finger: CGPoint?
    var fingerVelocity: Double?
    private var prior: (CGPoint, TimeInterval)?
    override func sendEvent(_ event: UIEvent) {
        if let touch = event.allTouches?.first {
            let point = touch.location(in: self)
            let dt = prior.map { touch.timestamp - $0.1 } ?? 0
            fingerVelocity = dt > 0 ? Double(point.y - prior!.0.y) / dt : nil
            finger = point
            trace?.record("event", ["name": "input.touch", "data": [
                "phase": touch.phase.rawValue, "x": point.x, "y": point.y,
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
    override func loadView() { view = CalibrationView(title: "Native Sheet Reference\nOpaque calibration surface") }
    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 150, width: 260, height: 50)
        button.setTitle("Run native scenarios", for: .normal)
        button.addTarget(self, action: #selector(startDefault), for: .touchUpInside)
        view.addSubview(button)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ProcessInfo.processInfo.environment["NATIVE_AUTORUN"] == "1" && !running {
            scenario = ProcessInfo.processInfo.environment["NATIVE_SCENARIO"] ?? scenario
            trials = Int(ProcessInfo.processInfo.environment["NATIVE_TRIALS"] ?? "10") ?? 10
            start()
        }
    }
    @objc func startDefault() { start() }
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
    func start() { guard !running else { return }; running = true; trial = 0; next() }
    func after(_ seconds: Double, _ work: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work) }
    func next() {
        guard trial < trials else {
            running = false; trace?.event("batch.completed", ["trials": trials]); return
        }
        trial += 1
        let t = Trace(scenario: scenario); trace = t; probe.trace = t
        let vc = UIViewController(); vc.view = CalibrationView(title: "\(scenario)\nTrial \(trial)/\(trials)")
        vc.modalPresentationStyle = scenario.contains("form") ? .formSheet : .pageSheet
        vc.preferredContentSize = CGSize(width: 320, height: 320)
        guard let config = vc.sheetPresentationController else { fatalError("Missing native sheet") }
        let fixed = UISheetPresentationController.Detent.custom(identifier: .init("fixed320")) { context in
            t.event("detent.resolved", ["maximum": context.maximumDetentValue,
                "medium": UISheetPresentationController.Detent.medium().resolvedValue(in: context) as Any? ?? NSNull(),
                "large": UISheetPresentationController.Detent.large().resolvedValue(in: context) as Any? ?? NSNull(), "fixed": 320])
            return 320
        }
        // A custom resolver probes native medium/large resolvedValue without changing those detents.
        config.detents = [fixed, .medium(), .large()]
        config.selectedDetentIdentifier = scenario.contains("custom") ? .init("fixed320") : (scenario.contains("large.basic") ? .large : .medium)
        config.prefersGrabberVisible = true
        config.prefersPageSizing = !scenario.contains("form")
        config.prefersEdgeAttachedInCompactHeight = scenario.contains("edge")
        config.widthFollowsPreferredContentSizeWhenEdgeAttached = scenario.contains("width")
        config.prefersScrollingExpandsWhenScrolledToEdge = !scenario.contains("content_first")
        config.largestUndimmedDetentIdentifier = scenario.contains("nonmodal") ? .medium : nil
        vc.isModalInPresentation = scenario.contains("disabled")
        if #available(iOS 27.0, *), scenario.contains("placement.leading") { config.preferredPlacement = .leading }
        if #available(iOS 27.0, *), scenario.contains("placement.trailing") { config.preferredPlacement = .trailing }
        config.delegate = self
        if scenario.contains("scroll") {
            let s = UIScrollView(frame: vc.view.bounds); s.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let content = CalibrationView(title: "Long scroll\nKnown extent 2400 pt"); content.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 2400)
            s.addSubview(content); s.contentSize = content.bounds.size; vc.view.addSubview(s); scroll = s
        } else { scroll = nil }
        if scenario.contains("keyboard") {
            let field = UITextField(frame: CGRect(x: 20, y: 150, width: 280, height: 50))
            field.borderStyle = .roundedRect; field.placeholder = "Keyboard reference"; vc.view.addSubview(field)
            after(1.5) { field.becomeFirstResponder() }
        }
        sheet = vc; phase = "present"; previousY = nil
        let screen = probe.screen
        t.record("session", ["scenario_id": scenario, "implementation": "native", "evidence_kind": "runtime",
            "os": ["version": UIDevice.current.systemVersion, "build": osBuild()],
            "device": ["model": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.model,
                "logical_size": ["width": screen.bounds.width, "height": screen.bounds.height],
                "physical_size": ["width": screen.nativeBounds.width, "height": screen.nativeBounds.height],
                "scale": screen.scale, "refresh_hz": screen.maximumFramesPerSecond],
            "environment": ["orientation": view.window?.windowScene?.interfaceOrientation.isLandscape == true ? "landscape" : "portrait",
                "safe_area": insets(view.safeAreaInsets), "size_classes": ["horizontal": traitCollection.horizontalSizeClass.rawValue == 1 ? "compact" : "regular", "vertical": traitCollection.verticalSizeClass.rawValue == 1 ? "compact" : "regular"],
                "status_bar": ["hidden": prefersStatusBarHidden], "keyboard": ["visible": false, "frame": rect(keyboardFrame)]],
            "configuration": ["trial": trial, "detents": ["fixed320", "medium", "large"], "surface": "opaque.white", "grabber": true, "page_sizing": config.prefersPageSizing,
                "modal_in_presentation": vc.isModalInPresentation, "largest_undimmed": config.largestUndimmedDetentIdentifier?.rawValue as Any? ?? NSNull()]])
        link?.invalidate(); link = CADisplayLink(target: self, selector: #selector(sample(_:))); link!.add(to: .main, forMode: .common)
        t.event("present.requested"); t.event("present.started")
        present(vc, animated: true) {
            t.event("present.completed") // Completion callback does not establish physical settling.
            self.phase = "idle"
        }
        // Manual gesture scenarios intentionally stay open for external input replay.
        guard !scenario.contains("drag") && !scenario.contains("scroll") && !scenario.contains("keyboard") else { return }
        after(1.5) {
            self.target = "large"; self.phase = "detent"
            t.event("detent.requested", ["target": "large"])
            config.animateChanges { config.selectedDetentIdentifier = .large }
        }
        after(3) {
            self.target = "medium"; self.phase = "detent"
            t.event("detent.requested", ["target": "medium"])
            config.animateChanges { config.selectedDetentIdentifier = .medium }
        }
        after(4.5) {
            self.phase = "dismiss"; t.event("dismiss.requested")
            vc.dismiss(animated: true) {
                t.event("dismiss.completed"); self.link?.invalidate(); self.sheet = nil
                self.after(0.4) { self.next() }
            }
        }
    }
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ controller: UISheetPresentationController) {
        trace?.event("detent.changed", ["selected": controller.selectedDetentIdentifier?.rawValue as Any? ?? NSNull()])
    }
    func presentationControllerDidDismiss(_ controller: UIPresentationController) {
        trace?.event("dismiss.interactive_completed"); link?.invalidate(); sheet = nil; running = false
    }
    func layerInfo(_ view: UIView, in window: UIWindow) -> [String: Any] {
        let layer = view.layer.presentation() ?? view.layer
        let target = window.layer.presentation() ?? window.layer
        return ["class": NSStringFromClass(type(of: view)), "frame_window": rect(layer.convert(layer.bounds, to: target)),
            "bounds": rect(layer.bounds), "corner_radius": layer.cornerRadius, "corner_curve": layer.cornerCurve.rawValue,
            "opacity": layer.opacity, "hidden": layer.isHidden, "clips": layer.masksToBounds,
            "background": layer.backgroundColor.map { UIColor(cgColor: $0).description } as Any? ?? NSNull(),
            "transform": [layer.transform.m11, layer.transform.m12, layer.transform.m21, layer.transform.m22, layer.transform.m41, layer.transform.m42]]
    }
    @objc func sample(_ display: CADisplayLink) {
        guard let trace, let sheet else { return }
        let container = sheet.presentationController?.presentedView ?? sheet.view!
        let l = container.layer.presentation() ?? container.layer
        let windowLayer = probe.layer.presentation() ?? probe.layer
        let r = l.convert(l.bounds, to: windowLayer)
        let pl = view.layer.presentation() ?? view.layer
        let t = CACurrentMediaTime()
        let velocity = previousY.map { (Double(r.minY) - $0.0) / (t - $0.1) }
        previousY = (Double(r.minY), t)
        var metrics: [String: Any] = ["sheet.x": r.minX, "sheet.y": r.minY, "sheet.width": r.width, "sheet.height": r.height,
            "sheet.visible_height": r.intersection(probe.bounds).height, "sheet.top": r.minY, "sheet.bottom": r.maxY,
            "sheet.left_inset": r.minX, "sheet.right_inset": probe.bounds.maxX - r.maxX, "sheet.bottom_inset": probe.bounds.maxY - r.maxY,
            "sheet.detent_height": NSNull(), "sheet.radius": NSNull(), "barrier.alpha": NSNull(),
            "presenter.scale_x": pl.transform.m11, "presenter.scale_y": pl.transform.m22,
            "presenter.translation_x": pl.transform.m41, "presenter.translation_y": pl.transform.m42,
            "presenter.radius": pl.cornerRadius, "sheet.velocity_y": velocity as Any? ?? NSNull(),
            "finger.y": probe.finger?.y as Any? ?? NSNull(), "finger.velocity_y": probe.fingerVelocity as Any? ?? NSNull(),
            "scroll.offset": scroll?.contentOffset.y as Any? ?? NSNull()]
        for (key, value) in metrics { if let n = value as? Double, !n.isFinite { metrics[key] = NSNull() } }
        var layers: [[String: Any]] = []
        func walk(_ node: UIView, _ depth: Int) {
            if depth > 6 { return }; var info = layerInfo(node, in: probe); info["depth"] = depth; layers.append(info)
            node.subviews.forEach { walk($0, depth + 1) }
        }
        probe.subviews.forEach { walk($0, 0) }
        trace.record("frame", ["metrics": metrics,
            "state": ["phase": phase, "selected_detent": sheet.sheetPresentationController?.selectedDetentIdentifier?.rawValue as Any? ?? NSNull(),
                "target_detent": target as Any? ?? NSNull(), "gesture": probe.finger == nil ? "none" : "touch", "scroll_owner": NSNull(), "underlying_hit_test": NSNull()],
            "unavailable": ["sheet.radius": "Container scalar may not represent visible clipping shape; inspect raw layers",
                "sheet.detent_height": "Only resolver context provides native resolved height", "barrier.alpha": "Unclassified system layer", "underlying_hit_test": "Requires actual background touch"],
            "display": ["timestamp": display.timestamp, "target_timestamp": display.targetTimestamp, "duration": display.duration],
            "raw_layers": layers, "keyboard_frame": rect(keyboardFrame)], time: t)
    }
}

@main @MainActor final class App: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let harness = Harness()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = ProbeWindow(frame: UIScreen.main.bounds); w.rootViewController = harness; w.makeKeyAndVisible(); window = w
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool { harness.open(url); return true }
}
