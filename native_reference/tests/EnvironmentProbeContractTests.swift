import Foundation
import CoreGraphics

@main struct EnvironmentProbeContractTests {
    static func main() {
        let observed = EnvironmentObservation.make(observationID: "swift-literal-1",
            identity: .init(osBuild: "iOS 27.0 (24A123)", deviceModel: "iPhone18,3", runtimeKind: "simulator",
                            orientation: "landscape", horizontalSizeClass: "compact", verticalSizeClass: "compact"),
            safeArea: .init(top: 0, left: 0, bottom: 21, right: 0),
            configured: .init(presentationStyle: "page", preferredContentSize: CGSize(width: 0, height: 0),
                              edgeAttachedInCompactHeight: false, widthFollowsPreferredContentSize: true,
                              sourceAnchor: CGRect(x: 12, y: 24, width: 48, height: 32)),
            resolved: .init(presentationStyle: "page", preferredContentSize: CGSize(width: 0, height: 0),
                            sourceAnchor: CGRect(x: 12, y: 24, width: 48, height: 32), placement: "bottom",
                            source: "public_runtime_observation"))
        precondition(observed["schema_version"] as? Int == 1)
        let serialized = try! JSONSerialization.data(withJSONObject: observed, options: [.sortedKeys])
        let json = try! JSONSerialization.jsonObject(with: serialized) as! [String: Any]
        precondition(Set(json.keys) == ["schema_version", "evidence_kind", "observation_id", "identity", "configured", "resolved"])
        precondition(json["observation_id"] as? String == "swift-literal-1")
        precondition(observed["identity"] as? [String: AnyHashable] == ["os_build": "iOS 27.0 (24A123)", "device_model": "iPhone18,3", "runtime_kind": "simulator", "orientation": "landscape", "horizontal_size_class": "compact", "vertical_size_class": "compact", "safe_area": ["top": 0, "left": 0, "bottom": 21, "right": 0]])
        precondition((observed["configured"] as? [String: Any])?["preferred_content_size"] as? [String: Double] == ["width": 0, "height": 0], "zero configured size is not missing")
        let resolved = observed["resolved"] as? [String: Any] ?? [:]
        precondition(resolved["source"] as? String == "public_runtime_observation")
        precondition(resolved["source_anchor"] as? [String: Double] == ["x": 12, "y": 24, "width": 48, "height": 32])
        precondition(JSONSerialization.isValidJSONObject(observed), "canonical observation must survive JSON serialization")

        let unavailable = EnvironmentObservation.make(observationID: "swift-unavailable-1",
            identity: .init(osBuild: nil, deviceModel: nil, runtimeKind: nil, orientation: "portrait",
                            horizontalSizeClass: "regular", verticalSizeClass: "regular"),
            safeArea: nil,
            configured: .init(presentationStyle: "form", preferredContentSize: CGSize(width: 99, height: 33),
                              edgeAttachedInCompactHeight: nil, widthFollowsPreferredContentSize: nil, sourceAnchor: nil),
            resolved: nil)
        let unavailableIdentity = unavailable["identity"] as? [String: Any] ?? [:]
        precondition(unavailableIdentity["os_build"] is NSNull && unavailableIdentity["device_model"] is NSNull && unavailableIdentity["runtime_kind"] is NSNull, "generic identity must fail closed")
        precondition(unavailableIdentity["safe_area"] is NSNull, "unloaded safe area is unavailable, never NaN")
        precondition((unavailable["configured"] as? [String: Any])?["preferred_content_size"] as? [String: Double] == ["width": 99, "height": 33], "configured preferred size stays configured")
        precondition(unavailable["resolved"] is NSNull, "incomplete resolution remains unavailable")
        print("PASS EnvironmentProbeContractTests: canonical JSON ID, exact identity, zero, unavailable, configured-resolved boundary")
    }
}
