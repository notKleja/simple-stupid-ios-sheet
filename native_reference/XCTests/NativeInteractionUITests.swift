import XCTest
import Foundation

final class NativeInteractionUITests: XCTestCase {
    func launch(_ scenario: String, trial: Int, dynamicsRecipe: [String: Any]? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.notkleja.NativeSheetHarness")
        app.launchEnvironment = ["NATIVE_AUTORUN":"1", "NATIVE_SCENARIO":scenario, "NATIVE_TRIALS":"1",
            "NATIVE_TRIAL_OFFSET":String(trial-1), "NATIVE_ATTEMPT_ID":UUID().uuidString, "NATIVE_ROLE":"training",
            "NATIVE_SOURCE_REVISION":Bundle(for:NativeInteractionUITests.self).object(forInfoDictionaryKey:"NativeSourceRevision") as? String ?? "unresolved"]
        if let recipe = dynamicsRecipe {
            let data = try! JSONSerialization.data(withJSONObject: recipe, options: [.sortedKeys])
            app.launchEnvironment["NATIVE_DYNAMICS_RECIPE"] = String(decoding: data, as: UTF8.self)
        }
        if let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"],
           let plist = NSDictionary(contentsOfFile: root + "/System/Library/CoreServices/SystemVersion.plist"),
           let build = plist["ProductBuildVersion"] as? String { app.launchEnvironment["NATIVE_OS_BUILD"] = build }
        app.launch()
        XCTAssertTrue(app.buttons["probe.begin"].waitForExistence(timeout: 10))
        return app
    }

    func wait(_ seconds: Double) {
        let expectation = XCTestExpectation(description: "observable idle dwell")
        DispatchQueue.main.asyncAfter(deadline: .now()+seconds) { expectation.fulfill() }
        XCTWaiter().wait(for: [expectation], timeout: seconds+5)
    }

    func finish(_ app: XCUIApplication) {
        app.buttons["experiment.finish"].tap()
        let complete = app.staticTexts["interaction.status"]
        let predicate = NSPredicate(format: "label == %@", "Experiment complete")
        expectation(for: predicate, evaluatedWith: complete)
        waitForExpectations(timeout: 10)
        app.terminate()
    }

    func testNonmodalBackgroundControl() {
        for trial in 1...10 {
            let app = launch("native.nonmodal.medium", trial: trial)
            wait(1)
            let frame = app.buttons["background.control"].frame
            XCTAssertGreaterThan(frame.width, 0)
            let target = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:frame.midX,dy:frame.midY))
            for phase in 0..<3 {
                if phase == 1 { app.buttons["sheet.select.large"].tap(); wait(1) }
                if phase == 2 { app.buttons["sheet.select.medium"].tap(); wait(1) }
                app.buttons["probe.begin"].tap()
                target.tap()
                app.buttons["probe.end"].tap()
            }
            finish(app)
        }
    }

    func scroll(_ scenario: String) {
        for trial in 1...10 {
            let app = launch(scenario, trial: trial)
            wait(1)
            app.buttons["probe.begin"].tap()
            let view = app.scrollViews["sheet.scroll"]
            XCTAssertTrue(view.exists)
            let from = view.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.85))
            let to = view.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.5))
            from.press(forDuration:0.1, thenDragTo:to)
            wait(1)
            app.buttons["probe.end"].tap()
            finish(app)
        }
    }

    func testScrollExpandsFirst() { scroll("native.scroll.medium_large") }
    func testScrollContentFirst() { scroll("native.scroll.content_first") }

    /// Future replay helper, deliberately not a runtime test/cohort in Task4A.
    /// Coordinates and press/drag calls are requests. Only the app's passive
    /// window observer establishes delivered position/time/finite-difference velocity.
    /// Does not implement nested/pager fixtures, velocity thresholds or phase interrupts.
    func requestDynamicsPath(_ app: XCUIApplication, origin: String, diagonal: Bool,
                             downward: Bool, secondGesture: Bool) {
        XCTAssertTrue(["handle", "content"].contains(origin), "Origin has no native fixture")
        guard ["handle", "content"].contains(origin) else { return }
        app.buttons["probe.begin"].tap() // App schedules 100/200ms on one request clock.
        let sheet = app.scrollViews["sheet.scroll"]
        XCTAssertTrue(sheet.exists)
        let startY: CGFloat = origin == "handle" ? 0.03 : (downward ? 0.35 : 0.85)
        let endY: CGFloat = downward ? 0.95 : 0.15
        let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let to = sheet.coordinate(withNormalizedOffset: CGVector(dx: diagonal ? 0.8 : 0.5, dy: endY))
        from.press(forDuration: 0.1, thenDragTo: to)
        if secondGesture {
            // A second request is not proof that scroll top was reached.
            from.press(forDuration: 0.1, thenDragTo: to)
        }
        wait(0.5)
        app.buttons["probe.end"].tap()
    }

    func testDownwardScrollHandoff() {
        for trial in 1...10 {
            let app = launch("native.scroll.handoff.down", trial:trial)
            wait(1)
            app.buttons["scroll.set400"].tap()
            app.buttons["probe.begin"].tap()
            let view=app.scrollViews["sheet.scroll"]
            view.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.35)).press(forDuration:0.1,
                thenDragTo:view.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.95)))
            wait(1)
            app.buttons["probe.end"].tap()
            finish(app)
        }
    }
}
