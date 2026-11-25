import XCTest
@testable import OpenUsage

/// Covers the "No data" state: a placed tile whose provider snapshot has no line matching the
/// descriptor's metric label must report `hasData == false`, render the exact "—"/"No data" copy,
/// and never leak its placeholder sample numbers into the menu bar.
@MainActor
final class WidgetNoDataTests: XCTestCase {
    func testMissingLineShowsNoDataAcrossDashboardAndMenuBar() async {
        let (store, present, missing) = await makeRefreshedStore()

        let blank = store.data(for: missing)
        XCTAssertFalse(blank.hasData)
        XCTAssertEqual(blank.headline, "—")
        XCTAssertEqual(blank.boundedTrailingText(), "No data")
        XCTAssertEqual(blank.valueText, WidgetData.noDataHeadline)

        let real = store.data(for: present)
        XCTAssertTrue(real.hasData)
        XCTAssertNotEqual(real.headline, "—")
        XCTAssertNotEqual(real.boundedTrailingText(), "No data")
        XCTAssertNotEqual(real.valueText, WidgetData.noDataHeadline)
    }

    func testUnavailableReasonsDistinguishNotOnPlanAndLoadFailure() async {
        let provider = Provider(id: "test", displayName: "Test", icon: .providerMark("cursor"))
        let noDataRow = boundedPercent(provider, id: "test.empty", metric: "Empty", sampleUsed: 50)
        let notOnPlanRow = boundedPercent(provider, id: "test.plan", metric: "PlanOnly", sampleUsed: 50)
        let failedRow = WidgetDescriptor(
            id: "test.failed",
            providerID: provider.id,
            metricLabel: "History",
            sample: WidgetData(title: "History", icon: provider.icon, kind: .dollars, used: 10, limit: nil)
        )
        let runtime = TestProviderRuntime(
            provider: provider,
            descriptors: [noDataRow, notOnPlanRow, failedRow],
            snapshot: ProviderSnapshot(
                providerID: provider.id,
                displayName: provider.displayName,
                lines: [],
                unavailableMetrics: [
                    "PlanOnly": .notApplicable,
                    "History": .loadFailed
                ]
            )
        )
        let defaults = makeUserDefaults("unavailable-reasons")
        let store = WidgetDataStore(
            registry: WidgetRegistry(providers: [provider], descriptors: [noDataRow, notOnPlanRow, failedRow]),
            providers: [runtime],
            cache: ProviderSnapshotCache(userDefaults: defaults, storageKey: "snapshots", ttl: 600, now: { Date() }),
            defaults: defaults
        )
        await store.refreshAll()

        let plain = store.data(for: noDataRow)
        XCTAssertEqual(plain.boundedTrailingText(), "No data")
        XCTAssertFalse(plain.isLoadFailed)
        XCTAssertEqual(plain.menuBarValue, "—")

        let notOnPlan = store.data(for: notOnPlanRow)
        XCTAssertEqual(notOnPlan.boundedTrailingText(), "Not on plan")
        XCTAssertFalse(notOnPlan.isLoadFailed)
        XCTAssertEqual(notOnPlan.menuBarValue, "—")

        let failed = store.data(for: failedRow)
        XCTAssertEqual(failed.unboundedDetail, "Couldn't load")
        XCTAssertTrue(failed.isLoadFailed)
        XCTAssertEqual(failed.menuBarValue, "—")
    }

    // Menu-bar ordering / no-data-skip / fallback are exercised on the real tray path
    // (MenuBarContentBuilder + LayoutStore.pinnedGroups) in MenuBarContentTests and MenuBarPinTests.

    // MARK: - Helpers

    private func makeRefreshedStore() async -> (WidgetDataStore, WidgetDescriptor, WidgetDescriptor) {
        let provider = Provider(id: "test", displayName: "Test", icon: .providerMark("cursor"))
        let present = boundedPercent(provider, id: "test.present", metric: "Present", sampleUsed: 40)
        // Deliberately fake sample numbers we must never show once the account lacks this metric.
        let missing = boundedPercent(provider, id: "test.missing", metric: "Missing", sampleUsed: 99)
        let runtime = TestProviderRuntime(
            provider: provider,
            descriptors: [present, missing],
            snapshot: ProviderSnapshot(
                providerID: provider.id,
                displayName: provider.displayName,
                lines: [.progress(label: "Present", used: 40, limit: 100, format: .percent)]
            )
        )
        let defaults = makeUserDefaults("missing-line")
        let store = WidgetDataStore(
            registry: WidgetRegistry(providers: [provider], descriptors: [present, missing]),
            providers: [runtime],
            cache: ProviderSnapshotCache(userDefaults: defaults, storageKey: "snapshots", ttl: 600, now: { Date() }),
            defaults: defaults
        )
        await store.refreshAll()
        return (store, present, missing)
    }

    private func boundedPercent(
        _ provider: Provider,
        id: String,
        metric: String,
        sampleUsed: Double
    ) -> WidgetDescriptor {
        WidgetDescriptor(
            id: id,
            providerID: provider.id,
            metricLabel: metric,
            sample: WidgetData(
                title: metric,
                icon: provider.icon,
                kind: .percent,
                used: sampleUsed,
                limit: 100
            )
        )
    }

    private func makeUserDefaults(_ name: String) -> UserDefaults {
        let suiteName = "OpenUsageTests.NoData.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
