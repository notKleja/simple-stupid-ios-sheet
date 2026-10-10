import Foundation
import QuartzCore

@main struct NativeAnimationCommitProbeTests {
    static func main() throws {
        var rows: [[String: Any]] = []
        let layer = CALayer(); layer.position = CGPoint(x: 8, y: 13)
        let parent = CALayer(); parent.speed = 0.5; parent.addSublayer(layer)
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(point: CGPoint(x: 0, y: 2))
        animation.toValue = NSValue(point: .zero)
        animation.duration = 3; animation.isAdditive = true
        animation.isRemovedOnCompletion = false; animation.fillMode = .both
        let probe = AnimationCommitProbe(runID: "commit-run", trial: 1) { rows.append($0) }
        try probe.start(phase: "presentation")
        layer.add(animation, forKey: "position")
        precondition(rows.count == 2, "Pre and post snapshots surround original add")
        precondition(rows[0]["stage"] as? String == "pre_forward")
        precondition(rows[1]["stage"] as? String == "post_forward")
        let id = rows[0]["install_id"] as! String
        precondition(rows[1]["install_id"] as? String == id)
        precondition(rows[0]["installed_animation"] is NSNull)
        let installed = rows[1]["installed_animation"] as! [String: Any]
        precondition(installed["duration"] as? Double == 3)
        animation.duration = 99
        layer.position = CGPoint(x: 8, y: 21)
        let deadline = Date().addingTimeInterval(2)
        while rows.count < 3 && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        precondition(rows.count == 3 && rows[2]["stage"] as? String == "next_runloop")
        precondition(rows[2]["install_id"] as? String == id)
        precondition((rows[2]["installed_animation"] as! [String: Any])["duration"] as? Double == 3)
        precondition(rows[2]["commit_epoch_status"] as? String == "unresolved_next_runloop_is_not_commit")
        let state = (rows[2]["layer"] as! [String: Any])["model_state"] as! [String: Any]
        precondition(state["position"] as? [Double] == [8, 21])
        let ancestry = (rows[2]["layer"] as! [String: Any])["ancestry"] as! [[String: Any]]
        precondition(ancestry.count == 1 && (ancestry[0]["timing"] as! [String: Any])["speed"] as? Double == 0.5)
        precondition((rows[2]["layer"] as! [String: Any])["presentation_state"] is NSNull)
        layer.removeAnimation(forKey: "position")
        let cleanup = rows.filter { $0["type"] as? String == "animation_cleanup" }
        precondition(cleanup.count == 2 && cleanup[0]["stage"] as? String == "pre_remove" && cleanup[1]["stage"] as? String == "post_remove")
        precondition(cleanup.allSatisfy { $0["install_id"] as? String == id })
        precondition(cleanup[1]["installed_animation"] is NSNull)
        probe.checkpoint("terminal")
        precondition(rows.last?["stage"] as? String == "checkpoint.terminal")
        precondition(rows.last?["installed_animation"] is NSNull)
        let count = rows.count; probe.stop()
        layer.add(animation, forKey: "stopped")
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        precondition(rows.count == count, "Closed probe has no deferred records")
        do { try probe.start(phase: "restart"); fatalError("Single-use lifetime") } catch {}
        let bytes = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        precondition(!String(data: bytes, encoding: .utf8)!.contains("sheet.y"))
        print("PASS NativeAnimationCommitProbeTests: paired immutable copies, model ancestry timing, deferred boundary, cleanup, lifetime")
    }
}
