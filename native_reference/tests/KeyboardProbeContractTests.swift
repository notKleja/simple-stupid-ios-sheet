import Foundation
import CoreGraphics

@main struct KeyboardProbeContractTests {
    static func main() {
        let r = KeyboardObservation.make(frame: CGRect(x: 0, y: 600, width: 400, height: 200),
            viewport: CGRect(x: 0, y: 0, width: 400, height: 800), duration: 0.25,
            curve: 7, timestamp: 1, focused: true)
        precondition(r["inset"] as? Double == 200, "overlap must exclude any extra safe area")
        precondition(r["interactive_phase"] as? String == "unavailable", "notifications cannot prove trajectory")
        precondition(r["focus"] as? String == "focused")
        for frame: CGRect? in [nil, CGRect(x: 0, y: 0, width: -1, height: 2)] {
            let v = KeyboardObservation.make(frame: frame, viewport: .zero, duration: nil, curve: nil, timestamp: 1, focused: nil)
            precondition(v["inset"] is NSNull)
            precondition(v["focus"] as? String == "unavailable")
        }
        let zero = KeyboardObservation.make(frame: CGRect(x: 0, y: 800, width: 400, height: 200), viewport: CGRect(x: 0, y: 0, width: 400, height: 800), duration: 0, curve: 0, timestamp: 2, focused: false)
        precondition(zero["inset"] as? Double == 0)
        precondition(zero["keyboard_presence"] as? String == "unavailable", "zero is not hardware keyboard proof")
        for duration in [Double.nan, -1] {
            let v = KeyboardObservation.make(frame: nil, viewport: .zero, duration: duration, curve: -1, timestamp: .nan, focused: nil)
            precondition(v["duration"] is NSNull && v["timestamp"] is NSNull && v["curve"] is NSNull)
        }
        print("PASS KeyboardProbeContractTests: overlap, unknown, zero, focus, malformed timing, interactive limits")
    }
}
