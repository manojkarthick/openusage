import XCTest
@testable import OpenUsage

final class TelemetryLeftoverCleanupTests: XCTestCase {
    private var root: URL!
    private var bundleID: String!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TelemetryLeftoverCleanupTests-\(UUID().uuidString)", isDirectory: true)
        bundleID = "OpenUsageTests.TelemetryCleanup.\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removePersistentDomain(forName: bundleID + ".telemetry")
        try? FileManager.default.removeItem(at: root)
    }

    func testRemovesSuitePostHogStorageAndCrashReportsButKeepsOtherAppSupportFiles() throws {
        let fileManager = FileManager.default
        let appSupport = root.appendingPathComponent("Application Support", isDirectory: true)
        let caches = root.appendingPathComponent("Caches", isDirectory: true)
        let appFolder = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        let postHog = appFolder.appendingPathComponent("phc_testtoken", isDirectory: true)
        let unrelated = appFolder.appendingPathComponent("keep.json")
        let crashReports = caches
            .appendingPathComponent("com.plausiblelabs.crashreporter.data", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        try fileManager.createDirectory(at: postHog, withIntermediateDirectories: true)
        try Data("id".utf8).write(to: postHog.appendingPathComponent("posthog.anonymousId"))
        try Data("{}".utf8).write(to: unrelated)
        try fileManager.createDirectory(at: crashReports, withIntermediateDirectories: true)
        UserDefaults.standard.setPersistentDomain(["installID": "abc"], forName: bundleID + ".telemetry")

        TelemetryLeftoverCleanup.removeLeftovers(
            bundleID: bundleID, defaults: .standard, applicationSupport: appSupport, caches: caches
        )

        XCTAssertTrue(UserDefaults.standard.persistentDomain(forName: bundleID + ".telemetry")?.isEmpty ?? true)
        XCTAssertFalse(fileManager.fileExists(atPath: postHog.path))
        XCTAssertFalse(fileManager.fileExists(atPath: crashReports.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelated.path))
    }

    func testNothingToRemoveIsANoOp() {
        TelemetryLeftoverCleanup.removeLeftovers(
            bundleID: bundleID,
            defaults: .standard,
            applicationSupport: root.appendingPathComponent("Application Support"),
            caches: root.appendingPathComponent("Caches")
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
}
