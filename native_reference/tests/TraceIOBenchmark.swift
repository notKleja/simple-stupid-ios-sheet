import Foundation

@main struct TraceIOBenchmark {
    static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let trace = Trace(scenario: "io-diagnostic", directory: dir)
        var events: [Double] = [], records: [Double] = []
        for i in 0..<20 {
            var start = ProcessInfo.processInfo.systemUptime
            trace.event("diagnostic", ["index": i])
            events.append((ProcessInfo.processInfo.systemUptime-start)*1000)
            start = ProcessInfo.processInfo.systemUptime
            trace.record("event", ["name":"diagnostic", "data":["index":i]])
            records.append((ProcessInfo.processInfo.systemUptime-start)*1000)
        }
        print(String(data: try JSONSerialization.data(withJSONObject: ["event_ms":events, "buffered_record_ms":records],options:[.sortedKeys]),encoding:.utf8)!)
    }
}
