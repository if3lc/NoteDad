//
//  NoteDadUITestsLaunchTests.swift
//  NoteDadUITests
//
//  Created by ismail ihsan bülbül on 21.04.2026.
//

import XCTest

final class NoteDadUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        let storageURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("NoteDadLaunchUITests-\(UUID().uuidString)", isDirectory: true)
        app.launchEnvironment["NOTEDAD_STORAGE_PATH"] = storageURL.path
        app.launchEnvironment["NOTEDAD_RESET_DEFAULTS"] = "1"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
        try? FileManager.default.removeItem(at: storageURL)
    }
}
