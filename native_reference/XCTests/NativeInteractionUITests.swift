import XCTest
import Foundation

final class NativeInteractionUITests: XCTestCase {
    func launch(_ scenario: String, trial: Int) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.notkleja.NativeSheetHarness")
        app.launchEnvironment = ["NATIVE_AUTORUN":"1", "NATIVE_SCENARIO":scenario, "NATIVE_TRIALS":"1",
            "NATIVE_TRIAL_OFFSET":String(trial-1), "NATIVE_ATTEMPT_ID":UUID().uuidString, "NATIVE_ROLE":"training"]
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
}
