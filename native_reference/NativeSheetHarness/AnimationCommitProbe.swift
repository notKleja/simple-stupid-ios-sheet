import Foundation
import QuartzCore
import ObjectiveC.runtime

/// Discrete object/model observations. A main-queue turn is deliberately not
/// asserted to be a transaction commit, render-server epoch, or trajectory.
final class AnimationCommitProbe {
    struct Install {
        let probe: AnimationCommitProbe
        let id: String
        let layer: CALayer
        let key: String?
        let phase: String
        let input: CAAnimation
        let ownerBacktrace: [[String: Any]]
    }
    private static var active: AnimationCommitProbe?
    private static let hook: Void = {
        for (original, replacement) in [
            (#selector(CALayer.removeAnimation(forKey:)), #selector(CALayer.commitProbeRemove(forKey:))),
            (#selector(CALayer.removeAllAnimations), #selector(CALayer.commitProbeRemoveAll))] {
            method_exchangeImplementations(class_getInstanceMethod(CALayer.self, original)!, class_getInstanceMethod(CALayer.self, replacement)!)
        }
    }()
    private let serializer: AnimationProbe
    private let runID: String
    private let trial: Int
    private let sink: ([String: Any]) -> Void
    private var installs: [Install] = []
    private var current: [ObjectIdentifier: [String: String]] = [:]
    private var phase = "presentation"
    private var started = false
    private var stopped = false
    private var delivering = false
    init(runID: String, trial: Int, sink: @escaping ([String: Any]) -> Void) {
        self.runID = runID; self.trial = trial; self.sink = sink
        serializer = AnimationProbe(runID: runID, trial: trial, sink: { row in
            if row["type"] as? String == "animation_probe.error" {
                var error = row; error["type"] = "animation_commit.error"; sink(error)
            }
        })
    }
    func start(phase: String) throws {
        precondition(Thread.isMainThread)
        guard !started && !stopped else { throw AnimationProbeError.reusedProbe }
        started = true; self.phase = phase
        _ = Self.hook
        Self.active?.stop(); Self.active = self
        // Reuse the established add hook without a second exchange.
        try serializer.start(phase: phase)
    }
    func setPhase(_ value: String) { precondition(Thread.isMainThread); phase = value }
    func stop() {
        precondition(Thread.isMainThread)
        if Self.active === self { Self.active = nil }
        stopped = true; serializer.stop(); installs.removeAll(); current.removeAll()
    }
    private func emit(_ install: Install, stage: String, rowType: String = "animation_commit") {
        guard !stopped && !delivering else { return }
        delivering = true; defer { delivering = false }
        do {
            var row = try serializer.snapshot(layer: install.layer, animation: install.input, key: install.key,
                                              phase: install.phase, includePresentation: false)
            let installed = install.key.flatMap { install.layer.animation(forKey: $0) }
            row["type"] = rowType; row["install_id"] = install.id; row["stage"] = stage
            row["owner_backtrace"] = install.ownerBacktrace
            row["installed_animation"] = try installed.map {
                try serializer.snapshot(layer: install.layer, animation: $0, key: install.key,
                                        phase: install.phase, includePresentation: false)["animation"]!
            } as Any? ?? NSNull()
            row["commit_epoch_status"] = "unresolved_next_runloop_is_not_commit"
            row["installation_status"] = install.key == nil ? "unresolved_nil_key" :
                (current[ObjectIdentifier(install.layer)]?[install.key!] == install.id ? "current" : "superseded")
            row["observation_boundary"] = stage == "next_runloop" ? "main_queue_async_no_flush" : "synchronous_call_boundary"
            var layer = row["layer"] as! [String: Any]
            layer["timing"] = timing(install.layer)
            layer["delegate"] = install.layer.delegate.map {
                ["class": NSStringFromClass(type(of: $0)), "address": String(format: "0x%llx", UInt64(UInt(bitPattern: Unmanaged.passUnretained($0).toOpaque())))]
            } as Any? ?? NSNull()
            var ancestry = layer["ancestry"] as! [[String: Any]]
            var cursor = install.layer.superlayer
            for index in ancestry.indices { ancestry[index]["timing"] = timing(cursor!); cursor = cursor?.superlayer }
            layer["ancestry"] = ancestry; row["layer"] = layer
            sink(row)
        } catch {
            sink(["type": "animation_commit.error", "run_id": runID, "trial": trial,
                  "install_id": install.id, "error": String(describing: error)])
        }
    }
    private func timing(_ layer: CALayer) -> [String: Any] {
        ["begin_time": layer.beginTime, "speed": Double(layer.speed), "time_offset": layer.timeOffset,
         "local_media_time": layer.convertTime(CACurrentMediaTime(), from: nil)]
    }
    static func beforeAdd(_ layer: CALayer, _ animation: CAAnimation, _ key: String?) -> Install? {
        guard Thread.isMainThread, let probe = active, !probe.stopped, !probe.delivering else { return nil }
        do {
            let input = animation.copy() as! CAAnimation
            let owner = try probe.serializer.snapshot(layer: layer, animation: input, key: key, phase: probe.phase, includePresentation: false)["backtrace"] as! [[String: Any]]
            let install = Install(probe: probe, id: "install.\(probe.installs.count + 1)", layer: layer, key: key,
                                  phase: probe.phase, input: input, ownerBacktrace: owner)
            probe.installs.append(install)
            if let key { probe.current[ObjectIdentifier(layer), default: [:]][key] = install.id }
            probe.emit(install, stage: "pre_forward")
            return install
        } catch { probe.sink(["type": "animation_commit.error", "run_id": probe.runID, "trial": probe.trial, "error": String(describing: error)]); return nil }
    }
    static func afterAdd(_ install: Install?) {
        guard let install else { return }
        install.probe.emit(install, stage: "post_forward")
        DispatchQueue.main.async { [weak probe = install.probe] in
            guard let probe, !probe.stopped else { return }
            probe.emit(install, stage: "next_runloop")
        }
    }
    static func removals(_ layer: CALayer, key: String?) -> [Install] {
        guard Thread.isMainThread, let probe = active, !probe.stopped, !probe.delivering else { return [] }
        return probe.installs.filter { $0.layer === layer && (key == nil || $0.key == key) }
            .filter { item in item.key.map { probe.current[ObjectIdentifier(layer)]?[$0] == item.id } ?? false }
    }
    static func recordRemoval(_ installs: [Install], stage: String) {
        for item in installs { item.probe.emit(item, stage: stage, rowType: "animation_cleanup") }
    }
    func checkpoint(_ name: String) {
        precondition(Thread.isMainThread)
        for item in installs { emit(item, stage: "checkpoint." + name, rowType: "animation_cleanup") }
    }
}

extension CALayer {
    @objc fileprivate func commitProbeRemove(forKey key: String) {
        let installs = AnimationCommitProbe.removals(self, key: key)
        AnimationCommitProbe.recordRemoval(installs, stage: "pre_remove")
        commitProbeRemove(forKey: key)
        AnimationCommitProbe.recordRemoval(installs, stage: "post_remove")
    }
    @objc fileprivate func commitProbeRemoveAll() {
        let installs = AnimationCommitProbe.removals(self, key: nil)
        AnimationCommitProbe.recordRemoval(installs, stage: "pre_remove_all")
        commitProbeRemoveAll()
        AnimationCommitProbe.recordRemoval(installs, stage: "post_remove_all")
    }
}
