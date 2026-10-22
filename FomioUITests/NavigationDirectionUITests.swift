import XCTest
import UIKit

/// Native Back follows the interface direction even when the iOS language has the other direction:
/// chevron orientation (measured from screenshot pixels), Back position and label, tap Back with its return
/// anchor, and the interactive edge-swipe pop. Fixture content and fixture catalogs only.
@MainActor final class NavigationDirectionUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false; MainActor.assumeIsolated { XCUIDevice.shared.orientation = .portrait } }

    private func launch(_ arguments: [String], system: String, namespace: String = UUID().uuidString, keepPreferences: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", "--ui-testing"] + arguments + (keepPreferences ? ["--keep-preferences"] : [])
            + ["-AppleLanguages", "(\(system))", "-AppleLocale", system == "ar" ? "ar_SA" : "en_US"]
        app.launchEnvironment["FOMIO_UI_TEST_NAMESPACE"] = namespace
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    /// Me keeps its stack, so the Language screen may already be open from an earlier switch.
    private func chooseLanguage(_ app: XCUIApplication, me: String, code: String) {
        select(app, tab: me)
        let row = app.buttons["language-\(code)"]
        if !row.waitForExistence(timeout: 2) { app.buttons["me-language"].tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    }
    private var backButton: (XCUIApplication) -> XCUIElement { { $0.navigationBars.buttons["BackButton"].firstMatch } }

    /// Orientation of the dark chevron inside the Back button: a left chevron's vertex (middle rows) is left of its arms.
    private func chevronPointsLeft(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool? {
        let button = backButton(app)
        guard button.waitForExistence(timeout: 5) else { XCTFail("no Back button", file: file, line: line); return nil }
        let screenshot = XCUIScreen.main.screenshot().image
        guard let cg = screenshot.cgImage else { return nil }
        let scale = CGFloat(cg.width) / screenshot.size.width
        let frame = button.frame.insetBy(dx: button.frame.width * 0.15, dy: button.frame.height * 0.15)
        let rect = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale).integral
        guard let crop = cg.cropping(to: rect) else { return nil }
        let width = crop.width, height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        var points: [(x: Int, y: Int)] = []
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            let luminance = 0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2])
            if luminance < 90 { points.append((x, y)) }
        } }
        guard points.count > 20, let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(), maxY - minY > 6 else { XCTFail("chevron not found", file: file, line: line); return nil }
        let mid = Double(minY + maxY) / 2, half = Double(maxY - minY) / 2
        let middle = points.filter { abs(Double($0.y) - mid) < half * 0.2 }.map { Double($0.x) }
        let ends = points.filter { abs(Double($0.y) - mid) > half * 0.6 }.map { Double($0.x) }
        guard !middle.isEmpty, !ends.isEmpty else { return nil }
        return middle.reduce(0, +) / Double(middle.count) < ends.reduce(0, +) / Double(ends.count)
    }
    /// Opens the first discussion, checks Back, taps it, reopens, then pops with the edge swipe.
    private func verifyBack(_ app: XCUIApplication, rightToLeft: Bool, homeTitle: String, label: String, file: StaticString = #filePath, line: UInt = #line) {
        let topic = app.buttons["topic-4190"]
        XCTAssertTrue(topic.waitForExistence(timeout: 10), file: file, line: line)
        let anchor = topic.frame.minY
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5), file: file, line: line)
        let back = backButton(app)
        XCTAssertTrue(back.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(chevronPointsLeft(app, file: file, line: line), !rightToLeft, "Back chevron direction", file: file, line: line)
        let width = app.windows.firstMatch.frame.width
        if rightToLeft { XCTAssertGreaterThan(back.frame.midX, width / 2, "Back on the right", file: file, line: line) }
        else { XCTAssertLessThan(back.frame.midX, width / 2, "Back on the left", file: file, line: line) }
        XCTAssertEqual(back.label, homeTitle, "Back names the previous screen", file: file, line: line)
        capture(app, label + ": Back control")
        back.tap()
        XCTAssertTrue(topic.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertLessThan(abs(topic.frame.minY - anchor), 4, "tap Back returns to the same reading position", file: file, line: line)
        // Interactive pop from the leading edge of the interface direction.
        topic.tap()
        XCTAssertTrue(app.buttons["discussion-reply"].waitForExistence(timeout: 5), file: file, line: line)
        let window = app.windows.firstMatch, origin = window.coordinate(withNormalizedOffset: .zero)
        let y = window.frame.height * 0.55
        let start = origin.withOffset(CGVector(dx: rightToLeft ? width - 2 : 2, dy: y))
        let end = origin.withOffset(CGVector(dx: rightToLeft ? width * 0.15 : width * 0.85, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["discussion-reply"].waitForNonExistence(timeout: 5), "edge swipe pops the discussion", file: file, line: line)
        XCTAssertTrue(topic.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertLessThan(abs(topic.frame.minY - anchor), 4, "swipe Back returns to the same reading position", file: file, line: line)
        capture(app, label + ": after edge-swipe Back")
    }

    func testArabicSystemEnglishInterfaceColdLaunchAndSwitching() {
        // Mismatch 1 on a cold offline launch: Arabic iOS, bundled English interface.
        let app = launch(["--language", "en", "--l10n-offline", "--l10n-reset"], system: "ar")
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10))
        verifyBack(app, rightToLeft: false, homeTitle: "Home", label: "Arabic iOS, English (cold)")
        app.terminate()
        // Matched Arabic, then switching to English in the same session.
        let switching = launch(["--language", "ar"], system: "ar")
        XCTAssertTrue(tab(switching, "الصفحة الرئيسية").waitForExistence(timeout: 10))
        verifyBack(switching, rightToLeft: true, homeTitle: "الصفحة الرئيسية", label: "Arabic iOS, Arabic")
        chooseLanguage(switching, me: "أنا", code: "en")
        XCTAssertTrue(tab(switching, "Home").waitForExistence(timeout: 10)); select(switching, tab: "Home")
        verifyBack(switching, rightToLeft: false, homeTitle: "Home", label: "Arabic iOS, after Arabic → English")
    }

    func testEnglishSystemArabicInterfaceCachedColdLaunchAndSwitching() {
        // Mismatch 2 on a cold launch from the cached Arabic catalog (offline): English iOS, Arabic interface.
        let namespace = UUID().uuidString
        let first = launch(["--language", "ar"], system: "en", namespace: namespace)
        XCTAssertTrue(tab(first, "الصفحة الرئيسية").waitForExistence(timeout: 10))
        first.terminate()
        let app = launch(["--l10n-offline"], system: "en", namespace: namespace, keepPreferences: true)
        XCTAssertTrue(tab(app, "الصفحة الرئيسية").waitForExistence(timeout: 5))
        verifyBack(app, rightToLeft: true, homeTitle: "الصفحة الرئيسية", label: "English iOS, Arabic (cached cold launch)")
        // Switching to English (matched) and back to Arabic in the same session.
        chooseLanguage(app, me: "أنا", code: "en")
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 10)); select(app, tab: "Home")
        verifyBack(app, rightToLeft: false, homeTitle: "Home", label: "English iOS, English")
        chooseLanguage(app, me: "Me", code: "ar")
        XCTAssertTrue(tab(app, "الصفحة الرئيسية").waitForExistence(timeout: 10)); select(app, tab: "الصفحة الرئيسية")
        verifyBack(app, rightToLeft: true, homeTitle: "الصفحة الرئيسية", label: "English iOS, after English → Arabic")
    }
}
