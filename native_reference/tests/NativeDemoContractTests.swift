import Foundation

@main struct NativeDemoContractTests {
    static func main() throws {
        let path = CommandLine.arguments[1]
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let timeline = try JSONDecoder().decode(SynchronizedDemoTimeline.self, from: data)
        precondition(timeline.scenes.count == 11)
        precondition(Set(timeline.scenes.map(\.language)) == Set(["en", "ar"]))
        precondition(timeline.scene(at: 3999).id == "en.intro")
        precondition(timeline.scene(at: 4000).id == "en.page")
        precondition(timeline.scene(at: 41000).id == "ar.page")
        precondition(timeline.scene(at: 41000).direction == "rtl")
        let due = timeline.actions(fromExclusive: 41200, through: 43600)
        precondition(due.map(\.type) == ["present", "select"])
        precondition(timeline.scenes.last!.endMs == timeline.durationMs)
        precondition(SynchronizedDemoPresentation.segmentItems(language: "ar") == ["الثاني", "الأول"])
        precondition(SynchronizedDemoPresentation.selectedSegment(language: "ar", toggleOn: true) == 0)
        precondition(SynchronizedDemoPresentation.segmentItems(language: "en") == ["First", "Second"])
        precondition(SynchronizedDemoPresentation.selectedSegment(language: "en", toggleOn: true) == 1)
        print("Native synchronized demo contract PASS: 11 scenes, en/ar, absolute actions, RTL")
    }
}
