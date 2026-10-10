import Foundation

@main struct AccessibilityProbeContractTests {
    static func main() {
        let settings = AccessibilityObservation.Settings(
            reduceMotion: true, contentSizeCategory: "UICTContentSizeCategoryAccessibilityL",
            localeIdentifier: "ar-SA", layoutDirection: "rtl")
        let delivered = AccessibilityObservation.make(
            observationID: "accessibility-swift-1", runID: "native-access-1", trial: 1,
            settings: settings, layerID: "sheet.layer.1", gestureID: "escape-1",
            dismissalLocked: false, escapeCallback: .init(layerID: "sheet.layer.1", gestureID: "escape-1", outcome: "dismissed"),
            dismissalCallback: .init(layerID: "sheet.layer.1", callback: "presentationControllerDidDismiss", delivered: true),
            focusCallback: .init(layerID: "sheet.layer.1", beforeID: "sheet.field", restoredID: "presenter.button"),
            barrierDismissLabel: "رفض", evidenceKind: "fixture")
        precondition(delivered["schema_version"] as? Int == 1)
        let access = ((delivered["conditions"] as? [String: Any])?["accessibility"] as? [String: Any]) ?? [:]
        precondition(access["reduce_motion_source"] as? String == "public_system_setting")
        precondition(access["content_size_source"] as? String == "public_trait_collection")
        precondition(access["layout_direction"] as? String == "rtl")
        let escape = delivered["escape"] as? [String: Any] ?? [:]
        precondition(escape["delivered"] as? Bool == true, "callback-bound escape must be delivered")
        precondition(escape["requested_gesture_id"] as? String == "escape-1")
        precondition(escape["delivered_gesture_id"] as? String == "escape-1")
        precondition((delivered["dismissal"] as? [String: Any])?["did_dismiss"] as? Bool == true)
        precondition((delivered["dismissal"] as? [String: Any])?["callback"] as? String == "presentationControllerDidDismiss")
        precondition((delivered["dismissal"] as? [String: Any])?["gesture_id"] as? String == "escape-1")
        precondition((delivered["focus"] as? [String: Any])?["restored"] as? Bool == true)
        precondition((delivered["semantic"] as? [String: Any])?["label_locale"] as? String == "ar-SA")
        let conditions = delivered["conditions"] as? [String: Any] ?? [:]
        precondition(conditions["os_build"] is NSNull && conditions["device_model"] is NSNull &&
                     conditions["runtime_kind"] is NSNull && conditions["orientation"] is NSNull,
                     "unavailable exact identity must fail closed in the canonical shape")
        let serialized = try! JSONSerialization.data(withJSONObject: delivered, options: [.sortedKeys])
        let json = try! JSONSerialization.jsonObject(with: serialized) as! [String: Any]
        precondition((json["conditions"] as? [String: Any])?["accessibility"] is [String: Any],
                     "canonical Swift record must survive JSON serialization")

        let unknownProvenance = AccessibilityObservation.make(
            observationID: "accessibility-swift-invalid", runID: "native-access-invalid", trial: 3,
            settings: settings, layerID: "sheet.layer.1", gestureID: "escape-invalid", dismissalLocked: false,
            escapeCallback: nil, dismissalCallback: nil, focusCallback: nil, barrierDismissLabel: "رفض", evidenceKind: "forged")
        precondition(unknownProvenance["evidence_kind"] as? String == "unavailable",
                     "unknown provenance must never be relabeled as fixture")

        let locked = AccessibilityObservation.make(
            observationID: "accessibility-swift-2", runID: "native-access-2", trial: 2,
            settings: settings, layerID: "sheet.layer.2", gestureID: "escape-2",
            dismissalLocked: true, escapeCallback: .init(layerID: "sheet.layer.2", gestureID: "escape-2", outcome: "blocked"),
            dismissalCallback: .init(layerID: "sheet.layer.2", callback: "presentationControllerShouldDismiss", delivered: false),
            focusCallback: .init(layerID: "sheet.layer.2", beforeID: "sheet.field", restoredID: "sheet.field"),
            barrierDismissLabel: "رفض", evidenceKind: "fixture")
        precondition((locked["escape"] as? [String: Any])?["delivered"] as? Bool == false)
        precondition((locked["dismissal"] as? [String: Any])?["did_dismiss"] as? Bool == false)
        precondition((locked["dismissal"] as? [String: Any])?["callback"] as? String == "presentationControllerShouldDismiss")
        precondition((locked["dismissal"] as? [String: Any])?["callback_result"] as? Bool == false)
        let allowedByCallback = AccessibilityObservation.make(
            observationID: "accessibility-swift-3", runID: "native-access-3", trial: 3,
            settings: settings, layerID: "sheet.layer.3", gestureID: "escape-3",
            dismissalLocked: true, escapeCallback: .init(layerID: "sheet.layer.3", gestureID: "escape-3", outcome: "blocked"),
            dismissalCallback: .init(layerID: "sheet.layer.3", callback: "presentationControllerShouldDismiss", delivered: true),
            focusCallback: .init(layerID: "sheet.layer.3", beforeID: "sheet.field", restoredID: "sheet.field"),
            barrierDismissLabel: "رفض", evidenceKind: "fixture")
        precondition((allowedByCallback["dismissal"] as? [String: Any])?["callback_result"] as? Bool == true,
                     "should-dismiss result must be serialized independently from did_dismiss")
        precondition((allowedByCallback["dismissal"] as? [String: Any])?["did_dismiss"] as? Bool == false)
        let lockedFocus = locked["focus"] as? [String: Any] ?? [:]
        precondition(lockedFocus["outcome"] as? String == "preserved")
        precondition(lockedFocus["restored"] as? Bool == false)
        print("PASS AccessibilityProbeContractTests: public settings, explicit callbacks, gesture binding, locks, focus, RTL semantics")
    }
}
