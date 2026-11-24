import XCTest
@testable import OpenUsage

/// Pro's separate Argon quota was retired 2026-11-23; Argon now draws from the shared Gemini pool.
final class AntigravityArgonQuotaTests: XCTestCase {
    func testRetiredArgonGroupNoLongerYieldsAMeter() {
        let data = Data("""
        {"groups":[
          {"displayName":"Gemini 4 Argon","buckets":[
            {"bucketId":"gemini-argon-wtu-weekly","window":"weekly","remainingFraction":0.1}
          ]},
          {"displayName":"Gemini Models","buckets":[
            {"bucketId":"gemini-5h","remainingFraction":0.8},
            {"bucketId":"gemini-weekly","remainingFraction":0.7}
          ]},
          {"displayName":"Claude and GPT models","buckets":[
            {"bucketId":"3p-5h","remainingFraction":0.6},
            {"bucketId":"3p-weekly","remainingFraction":0.5}
          ]}
        ]}
        """.utf8)
        let lines = AntigravityUsageMapper.parseQuotaSummary(data)
        XCTAssertEqual(lines?.map(\.label), ["Session", "Weekly", "Claude", "Claude Weekly"])
        let used = lines?.compactMap { metric -> Double? in
            guard case .progress(_, let used, _, _, _, _, _) = metric else { return nil }
            return used
        }
        for (actual, expected) in zip(used ?? [], [20.0, 30, 40, 50]) {
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
    }

    func testLegacyArgonModelsNeverJoinTheSharedSessionEvenWithNumericQuota() {
        // Legacy endpoints can report Argon with empty quotaInfo, which pooling would read as depleted.
        let json = """
        {"models":{
          "argon":{"model":"MODEL_PLACEHOLDER_M421","displayName":"Gemini 4 Argon","quotaInfo":{}},
          "argon-low":{"model":"gemini-4-argon-low","displayName":"Gemini 4 Argon (Low)","quotaInfo":{"remainingFraction":0.1}},
          "flash":{"displayName":"Gemini 3.8 Flash (High)","quotaInfo":{"remainingFraction":0.8}}
        }}
        """
        let lines = AntigravityUsageMapper.buildLines(AntigravityUsageMapper.parseCloudCodeModels(Data(json.utf8)))
        XCTAssertEqual(lines.map(\.label), ["Session"])
        if case .progress(_, let used, let limit, let format, let resetsAt, let periodMs, _)? = lines.first {
            XCTAssertEqual(used, 20, accuracy: 0.0001)
            XCTAssertEqual(limit, 100)
            XCTAssertEqual(format, .percent)
            XCTAssertNil(resetsAt)
            XCTAssertEqual(periodMs, MetricPeriod.sessionMs)
        } else {
            XCTFail("expected Session progress line")
        }

        let buckets = Data(#"{"buckets":[{"modelId":"gemini-4-argon","remainingFraction":0.1},{"modelId":"gemini-3.8-flash","remainingFraction":0.8}]}"#.utf8)
        XCTAssertEqual(AntigravityUsageMapper.buildLines(AntigravityUsageMapper.parseQuotaBuckets(buckets)), lines)
    }
}
