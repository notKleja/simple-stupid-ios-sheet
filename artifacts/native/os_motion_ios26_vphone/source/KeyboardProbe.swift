import Foundation
import CoreGraphics

/// A serialization-only observation from the public keyboard notification.
///
/// This deliberately does not install observers or decide a sheet-avoidance
/// policy. A notification describes one reported endpoint; it cannot establish
/// the path or outcome of an interactive keyboard dismissal.
enum KeyboardObservation {
    static func make(frame: CGRect?, viewport: CGRect, duration: Double?, curve: Int?, timestamp: Double, focused: Bool?) -> [String: Any] {
        let validViewport = finiteRect(viewport) && viewport.size.width >= 0 && viewport.size.height >= 0
        let validFrame = frame.flatMap { finiteRect($0) && $0.size.width >= 0 && $0.size.height >= 0 ? $0 : nil }
        let visibleFrame = validViewport ? validFrame : nil
        let overlap = visibleFrame.map { max(0, viewport.intersection($0).height) }

        return [
            "source": "public_notification",
            "timestamp": finiteNonnegative(timestamp) ?? NSNull(),
            "frame": visibleFrame.map(rect) ?? NSNull(),
            "duration": duration.flatMap(finiteNonnegative) ?? NSNull(),
            "curve": curve.flatMap { $0 >= 0 ? $0 : nil } ?? NSNull(),
            // This is the viewport intersection only. Safe-area handling is a
            // later policy decision and must not be added to this observation.
            "inset": overlap.map(Double.init) ?? NSNull(),
            "inset_basis": overlap == nil ? "unavailable" : "viewport_intersection_no_safe_area_addition",
            "keyboard_presence": overlap.map { $0 > 0 ? "software" : "unavailable" } ?? "unavailable",
            "focus": focused.map { $0 ? "focused" : "unfocused" } ?? "unavailable",
            "interactive_phase": "unavailable"
        ]
    }

    private static func finiteNonnegative(_ value: Double) -> Double? {
        value.isFinite && value >= 0 ? value : nil
    }

    private static func finiteRect(_ value: CGRect) -> Bool {
        value.origin.x.isFinite && value.origin.y.isFinite &&
        value.size.width.isFinite && value.size.height.isFinite
    }

    private static func rect(_ value: CGRect) -> [String: Double] {
        ["x": value.origin.x, "y": value.origin.y, "width": value.size.width, "height": value.size.height]
    }
}
