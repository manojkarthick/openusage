import Foundation

/// Deletes what PostHog telemetry left on disk before it was removed from the app (issue #3). Nothing
/// reads this data any more; removing it means the app actually forgets the old anonymous IDs instead of
/// only no longer sending them.
///
/// Covers everything outside the app's own `UserDefaults` domain:
/// - the `<bundle id>.telemetry` defaults suite (install ID, opt-out choice, daily counters),
/// - PostHog SDK storage at `~/Library/Application Support/<bundle id>/phc_<token>/` (anonymous and
///   device IDs, cached flags and config, queued events),
/// - PLCrashReporter's folder at `~/Library/Caches/com.plausiblelabs.crashreporter.data/<bundle id>/`.
/// The two `PHG*` keys PostHog wrote into the main domain are dropped by settings migration v4.
///
/// Runs on every launch rather than behind a one-shot flag: once everything is gone each run is a
/// domain lookup plus two existence probes, and there's no flag to keep around. Delete this file once
/// installs from before the removal are no longer a concern.
enum TelemetryLeftoverCleanup {
    /// Live entry point. Parameters exist for tests only; an unbundled `swift run` has no bundle ID and
    /// never had PostHog storage, so it skips.
    static func removeLeftovers(
        bundleID: String? = Bundle.main.bundleIdentifier,
        defaults: UserDefaults = .standard,
        applicationSupport: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
        caches: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    ) {
        guard let bundleID, !bundleID.isEmpty else { return }

        let suite = bundleID + ".telemetry"
        // A removed domain reads back as `[:]`, not nil, so test for content.
        if defaults.persistentDomain(forName: suite)?.isEmpty == false {
            defaults.removePersistentDomain(forName: suite)
            AppLog.info(.lifecycle, "removed leftover telemetry defaults suite \(suite)")
        }

        let fileManager = FileManager.default
        let postHogParent = applicationSupport.appendingPathComponent(bundleID, isDirectory: true)
        // Missing folder is the common case; any other listing error is worth surfacing.
        if fileManager.fileExists(atPath: postHogParent.path) {
            do {
                for entry in try fileManager.contentsOfDirectory(atPath: postHogParent.path)
                where entry.hasPrefix("phc_") {
                    remove(postHogParent.appendingPathComponent(entry, isDirectory: true))
                }
            } catch {
                AppLog.error(.lifecycle, "couldn't list \(postHogParent.path) for PostHog leftovers: \(error.localizedDescription)")
            }
        }

        let crashReports = caches
            .appendingPathComponent("com.plausiblelabs.crashreporter.data", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        if fileManager.fileExists(atPath: crashReports.path) {
            remove(crashReports)
        }
    }

    private static func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            AppLog.info(.lifecycle, "removed leftover telemetry data at \(url.path)")
        } catch {
            AppLog.error(.lifecycle, "couldn't delete leftover telemetry data at \(url.path): \(error.localizedDescription) — will retry next launch")
        }
    }
}
