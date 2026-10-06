import Foundation

/// The selected scene root owns whether reference URL replay may run.
enum NativeLaunchMode: String {
    case referenceHarness, swiftUI, synchronizedDemo

    func dispatchReferenceURL(_ url: URL, open: (URL) -> Void) {
        guard self == .referenceHarness else { return }
        open(url)
    }
}

func canonicalDetentID(_ raw: String?) -> String? {
    switch raw {
    case "com.apple.UIKit.medium": return "medium"
    case "com.apple.UIKit.large": return "large"
    default: return raw
    }
}

struct NativeScenario {
    let id: String
    var style = "page_sheet"
    var placement = "automatic"
    var initial = "medium"
    var manual = false
    var scrolling = false
    var keyboard = false
    var expandsOnScroll = true
    var undimmed = false
    var dismissalLocked = false
    var compactEdge = false
    var preferredWidth = false
    var minimumMajor = 26

    static let definitions: [String: NativeScenario] = {
        var result: [String: NativeScenario] = [:]
        func add(_ scenario: NativeScenario) { result[scenario.id] = scenario }
        add(NativeScenario(id: "native.medium_large.programmatic"))
        add(NativeScenario(id: "native.medium.basic", manual: true))
        add(NativeScenario(id: "native.large.basic", initial: "large", manual: true))
        add(NativeScenario(id: "native.custom.320", initial: "fixed320", manual: true))
        add(NativeScenario(id: "native.medium_large.drag", manual: true))
        add(NativeScenario(id: "native.nonmodal.medium", manual: true, undimmed: true))
        add(NativeScenario(id: "native.dismiss.disabled", manual: true, dismissalLocked: true))
        add(NativeScenario(id: "native.scroll.medium_large", manual: true, scrolling: true))
        add(NativeScenario(id: "native.scroll.content_first", manual: true, scrolling: true, expandsOnScroll: false))
        add(NativeScenario(id: "native.scroll.handoff.down", initial: "large", manual: true, scrolling: true))
        add(NativeScenario(id: "native.keyboard.medium", manual: true, keyboard: true))
        add(NativeScenario(id: "native.edge.width", compactEdge: true, preferredWidth: true))
        add(NativeScenario(id: "native.form", style: "form_sheet"))
        add(NativeScenario(id: "native.form.placement.leading", style: "form_sheet", placement: "leading", minimumMajor: 27))
        add(NativeScenario(id: "native.form.placement.trailing", style: "form_sheet", placement: "trailing", minimumMajor: 27))
        return result
    }()

    static func resolve(_ id: String, major: Int) throws -> NativeScenario {
        guard let scenario = definitions[id] else { throw ScenarioError.invalid("Unknown scenario ID: \(id)") }
        guard major >= scenario.minimumMajor else { throw ScenarioError.invalid("Scenario \(id) requires iOS \(scenario.minimumMajor)+") }
        return scenario
    }

    func configuration(trial: Int, detents: [String]) -> [String: Any] {
        ["trial": trial, "detents": detents, "surface": "opaque.white", "grabber": true,
         "page_sizing": style == "page_sheet", "modal_in_presentation": dismissalLocked,
         "largest_undimmed": undimmed ? "medium" : NSNull(), "presentation_style": style,
         "preferred_content_size": ["width": 320, "height": 320], "placement": placement,
         "edge_attached_in_compact_height": compactEdge, "width_follows_preferred_content_size": preferredWidth,
         "scroll_expansion": expandsOnScroll]
    }
}

enum ScenarioError: Error { case invalid(String) }
