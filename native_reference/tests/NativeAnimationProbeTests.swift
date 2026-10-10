import Foundation
import QuartzCore

@main struct NativeAnimationProbeTests {
    static func main() throws {
        let layer = CALayer(); layer.position = CGPoint(x: 20, y: 30)
        let parent = CALayer(); parent.transform = CATransform3DMakeScale(2, 3, 1); parent.addSublayer(layer)
        let spring = CASpringAnimation(keyPath: "position")
        spring.fromValue = NSValue(point: CGPoint(x: 1, y: 2))
        spring.toValue = NSValue(point: CGPoint(x: 20, y: 30))
        spring.mass = 2; spring.stiffness = 300; spring.damping = 40
        spring.initialVelocity = 3; spring.duration = 0.75
        spring.beginTime = 12; spring.timeOffset = 0.1; spring.speed = 0.5
        spring.repeatCount = 2; spring.repeatDuration = 4; spring.autoreverses = true
        spring.fillMode = .both; spring.isRemovedOnCompletion = false
        spring.isAdditive = true; spring.isCumulative = true
        spring.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.2, 0.3, 0.4)
        let probe = AnimationProbe(runID: "literal-run", trial: 1, sink: { _ in })
        let before = try probe.snapshot(layer: layer, animation: spring, key: "position", phase: "present")
        let required: Set<String> = ["animation_class", "key_path", "from_value", "to_value", "by_value", "current_value", "model_value", "timing_function", "spring", "duration", "begin_time", "time_offset", "speed", "repeat_count", "repeat_duration", "autoreverses", "fill_mode", "additive", "cumulative", "removed_on_completion", "children", "keyframe", "transition"]
        let animation = before["animation"] as! [String: Any]
        precondition(Set(animation.keys) == required, "Complete CA object contract")
        precondition((before["layer"] as! [String: Any])["address"] as? String != nil)
        precondition((before["layer"] as! [String: Any])["class"] as? String == "CALayer")
        let ancestry = (before["layer"] as! [String: Any])["ancestry"] as! [[String: Any]]
        precondition(ancestry.count == 1 && ((ancestry[0]["model_state"] as! [String: Any])["transform"] as! [Double])[5] == 3)
        precondition(before["key"] as? String == "position")
        precondition(before["transaction_time"] as? Double != nil)
        precondition(before["t_ns"] as? Int64 != nil)
        precondition(!(before["backtrace"] as! [[String: Any]]).isEmpty)
        for frame in before["backtrace"] as! [[String: Any]] {
            precondition(frame["address"] != nil && frame["image"] != nil && frame["image_uuid"] != nil && frame["image_offset"] != nil && frame["symbol"] != nil)
        }
        let params = animation["spring"] as! [String: Any]
        precondition(params["mass"] as? Double == 2 && params["stiffness"] as? Double == 300 && params["damping"] as? Double == 40 && params["initial_velocity"] as? Double == 3)
        precondition(params["settling_duration"] as? Double == spring.settlingDuration)
        precondition(params["allows_overdamping"] != nil, "Solver branch selector is explicit, even when unavailable")
        precondition(animation["duration"] as? Double == 0.75 && animation["fill_mode"] as? String == "both")
        precondition(animation["by_value"] is NSNull)
        let points = (animation["timing_function"] as! [String: Any])["control_points"] as! [[Double]]
        precondition(points.count == 4 && abs(points[1][0] - 0.1) < 1e-7 && abs(points[2][1] - 0.4) < 1e-7)
        let immutable = try JSONSerialization.data(withJSONObject: before, options: [.sortedKeys])
        spring.mass = 99; layer.position = .zero
        let afterMutation = try JSONSerialization.data(withJSONObject: before, options: [.sortedKeys])
        precondition(afterMutation == immutable, "Snapshot cannot retain live mutable objects")
        let same = try probe.snapshot(layer: layer, animation: CABasicAnimation(keyPath: "opacity"), key: nil, phase: "detent.medium")
        precondition((same["layer"] as! [String: Any])["id"] as? String == (before["layer"] as! [String: Any])["id"] as? String)
        precondition(same["key"] is NSNull)
        let other = AnimationProbe(runID: "other-run", trial: 2, sink: { _ in })
        let fresh = try other.snapshot(layer: CALayer(), animation: CAAnimation(), key: nil, phase: "dismiss")
        precondition((fresh["layer"] as! [String: Any])["id"] as? String == "layer.1", "Layer IDs reset each run")
        let group = CAAnimationGroup(); group.animations = [spring, CABasicAnimation(keyPath: "opacity")]
        let grouped = try probe.snapshot(layer: layer, animation: group, key: "group", phase: "dismiss")
        precondition(((grouped["animation"] as! [String: Any])["children"] as! [[String: Any]]).count == 2)
        let unknown = CABasicAnimation(keyPath: "opacity"); unknown.fromValue = NSObject()
        do { _ = try probe.snapshot(layer: layer, animation: unknown, key: nil, phase: "dismiss"); fatalError("Unsupported CA values must fail closed") } catch {}
        let indefinite = CABasicAnimation(keyPath: "opacity"); indefinite.duration = .infinity
        let indefiniteRow = try probe.snapshot(layer: layer, animation: indefinite, key: "indefinite", phase: "presentation")
        let infinity = (indefiniteRow["animation"] as! [String: Any])["duration"] as! [String: String]
        precondition(infinity == ["ieee754": "positive_infinity", "bits_hex": "7ff0000000000000"], "Preserve real OS nonfinite values without clamping; host loader rejects them")
        let provider = CGDataProvider(data: Data([0,0,0,0]) as CFData)!
        let image = CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let contents = CABasicAnimation(keyPath: "contents"); contents.fromValue = image
        let pixels = try probe.snapshot(layer: layer, animation: contents, key: "contents", phase: "presentation")
        let opaque = ((pixels["animation"] as! [String: Any])["from_value"] as! [String: Any])["opaque_reference"] as! [String: Any]
        precondition(Set(opaque.keys) == ["cf_type_id", "runtime_class", "address", "reason"])
        precondition(opaque["reason"] as? String == "pixel_backing_not_captured")
        precondition(opaque["bytes"] == nil && opaque["description"] == nil)
        var installed: [[String: Any]] = []
        let recorder = AnimationProbe(runID: "install-run", trial: 1, sink: { installed.append($0) })
        try recorder.start(phase: "present")
        let actual = CABasicAnimation(keyPath: "opacity"); actual.fromValue = 0; actual.toValue = 1; actual.duration = 2
        layer.add(actual, forKey: "audit-opacity")
        precondition(installed.count == 1 && layer.animation(forKey: "audit-opacity")?.duration == 2, "Capture must forward original installation")
        recorder.stop(); layer.add(actual, forKey: "after-stop")
        precondition(installed.count == 1, "No cross-run or post-stop capture")
        do { try recorder.start(phase: "restarted"); fatalError("A stopped run must not restart with stale identities") } catch {}
        var reentry: [[String: Any]] = []
        let nestedLayer = CALayer()
        let recursive = AnimationProbe(runID: "reentry-run", trial: 1) { row in
            reentry.append(row)
            nestedLayer.add(actual, forKey: "logger-induced")
        }
        try recursive.start(phase: "present")
        layer.add(actual, forKey: "outer")
        precondition(reentry.count == 1 && nestedLayer.animation(forKey: "logger-induced") != nil, "Thread-local recursion guard must still forward nested installs")
        recursive.stop()
        var failures: [[String: Any]] = []
        let concurrent = AnimationProbe(runID: "concurrent-run", trial: 1) { failures.append($0) }
        try concurrent.start(phase: "present")
        let backgroundLayer = CALayer(); let completed = DispatchGroup(); completed.enter()
        DispatchQueue.global().async {
            backgroundLayer.add(actual, forKey: "concurrent-legitimate")
            precondition(backgroundLayer.animation(forKey: "concurrent-legitimate") != nil, "Original background install forwards before its transaction/thread ends")
            completed.leave()
        }
        precondition(completed.wait(timeout: .now() + 5) == .success, "Hook must not deadlock concurrent installation")
        let deadline = Date().addingTimeInterval(2)
        while failures.isEmpty && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        precondition(concurrent.invalidated && failures.count == 1 && failures[0]["type"] as? String == "animation_probe.error", "Unsupported off-thread capture must explicitly fail the run, never be silently suppressed")
        precondition((failures[0]["error"] as? String)?.contains("off_thread_capture") == true)
        concurrent.stop()
        do { try concurrent.start(phase: "retry"); fatalError("An invalidated run must not restart") } catch {}
        var overlapRows: [[String: Any]] = []
        let overlapBackground = CALayer()
        let overlap = AnimationProbe(runID: "overlap-run", trial: 1) { row in
            overlapRows.append(row)
            if row["type"] as? String == "animation_install" {
                let worker = DispatchGroup(); worker.enter()
                DispatchQueue.global().async { overlapBackground.add(actual, forKey: "during-main-logging"); worker.leave() }
                precondition(worker.wait(timeout: .now() + 5) == .success, "Concurrent capture during sink delivery cannot deadlock")
            }
        }
        try overlap.start(phase: "present"); layer.add(actual, forKey: "overlap-main")
        let overlapDeadline = Date().addingTimeInterval(2)
        while overlapRows.count < 2 && Date() < overlapDeadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        precondition(overlap.invalidated && overlapRows.filter { $0["type"] as? String == "animation_probe.error" }.count == 1, "A different thread's legitimate install must not disappear under the logger recursion guard")
        overlap.stop()
        precondition(!String(data: immutable, encoding: .utf8)!.contains("sheet.y"))
        print("PASS NativeAnimationProbeTests: complete immutable objects, timing, spring, backtrace, run IDs, forwarding, fail closed")
    }
}
