import XCTest

final class NoteDadUITests: XCTestCase {
    private var storageURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storageURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("NoteDadUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let storageURL {
            try? FileManager.default.removeItem(at: storageURL)
        }
    }

    @MainActor
    func testInitialLaunchCreatesEditableNote() throws {
        let app = launchApp()

        let editor = app.textViews["note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText("# Başlık\nGövde")

        XCTAssertTrue(waitForFile(named: "Baslik.md"))
    }

    @MainActor
    func testCommandNCreatesNewNoteAndCommandPOpensPalette() throws {
        let app = launchApp()
        XCTAssertTrue(app.textViews["note-editor"].waitForExistence(timeout: 5))

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(waitForMinimumNoteCount(2))

        app.typeKey("p", modifierFlags: .command)
        XCTAssertTrue(app.textFields["command-palette-search"].waitForExistence(timeout: 2))
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NOTEDAD_STORAGE_PATH"] = storageURL.path
        app.launchEnvironment["NOTEDAD_RESET_DEFAULTS"] = "1"
        app.launch()
        return app
    }

    private func waitForFile(named fileName: String) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        let fileURL = storageURL.appendingPathComponent(fileName)

        while Date() < deadline {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return false
    }

    private func waitForMinimumNoteCount(_ count: Int) -> Bool {
        let deadline = Date().addingTimeInterval(3)

        while Date() < deadline {
            let files = (try? FileManager.default.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)) ?? []
            if files.filter({ ["md", "txt"].contains($0.pathExtension) }).count >= count {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return false
    }
}
