import Foundation

struct SynchronizedDemoAction: Codable {
    let atMs: Int
    let type: String
    let detent: String?
    let offset: Double?

    enum CodingKeys: String, CodingKey {
        case atMs = "at_ms"
        case type, detent, offset
    }
}

struct SynchronizedDemoConfiguration: Codable {
    let detents: String?
    let content: String?
    let scrollExpansion: Bool?
    let largestUndimmed: String?
    let dismissalLocked: Bool?

    enum CodingKeys: String, CodingKey {
        case detents, content
        case scrollExpansion = "scroll_expansion"
        case largestUndimmed = "largest_undimmed"
        case dismissalLocked = "dismissal_locked"
    }
}

struct SynchronizedDemoScene: Codable {
    let id: String
    let language: String
    let direction: String
    let kind: String
    let startMs: Int
    let durationMs: Int
    let title: String
    let subtitle: String
    let configuration: SynchronizedDemoConfiguration?
    let actions: [SynchronizedDemoAction]

    var endMs: Int { startMs + durationMs }

    enum CodingKeys: String, CodingKey {
        case id, language, direction, kind, title, subtitle, configuration, actions
        case startMs = "start_ms"
        case durationMs = "duration_ms"
    }
}

struct SynchronizedScheduledAction {
    let absoluteMs: Int
    let scene: SynchronizedDemoScene
    let action: SynchronizedDemoAction
    var type: String { action.type }
}

struct SynchronizedDemoTimeline: Codable {
    let schemaVersion: Int
    let title: String
    let device: String
    let runtime: String
    let durationMs: Int
    let scenes: [SynchronizedDemoScene]

    enum CodingKeys: String, CodingKey {
        case title, device, runtime, scenes
        case schemaVersion = "schema_version"
        case durationMs = "duration_ms"
    }

    func scene(at elapsedMs: Int) -> SynchronizedDemoScene {
        if elapsedMs <= scenes[0].startMs { return scenes[0] }
        return scenes.last(where: { elapsedMs >= $0.startMs && elapsedMs < $0.endMs }) ?? scenes.last!
    }

    func actions(fromExclusive previousMs: Int, through currentMs: Int) -> [SynchronizedScheduledAction] {
        scenes.flatMap { scene in
            scene.actions.compactMap { action in
                let absolute = scene.startMs + action.atMs
                return absolute > previousMs && absolute <= currentMs
                    ? SynchronizedScheduledAction(absoluteMs: absolute, scene: scene, action: action)
                    : nil
            }
        }.sorted { $0.absoluteMs < $1.absoluteMs }
    }

    static func loadFromBundle() throws -> SynchronizedDemoTimeline {
        guard let url = Bundle.main.url(forResource: "synchronized_bilingual_demo", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

enum SynchronizedDemoPresentation {
    static func segmentItems(language: String) -> [String] {
        language == "ar" ? ["الثاني", "الأول"] : ["First", "Second"]
    }

    static func selectedSegment(language: String, toggleOn: Bool) -> Int {
        if language == "ar" { return toggleOn ? 0 : 1 }
        return toggleOn ? 1 : 0
    }

    static func switchOrder(language: String) -> [String] {
        language == "ar" ? ["switch", "label"] : ["label", "switch"]
    }

    static func syncMarkerVisible(elapsedMs: Int, durationMs: Int) -> Bool {
        (elapsedMs >= 0 && elapsedMs < 1000) || (elapsedMs >= durationMs - 1000 && elapsedMs < durationMs)
    }
}
