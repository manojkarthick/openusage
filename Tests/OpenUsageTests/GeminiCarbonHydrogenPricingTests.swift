import XCTest
@testable import OpenUsage

final class GeminiCarbonHydrogenPricingTests: XCTestCase {
    private let pricing = ModelPricing(
        supplement: TestPricing.bundled.supplement,
        primary: PricingCatalog(),
        secondary: PricingCatalog()
    )

    func testBundledSupplementPricesCarbonIDsAndLabelsWithoutRemoteCatalogs() {
        let expected = ModelRates(
            inputPerMillion: 2, outputPerMillion: 10,
            cacheWritePerMillion: 2, cacheReadPerMillion: 0.1
        )
        assertPrices(variants(of: "carbon", label: "Carbon"), as: "gemini-4-carbon", at: expected)
    }

    func testBundledSupplementPricesHydrogenIDsLabelsAndTieredSubagentsWithoutRemoteCatalogs() {
        let expected = ModelRates(
            inputPerMillion: 1.5, outputPerMillion: 7.5,
            cacheWritePerMillion: 1.5, cacheReadPerMillion: 0.075
        )
        // Antigravity's subagent tier config names Hydrogen with `-tiered` before the effort.
        let tiered = [
            "gemini-4-hydrogen-tiered-high", "gemini-4-hydrogen-tiered-xhigh", "gemini-4-hydrogen-tiered"
        ]
        assertPrices(variants(of: "hydrogen", label: "Hydrogen") + tiered, as: "gemini-4-hydrogen", at: expected)
    }

    func testAntigravityNeonIDsAndLabelsUseBundledRates() {
        let expected = ModelRates(
            inputPerMillion: 3, outputPerMillion: 15,
            cacheWritePerMillion: 3, cacheReadPerMillion: 0.15
        )
        assertPrices(
            ["gemini-4-neon", "gemini-4-neon-medium", "gemini-4-neon-high",
             "Gemini 4 Neon (Medium)", "Gemini 4 Neon (High)"],
            as: "gemini-4-neon", at: expected
        )
    }

    func testCarbonAndHydrogenAliasesLeaveOtherVersionsAndUnrecognizedVariantsUnpriced() {
        for model in [
            "gemini-5-carbon", "gemini-4.1-carbon", "gemini-4-carbon-fast",
            "gemini-4-carbon-contributor", "Gemini 4 Carbon (Contributor)", "Gemini 5 Carbon (High)",
            "gemini-5-hydrogen", "gemini-4.1-hydrogen", "gemini-4-hydrogen-fast",
            "gemini-4-hydrogen-contributor", "gemini-4-hydrogen-contributor-high",
            "gemini-4-hydrogen-sonar", "gemini-4-hydrogen-high-tiered-high",
            "Gemini 4 Hydrogen (Contributor)", "Gemini 4 Hydrogen (Fast)", "Gemini 5 Hydrogen (High)"
        ] {
            XCTAssertNil(pricing.supplement.canonicalName(for: model), model)
            XCTAssertNil(pricing.resolve(model: model), model)
        }
    }

    func testCarbonAndHydrogenCostIncludesInputCacheWritesCacheReadsAndOutput() throws {
        let tokens = TokenBreakdown(input: 1_000_000, cacheWrite5m: 250_000, cacheRead: 200_000, output: 500_000)

        let carbon = try XCTUnwrap(pricing.estimatedCostDollars(model: "gemini-4-carbon-high", tokens: tokens))
        // $2 input + $0.50 cache writes + $0.02 cache reads + $5 output.
        XCTAssertEqual(carbon, 7.52, accuracy: 0.000_001)

        let hydrogen = try XCTUnwrap(pricing.estimatedCostDollars(model: "gemini-4-hydrogen-tiered-xhigh", tokens: tokens))
        // $1.50 input + $0.375 cache writes + $0.015 cache reads + $3.75 output.
        XCTAssertEqual(hydrogen, 5.64, accuracy: 0.000_001)
    }

    private func variants(of slug: String, label: String) -> [String] {
        let base = "gemini-4-\(slug)"
        let efforts = ["none", "n", "low", "medium", "high", "xhigh"]
        return [base, "\(base)-trial", "\(base)-preview"]
            + efforts.map { "\(base)-\($0)" }
            + ["\(base)-trial-high", "\(base)-high-trial", "\(base)-preview-high", "\(base)-xhigh-preview",
               "\(base)-high (Auto Balanced)"]
            + ["", " (None)", " (Low)", " (Medium)", " (High)", " (XHigh)", " (Trial)", " (Preview)", " (Auto Balanced)"]
                .map { "Gemini 4 \(label)\($0)" }
    }

    private func assertPrices(
        _ models: [String], as canonical: String, at expected: ModelRates,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for model in models {
            XCTAssertEqual(pricing.resolve(model: model), expected, model, file: file, line: line)
            XCTAssertEqual(pricing.supplement.canonicalName(for: model), canonical, model, file: file, line: line)
            XCTAssertEqual(pricing.familyName(for: model, stripping: ["-preview"]), canonical, model, file: file, line: line)
        }
    }
}
