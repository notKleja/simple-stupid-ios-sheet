import Foundation

@main struct NativeContractTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let trace = Trace(scenario: "test", directory: directory, clock: { 1 })
        trace.record("session", ["native_contract_version": 2])
        trace.record("frame", ["metrics": ["finger.y": NSNull()], "state": ["scroll_owner": NSNull()]])
        trace.record("event", ["name": "bad", "data": ["value": Double.nan]])
        trace.record("event", ["name": "must_not_follow_error", "data": [:]])
        let rows = try String(contentsOf: trace.path, encoding: .utf8).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
        precondition(rows.count == 3, "Serialization failure must persist exactly one terminal error, then stop")
        precondition(rows.last?["name"] as? String == "run.error")
        precondition(rows.last?["seq"] as? Int == 2, "Failed observation must not create a sequence hole")
        precondition(rows.last?["terminal"] as? Bool == true)
        let reasons = rows[1]["unavailable"] as! [String: String]
        precondition(reasons["finger.y"] != nil && reasons["scroll_owner"] != nil)
        precondition(trace.invalidated)
        precondition(canonicalDetentID("com.apple.UIKit.medium") == "medium")
        precondition(canonicalDetentID("com.apple.UIKit.large") == "large")
        precondition(canonicalDetentID("fixed320") == "fixed320")
        precondition(canonicalDetentID(nil) == nil)
        let page = try NativeScenario.resolve("native.medium_large.programmatic", major: 26)
        let config = page.configuration(trial: 1, detents: ["fixed320", "medium", "large"])
        let required = ["trial", "detents", "surface", "grabber", "page_sizing", "modal_in_presentation", "largest_undimmed", "presentation_style", "preferred_content_size", "placement", "edge_attached_in_compact_height", "width_follows_preferred_content_size", "scroll_expansion"]
        precondition(Set(required) == Set(config.keys), "Serialize complete effective scenario configuration")
        precondition((try? NativeScenario.resolve("native.geometry.smoke", major:26))?.id == "native.geometry.smoke", "Explicit diagnostic geometry smoke definition missing")
        do { _ = try NativeScenario.resolve("native.typo.scroll", major: 27); fatalError("Unknown scenario silently accepted") } catch {}
        do { _ = try NativeScenario.resolve("native.form.placement.leading", major: 26); fatalError("Unavailable placement silently accepted") } catch {}
        print("Native contract checks PASS: serialization terminal/sequence, null reasons, canonical IDs, scenario validation/configuration")
    }
}
