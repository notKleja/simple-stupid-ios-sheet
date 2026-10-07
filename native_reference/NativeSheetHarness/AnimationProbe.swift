import Foundation
import QuartzCore
import ObjectiveC.runtime
import Darwin
import MachO

enum AnimationProbeError: Error { case unsupportedValue(String), serialization(String), reusedProbe, stoppedProbe }

/// Install-boundary observations only. No display link, screen-coordinate
/// conversion, trajectory sampler, or changes to the installed CA object.
final class AnimationProbe {
    private static var active: AnimationProbe?
    private static let lifecycleLock = NSRecursiveLock()
    private static let recursionKey = "dev.notkleja.animation-probe.logging"
    private static let hook: Void = {
        let original = class_getInstanceMethod(CALayer.self, #selector(CALayer.add(_:forKey:)))!
        let replacement = class_getInstanceMethod(CALayer.self, #selector(CALayer.motionProbeAdd(_:forKey:)))!
        method_exchangeImplementations(original, replacement)
    }()
    private let runID: String
    private let trial: Int
    private let sink: ([String: Any]) -> Void
    private var ids: [ObjectIdentifier: String] = [:]
    // Retain model layers until stop so reused addresses cannot reuse an ID.
    private var layers: [CALayer] = []
    private var phase = "present"
    private let stateLock = NSRecursiveLock()
    private let sinkLock = NSRecursiveLock()
    private var started = false
    private var stopped = false
    private var failed = false
    var invalidated: Bool { stateLock.lock(); defer { stateLock.unlock() }; return failed }

    init(runID: String, trial: Int, sink: @escaping ([String: Any]) -> Void) {
        self.runID = runID; self.trial = trial; self.sink = sink
    }
    func start(phase: String) throws {
        precondition(Thread.isMainThread, "Probe lifecycle belongs to main thread")
        stateLock.lock()
        guard !started && !stopped else { stateLock.unlock(); throw AnimationProbeError.reusedProbe }
        started = true; self.phase = phase; stateLock.unlock()
        Self.lifecycleLock.lock(); defer { Self.lifecycleLock.unlock() }
        Self.active?.stop()
        _ = Self.hook; Self.active = self
    }
    func setPhase(_ value: String) { stateLock.lock(); defer { stateLock.unlock() }; phase = value }
    func stop() {
        Self.lifecycleLock.lock(); defer { Self.lifecycleLock.unlock() }
        if Self.active === self { Self.active = nil }
        stateLock.lock(); defer { stateLock.unlock() }
        stopped = true; layers.removeAll(); ids.removeAll()
    }
    private func deliver(_ row: [String: Any]) {
        sinkLock.lock(); defer { sinkLock.unlock() }
        let thread = Thread.current.threadDictionary
        let prior = thread[Self.recursionKey]
        thread[Self.recursionKey] = true
        defer { if let prior { thread[Self.recursionKey] = prior } else { thread.removeObject(forKey: Self.recursionKey) } }
        sink(row)
    }
    private func fail(_ error: String, animation: CAAnimation, key: String?) {
        stateLock.lock()
        guard !failed && !stopped else { stateLock.unlock(); return }
        failed = true; stateLock.unlock()
        let row: [String: Any] = ["type": "animation_probe.error", "run_id": runID,
            "trial": trial, "animation_class": NSStringFromClass(type(of: animation)),
            "key": key as Any? ?? NSNull(), "key_path": (animation as? CAPropertyAnimation)?.keyPath as Any? ?? NSNull(), "error": error]
        // Trace/App lifecycle belongs to main. Off-thread failures are explicit
        // terminal evidence delivered there, never concurrent FileHandle writes.
        if Thread.isMainThread { deliver(row) }
        else { DispatchQueue.main.async { self.deliver(row) } }
    }
    fileprivate static func capture(_ layer: CALayer, _ animation: CAAnimation, _ key: String?) {
        guard Thread.current.threadDictionary[recursionKey] as? Bool != true else { return }
        lifecycleLock.lock(); let probe = active; lifecycleLock.unlock()
        guard let probe else { return }
        guard Thread.isMainThread else { probe.fail("off_thread_capture: run is invalid; original installation forwarded", animation: animation, key: key); return }
        probe.stateLock.lock()
        guard !probe.failed && !probe.stopped else { probe.stateLock.unlock(); return }
        let phase = probe.phase; probe.stateLock.unlock()
        do { probe.deliver(try probe.snapshot(layer: layer, animation: animation, key: key, phase: phase)) }
        catch {
            probe.fail(String(describing: error), animation: animation, key: key)
        }
    }
    private func layerID(_ layer: CALayer) -> String {
        let key = ObjectIdentifier(layer)
        if let id = ids[key] { return id }
        let id = "layer.\(ids.count + 1)"; ids[key] = id; layers.append(layer); return id
    }
    func snapshot(layer: CALayer, animation: CAAnimation, key: String?, phase: String) throws -> [String: Any] {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !stopped else { throw AnimationProbeError.stoppedProbe }
        let now = CACurrentMediaTime()
        // Capture the call stack before serialization or forwarding.
        let addresses = Thread.callStackReturnAddresses
        let row: [String: Any] = ["schema_version": 1, "type": "animation_install", "run_id": runID,
            "trial": trial, "phase": phase, "t_ns": Int64(now * 1e9),
            "transaction_time": now, "layer": ["id": layerID(layer),
                "address": String(format: "0x%llx", UInt64(UInt(bitPattern: Unmanaged.passUnretained(layer).toOpaque()))),
                "class": NSStringFromClass(type(of: layer)),
                "parent_id": layer.superlayer.map(layerID) as Any? ?? NSNull(),
                "model_state": try state(layer), "presentation_state": try layer.presentation().map(state) as Any? ?? NSNull(),
                "ancestry": try ancestry(layer)],
            "key": key as Any? ?? NSNull(), "animation": try object(animation, layer: layer),
            "transaction": ["duration": CATransaction.animationDuration(), "disable_actions": CATransaction.disableActions(),
                "timing_function": timing(CATransaction.animationTimingFunction())],
            "backtrace": addresses.map(Self.frame)]
        let immutable = Self.preserveIEEE(row) as! [String: Any]
        guard JSONSerialization.isValidJSONObject(immutable) else {
            throw AnimationProbeError.serialization(Self.invalidJSON(immutable, path: "install"))
        }
        return immutable
    }
    private static func preserveIEEE(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] { return dictionary.mapValues(preserveIEEE) }
        if let array = value as? [Any] { return array.map(preserveIEEE) }
        if let number = value as? NSNumber, !number.doubleValue.isFinite {
            let v = number.doubleValue
            return ["ieee754": v.isNaN ? "nan" : (v > 0 ? "positive_infinity" : "negative_infinity"),
                "bits_hex": String(format: "%016llx", v.bitPattern)]
        }
        return value
    }
    private static func invalidJSON(_ value: Any, path: String) -> String {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys.sorted().compactMap { key in
                JSONSerialization.isValidJSONObject([dictionary[key]!]) ? nil : invalidJSON(dictionary[key]!, path: path + "." + key)
            }.joined(separator: "; ")
        }
        if let array = value as? [Any] {
            return array.enumerated().compactMap { index, item in
                JSONSerialization.isValidJSONObject([item]) ? nil : invalidJSON(item, path: path + ".\(index)")
            }.joined(separator: "; ")
        }
        return "\(path): \(String(reflecting: type(of: value))) = \(value)"
    }
    private func state(_ layer: CALayer) throws -> [String: Any] {
        ["position": [Double(layer.position.x), Double(layer.position.y)],
         "bounds": [Double(layer.bounds.origin.x), Double(layer.bounds.origin.y), Double(layer.bounds.width), Double(layer.bounds.height)],
         "anchor_point": [Double(layer.anchorPoint.x), Double(layer.anchorPoint.y)], "anchor_point_z": Double(layer.anchorPointZ),
         "transform": matrix(layer.transform), "sublayer_transform": matrix(layer.sublayerTransform),
         "opacity": Double(layer.opacity), "z_position": Double(layer.zPosition), "geometry_flipped": layer.isGeometryFlipped]
    }
    private func ancestry(_ layer: CALayer) throws -> [[String: Any]] {
        var result: [[String: Any]] = []; var cursor = layer.superlayer
        while let parent = cursor {
            result.append(["id": layerID(parent), "address": String(format: "0x%llx", UInt64(UInt(bitPattern: Unmanaged.passUnretained(parent).toOpaque()))),
                "class": NSStringFromClass(type(of: parent)), "model_state": try state(parent),
                "presentation_state": try parent.presentation().map(state) as Any? ?? NSNull()])
            cursor = parent.superlayer
        }
        return result
    }
    private func matrix(_ t: CATransform3D) -> [Double] {
        [t.m11,t.m12,t.m13,t.m14,t.m21,t.m22,t.m23,t.m24,t.m31,t.m32,t.m33,t.m34,t.m41,t.m42,t.m43,t.m44].map(Double.init)
    }
    private func timing(_ function: CAMediaTimingFunction?) -> Any {
        guard let function else { return NSNull() }
        let points = (0..<4).map { index -> [Double] in
            var pair = [Float](repeating: 0, count: 2)
            function.getControlPoint(at: index, values: &pair); return pair.map(Double.init)
        }
        let names: [CAMediaTimingFunctionName] = [.linear, .easeIn, .easeOut, .easeInEaseOut, .default]
        let name = names.first { candidate in
            let standard = CAMediaTimingFunction(name: candidate)
            return (0..<4).allSatisfy { index in
                var pair = [Float](repeating: 0, count: 2); standard.getControlPoint(at: index, values: &pair)
                return pair.map(Double.init) == points[index]
            }
        }?.rawValue ?? "custom"
        return ["name": name, "control_points": points]
    }
    private func object(_ a: CAAnimation, layer: CALayer) throws -> [String: Any] {
        let basic = a as? CABasicAnimation; let property = a as? CAPropertyAnimation
        let spring = a as? CASpringAnimation; let keyframe = a as? CAKeyframeAnimation; let transition = a as? CATransition
        let keyPath = property?.keyPath
        return ["animation_class": NSStringFromClass(type(of: a)), "key_path": keyPath as Any? ?? NSNull(),
            "from_value": try value(basic?.fromValue), "to_value": try value(basic?.toValue), "by_value": try value(basic?.byValue),
            "model_value": try value(keyPath.flatMap { layer.value(forKeyPath: $0) }),
            "current_value": try value(keyPath.flatMap { layer.presentation()?.value(forKeyPath: $0) }),
            "timing_function": timing(a.timingFunction),
            "spring": spring.map { ["mass": Double($0.mass), "stiffness": Double($0.stiffness), "damping": Double($0.damping),
                "initial_velocity": Double($0.initialVelocity), "settling_duration": $0.settlingDuration,
                "allows_overdamping": $0.responds(to: NSSelectorFromString("allowsOverdamping")) ? $0.value(forKey: "allowsOverdamping") as Any? ?? NSNull() : NSNull()] as [String: Any] } as Any? ?? NSNull(),
            "duration": a.duration, "begin_time": a.beginTime, "time_offset": a.timeOffset, "speed": Double(a.speed),
            "repeat_count": Double(a.repeatCount), "repeat_duration": a.repeatDuration, "autoreverses": a.autoreverses,
            "fill_mode": a.fillMode.rawValue, "additive": property?.isAdditive as Any? ?? NSNull(),
            "cumulative": property?.isCumulative as Any? ?? NSNull(), "removed_on_completion": a.isRemovedOnCompletion,
            "children": try (a as? CAAnimationGroup)?.animations?.map { try object($0, layer: layer) } as Any? ?? NSNull(),
            "keyframe": try keyframe.map { ["values": try value($0.values), "key_times": try value($0.keyTimes),
                "timing_functions": $0.timingFunctions?.map(timing) as Any? ?? NSNull(), "path": try value($0.path),
                "calculation_mode": $0.calculationMode.rawValue, "rotation_mode": $0.rotationMode?.rawValue as Any? ?? NSNull(),
                "tension_values": try value($0.tensionValues), "continuity_values": try value($0.continuityValues),
                "bias_values": try value($0.biasValues)] } as Any? ?? NSNull(),
            "transition": transition.map { ["type": $0.type.rawValue, "subtype": $0.subtype?.rawValue as Any? ?? NSNull(),
                "start_progress": $0.startProgress, "end_progress": $0.endProgress] as [String: Any] } as Any? ?? NSNull()]
    }
    private func value(_ raw: Any?) throws -> Any {
        guard let raw else { return NSNull() }
        if raw is NSNull { return NSNull() }
        if let number = raw as? NSNumber { return number }
        if let text = raw as? String { return text }
        if let array = raw as? [Any] { return try array.map(value) }
        if let boxed = raw as? NSValue {
            let encoding = String(cString: boxed.objCType)
            var size = 0; NSGetSizeAndAlignment(boxed.objCType, &size, nil)
            var bytes = [UInt8](repeating: 0, count: size); boxed.getValue(&bytes, size: size)
            // Preserve all original bits, including less common CA structs.
            return ["encoding": encoding, "bytes_base64": Data(bytes).base64EncodedString()]
        }
        let cf = raw as CFTypeRef
        let typeID = CFGetTypeID(cf)
        let typeName = CFCopyTypeIDDescription(typeID) as String? ?? "unresolved"
        if typeID == CGImage.typeID || typeName.lowercased().contains("backingstore") {
            return ["opaque_reference": ["cf_type_id": typeID, "runtime_class": String(reflecting: type(of: raw)),
                "address": String(format: "0x%llx", UInt64(UInt(bitPattern: Unmanaged.passUnretained(cf).toOpaque()))),
                "reason": "pixel_backing_not_captured"]]
        }
        if CFGetTypeID(cf) == CGColor.typeID {
            let color = raw as! CGColor
            return ["type": "CGColor", "components": color.components?.map(Double.init) as Any? ?? NSNull(),
                "color_space": color.colorSpace?.name as Any? ?? NSNull()]
        }
        if CFGetTypeID(cf) == CGPath.typeID {
            let path = raw as! CGPath; var elements: [[String: Any]] = []
            path.applyWithBlock { element in
                let e = element.pointee
                let count = [1,1,2,3,0][Int(e.type.rawValue)]
                elements.append(["type": e.type.rawValue, "points": (0..<count).map { [Double(e.points[$0].x), Double(e.points[$0].y)] }])
            }
            return ["type": "CGPath", "elements": elements]
        }
        throw AnimationProbeError.unsupportedValue("\(String(reflecting: type(of: raw))) CFTypeID=\(typeID) type=\(typeName)")
    }
    private static func frame(_ address: NSNumber) -> [String: Any] {
        var info = Dl_info()
        let pointer = UnsafeRawPointer(bitPattern: address.uintValue)
        let resolved = dladdr(pointer, &info) != 0
        let base = info.dli_fbase.map { UInt(bitPattern: $0) }
        return ["address": String(format: "0x%llx", address.uint64Value),
            "image": resolved ? info.dli_fname.map { String(cString: $0) } as Any? ?? NSNull() : NSNull(),
            "image_uuid": info.dli_fbase.flatMap(uuid) as Any? ?? NSNull(),
            "image_base": base.map { String(format: "0x%llx", UInt64($0)) } as Any? ?? NSNull(),
            "image_offset": base.map { address.uint64Value - UInt64($0) } as Any? ?? NSNull(),
            "symbol": info.dli_sname.map { String(cString: $0) } as Any? ?? NSNull(),
            "symbol_address": info.dli_saddr.map { String(format: "0x%llx", UInt64(UInt(bitPattern: $0))) } as Any? ?? NSNull()]
    }
    private static func uuid(_ base: UnsafeMutableRawPointer) -> String? {
        let header = base.assumingMemoryBound(to: mach_header_64.self).pointee
        guard header.magic == MH_MAGIC_64 else { return nil }
        var cursor = UnsafeRawPointer(base).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<header.ncmds {
            let command = cursor.assumingMemoryBound(to: load_command.self).pointee
            if command.cmd == LC_UUID {
                let id = cursor.assumingMemoryBound(to: uuid_command.self).pointee.uuid
                return UUID(uuid: id).uuidString
            }
            cursor = cursor.advanced(by: Int(command.cmdsize))
        }
        return nil
    }
}

extension CALayer {
    @objc fileprivate func motionProbeAdd(_ animation: CAAnimation, forKey key: String?) {
        AnimationProbe.capture(self, animation, key)
        // After swizzling, this selector is the original implementation.
        motionProbeAdd(animation, forKey: key)
    }
}
