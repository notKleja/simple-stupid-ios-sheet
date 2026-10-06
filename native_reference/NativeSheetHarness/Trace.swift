import Foundation

/// One serial recorder clock; failed observations invalidate the entire run.
final class Trace {
    let id = UUID().uuidString
    let path: URL
    private let handle: FileHandle
    private let clock: () -> Double
    private var seq = 0
    private var lastTime: Int64 = 0
    private(set) var invalidated = false

    init(scenario: String, directory: URL? = nil, clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        let dir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeName = String(scenario.map { $0.isLetter || $0.isNumber || ".-_".contains($0) ? $0 : "_" })
        path = dir.appendingPathComponent("\(safeName)-\(id).jsonl")
        FileManager.default.createFile(atPath: path.path, contents: nil)
        handle = try! FileHandle(forWritingTo: path)
    }

    @discardableResult func record(_ type: String, _ fields: [String: Any], time: Double? = nil) -> Bool {
        guard !invalidated else { return false }
        let seconds = time ?? clock()
        guard seconds.isFinite && seconds >= 0 && seconds < Double(Int64.max) / 1e9 else {
            fail("invalid_clock", ["failed_record_type": type]); return false
        }
        var row = fields
        guard Int64(seconds * 1e9) >= lastTime else { fail("nonmonotonic_clock", ["failed_record_type": type]); return false }
        row.merge(["schema_version": 1, "type": type, "run_id": id, "seq": seq, "t_ns": Int64(seconds * 1e9)]) { _, new in new }
        if type == "session" { row["native_contract_version"] = 2 }
        if type == "frame" {
            var reasons = row["unavailable"] as? [String: String] ?? [:]
            for section in ["metrics", "state"] {
                for (key, value) in row[section] as? [String: Any] ?? [:] where value is NSNull {
                    if reasons[key]?.isEmpty != false { reasons[key] = "Native \(section) field unavailable at this observation" }
                }
            }
            row["unavailable"] = reasons
        }
        guard JSONSerialization.isValidJSONObject(row) else {
            fail("serialization_failed", ["failed_record_type": type]); return false
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
            try handle.write(contentsOf: data + Data([10]))
            lastTime = max(lastTime, Int64(seconds * 1e9)); seq += 1
            return true
        } catch {
            fail("write_failed", ["failed_record_type": type, "error": String(describing: error)]); return false
        }
    }

    func event(_ name: String, _ data: [String: Any] = [:], terminal: Bool = false) {
        let before = clock()
        record("event", ["name": name, "data": data, "terminal": terminal])
        let beforeSync = clock()
        try? handle.synchronize()
        if ProcessInfo.processInfo.environment["NATIVE_IO_AUDIT"] == "1" {
            record("event", ["name": "recorder.io", "data": ["for_event": name,
                "write_ms": (beforeSync-before)*1000, "sync_ms": (clock()-beforeSync)*1000]])
        }
    }

    func fail(_ code: String, _ data: [String: Any] = [:]) {
        guard !invalidated else { return }
        invalidated = true
        let row: [String: Any] = ["schema_version": 1, "type": "event", "run_id": id, "seq": seq,
            "t_ns": lastTime, "name": "run.error", "data": ["code": code, "details": data], "terminal": true, "run_status": "invalid"]
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) {
            do { try handle.write(contentsOf: data + Data([10])); try handle.synchronize(); seq += 1 } catch {
                // If storage itself fails, no completed/accepted trace can be emitted.
                fputs("Native trace storage failure: \(error)\n", stderr)
            }
        }
    }
}
