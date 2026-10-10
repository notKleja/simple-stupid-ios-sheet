import Foundation
import CoreGraphics

/// Public environment facts. Configuration and resolution are intentionally
/// separate: neither a loaded window nor a configured value proves adaptation.
enum EnvironmentObservation {
    struct SafeArea { let top: Double; let left: Double; let bottom: Double; let right: Double }
    struct Identity {
        let osBuild: String?; let deviceModel: String?; let runtimeKind: String?
        let orientation: String; let horizontalSizeClass: String; let verticalSizeClass: String
    }
    struct Configuration {
        let presentationStyle: String; let preferredContentSize: CGSize?
        let edgeAttachedInCompactHeight: Bool?; let widthFollowsPreferredContentSize: Bool?; let sourceAnchor: CGRect?
    }
    struct Resolution {
        let presentationStyle: String; let preferredContentSize: CGSize; let sourceAnchor: CGRect
        let placement: String; let source: String
    }

    static func make(observationID: String, identity: Identity, safeArea: SafeArea?, configured: Configuration,
                     resolved: Resolution?, evidenceKind: String = "fixture") -> [String: Any] {
        let validConfiguredSize = configured.preferredContentSize.flatMap(validSize)
        let validConfiguredAnchor = configured.sourceAnchor.flatMap(validRect)
        let validResolved = resolved.flatMap { value -> [String: Any]? in
            guard let size = validSize(value.preferredContentSize), let anchor = validRect(value.sourceAnchor),
                  (value.presentationStyle == "page" || value.presentationStyle == "form"),
                  supportedPlacements.contains(value.placement), value.source == "public_runtime_observation" else { return nil }
            return ["presentation_style": value.presentationStyle, "preferred_content_size": sizeDictionary(size),
                    "source_anchor": rectangle(anchor),
                    "placement": ["value": value.placement, "availability": "observed_supported"], "source": value.source]
        }
        return [
            "schema_version": 1, "evidence_kind": evidenceKind, "observation_id": observationID,
            "identity": ["os_build": identity.osBuild.map { $0 as Any } ?? NSNull(), "device_model": identity.deviceModel.map { $0 as Any } ?? NSNull(),
                         "runtime_kind": identity.runtimeKind.map { $0 as Any } ?? NSNull(), "orientation": identity.orientation,
                         "horizontal_size_class": identity.horizontalSizeClass, "vertical_size_class": identity.verticalSizeClass,
                         "safe_area": safeArea.map(safeAreaDictionary) ?? NSNull()],
            "configured": ["presentation_style": configured.presentationStyle,
                           "preferred_content_size": validConfiguredSize.map(sizeDictionary) ?? NSNull(),
                           "edge_attached_in_compact_height": configured.edgeAttachedInCompactHeight.map { $0 as Any } ?? NSNull(),
                           "width_follows_preferred_content_size": configured.widthFollowsPreferredContentSize.map { $0 as Any } ?? NSNull(),
                           "source_anchor": validConfiguredAnchor.map(rectangle) ?? NSNull()],
            "resolved": validResolved ?? NSNull(),
        ]
    }

    private static let supportedPlacements: Set<String> = ["top", "bottom", "leading", "trailing"]
    private static func validSize(_ value: CGSize) -> CGSize? { value.width.isFinite && value.height.isFinite && value.width >= 0 && value.height >= 0 ? value : nil }
    private static func validRect(_ value: CGRect) -> CGRect? { value.origin.x.isFinite && value.origin.y.isFinite && value.width.isFinite && value.height.isFinite && value.width >= 0 && value.height >= 0 ? value : nil }
    private static func safeAreaDictionary(_ value: SafeArea) -> [String: Double] { ["top": value.top, "left": value.left, "bottom": value.bottom, "right": value.right] }
    private static func sizeDictionary(_ value: CGSize) -> [String: Double] { ["width": value.width, "height": value.height] }
    private static func rectangle(_ value: CGRect) -> [String: Double] { ["x": value.origin.x, "y": value.origin.y, "width": value.width, "height": value.height] }
}

#if canImport(UIKit)
import UIKit

extension EnvironmentObservation {
    /// Generic UIKit APIs do not provide exact model/runtime/OS-build identity
    /// or a resolved adaptive sheet placement. Those values remain unavailable.
    @MainActor static func observe(presented controller: UIViewController) -> [String: Any] {
        let view = controller.viewIfLoaded
        let traits = controller.traitCollection
        let sheet = controller.sheetPresentationController
        let popover = controller.popoverPresentationController
        let anchor: CGRect? = {
            guard let source = popover?.sourceView else { return nil }
            return source.convert(popover?.sourceRect ?? .zero, to: view?.window)
        }()
        let safeArea: SafeArea? = view.flatMap { loaded in
            let inset = loaded.safeAreaInsets
            guard inset.top.isFinite, inset.left.isFinite, inset.bottom.isFinite, inset.right.isFinite else { return nil }
            return SafeArea(top: Double(inset.top), left: Double(inset.left), bottom: Double(inset.bottom), right: Double(inset.right))
        }
        return make(observationID: UUID().uuidString,
            identity: Identity(osBuild: nil, deviceModel: nil, runtimeKind: nil,
                               orientation: orientation(UIDevice.current.orientation),
                               horizontalSizeClass: sizeClass(traits.horizontalSizeClass), verticalSizeClass: sizeClass(traits.verticalSizeClass)),
            safeArea: safeArea,
            configured: Configuration(presentationStyle: presentationStyle(controller.modalPresentationStyle),
                                      preferredContentSize: controller.preferredContentSize,
                                      edgeAttachedInCompactHeight: sheet?.prefersEdgeAttachedInCompactHeight,
                                      widthFollowsPreferredContentSize: sheet?.widthFollowsPreferredContentSizeWhenEdgeAttached,
                                      sourceAnchor: anchor),
            resolved: nil, evidenceKind: "runtime_observation")
    }

    private static func sizeClass(_ value: UIUserInterfaceSizeClass) -> String { switch value { case .compact: return "compact"; case .regular: return "regular"; default: return "unavailable" } }
    private static func orientation(_ value: UIDeviceOrientation) -> String { switch value { case .portrait: return "portrait"; case .portraitUpsideDown: return "portrait_upside_down"; case .landscapeLeft, .landscapeRight: return "landscape"; default: return "unavailable" } }
    private static func presentationStyle(_ value: UIModalPresentationStyle) -> String { switch value { case .pageSheet: return "page"; case .formSheet: return "form"; default: return "unavailable" } }
}
#endif
