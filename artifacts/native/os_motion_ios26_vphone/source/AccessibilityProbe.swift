import Foundation

/// Serialization boundary for accessibility observations. It deliberately
/// records a callback outcome rather than promoting an accessibility request
/// into a dismissal result.
enum AccessibilityObservation {
    struct Identity {
        let osBuild: String?
        let deviceModel: String?
        let runtimeKind: String?
        let orientation: String?

        static let unavailable = Identity(osBuild: nil, deviceModel: nil, runtimeKind: nil, orientation: nil)
    }

    struct Settings {
        let reduceMotion: Bool
        let contentSizeCategory: String
        let localeIdentifier: String
        let layoutDirection: String
    }

    struct EscapeCallback {
        let layerID: String
        let gestureID: String
        /// Accepted values are the callback's result, never the request.
        let outcome: String
    }

    struct DismissalCallback {
        let layerID: String
        /// The actual public presentation-controller callback that fired.
        let callback: String
        /// Its delivered boolean result, never inferred from configuration.
        let delivered: Bool
    }

    struct FocusCallback {
        let layerID: String
        let beforeID: String
        let restoredID: String
    }

    static func make(observationID: String, runID: String, trial: Int, settings: Settings,
                     layerID: String, gestureID: String, dismissalLocked: Bool,
                     escapeCallback: EscapeCallback?, dismissalCallback: DismissalCallback?,
                     focusCallback: FocusCallback?, barrierDismissLabel: String,
                     evidenceKind: String = "runtime_observation", identity: Identity = .unavailable) -> [String: Any] {
        let callback: Any = escapeCallback.map { value -> Any in
            ["callback": "accessibilityPerformEscape", "layer_id": value.layerID,
             "gesture_id": value.gestureID, "outcome": value.outcome]
        } ?? NSNull()
        let escapeDelivered = !dismissalLocked && escapeCallback?.outcome == "dismissed" &&
            escapeCallback?.layerID == layerID && escapeCallback?.gestureID == gestureID
        let dismissalDelivered = !dismissalLocked && dismissalCallback?.callback == "presentationControllerDidDismiss" &&
            dismissalCallback?.delivered == true && dismissalCallback?.layerID == layerID
        let validFocusCallback = focusCallback?.layerID == layerID &&
            nonempty(focusCallback?.beforeID) && nonempty(focusCallback?.restoredID)
        let focusOutcome: String = {
            if dismissalLocked && validFocusCallback && focusCallback?.beforeID == focusCallback?.restoredID { return "preserved" }
            if !dismissalLocked && validFocusCallback && focusCallback?.beforeID != focusCallback?.restoredID { return "restored" }
            return "unavailable"
        }()
        let normalizedKind = evidenceKind == "fixture" || evidenceKind == "runtime_observation" ? evidenceKind : "unavailable"

        return [
            "schema_version": 1, "evidence_kind": normalizedKind,
            "observation_id": observationID, "run_id": runID, "trial": trial, "layer_id": layerID,
            "conditions": [
                "os_build": identity.osBuild.map { $0 as Any } ?? NSNull(),
                "device_model": identity.deviceModel.map { $0 as Any } ?? NSNull(),
                "runtime_kind": identity.runtimeKind.map { $0 as Any } ?? NSNull(),
                "orientation": identity.orientation.map { $0 as Any } ?? NSNull(),
                "accessibility": [
                    "reduce_motion": settings.reduceMotion,
                    "reduce_motion_source": "public_system_setting",
                    "content_size_category": settings.contentSizeCategory,
                    "content_size_source": "public_trait_collection",
                    "locale_identifier": settings.localeIdentifier,
                    "layout_direction": settings.layoutDirection,
                    "locale_source": "public_locale",
                ],
                "configuration": ["modal_in_presentation": dismissalLocked],
            ],
            "escape": ["requested": true, "requested_gesture_id": gestureID, "callback": callback,
                       "delivered": escapeDelivered,
                       "delivered_gesture_id": escapeCallback?.gestureID as Any? ?? NSNull()],
            "dismissal": ["locked": dismissalLocked as Any,
                          "callback": dismissalCallback?.callback as Any? ?? NSNull(),
                          "callback_result": dismissalCallback?.delivered as Any? ?? NSNull(),
                          "layer_id": dismissalCallback?.layerID as Any? ?? NSNull(),
                          "observation_id": observationID, "gesture_id": gestureID,
                          "did_dismiss": dismissalDelivered],
            "focus": ["callback": focusCallback == nil ? NSNull() : "accessibility_focus_callback",
                      "layer_id": focusCallback?.layerID as Any? ?? NSNull(),
                      "observation_id": observationID, "gesture_id": gestureID,
                      "before_id": focusCallback?.beforeID as Any? ?? NSNull(),
                      "restored_id": focusCallback?.restoredID as Any? ?? NSNull(),
                      "restored": focusOutcome == "restored", "outcome": focusOutcome],
            "semantic": ["barrier_dismiss_label": barrierDismissLabel,
                         "label_locale": settings.localeIdentifier,
                         "source": "public_localized_string"],
        ]
    }

    private static func nonempty(_ value: String?) -> Bool { value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
}

#if canImport(UIKit)
import UIKit

extension AccessibilityObservation {
    /// Reads public system and trait APIs at observation time. Launch arguments
    /// are intentionally not an input to this function.
    @MainActor static func publicSettings(for controller: UIViewController) -> Settings {
        Settings(reduceMotion: UIAccessibility.isReduceMotionEnabled,
                 contentSizeCategory: controller.traitCollection.preferredContentSizeCategory.rawValue,
                 localeIdentifier: Locale.current.identifier,
                 layoutDirection: controller.traitCollection.layoutDirection == .rightToLeft ? "rtl" : "ltr")
    }
}
#endif
