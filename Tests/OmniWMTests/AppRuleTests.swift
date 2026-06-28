// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

@testable import OmniWM
import XCTest

final class AppRuleTests: XCTestCase {
    func testNormalizeSingleTitleDropsSubstringWhenBothSet() {
        let rule = AppRule(
            bundleId: "com.test.app",
            titleSubstring: "Main",
            titleRegex: "^Main$",
            layout: .float
        )
        XCTAssertNil(rule.titleSubstring)
        XCTAssertEqual(rule.titleRegex, "^Main$")
    }

    func testNormalizeKeepsLoneTitleMatchers() {
        let substring = AppRule(bundleId: "a", titleSubstring: "Main", layout: .float)
        XCTAssertEqual(substring.titleSubstring, "Main")
        XCTAssertNil(substring.titleRegex)

        let regex = AppRule(bundleId: "a", titleRegex: "^Main$", layout: .float)
        XCTAssertNil(regex.titleSubstring)
        XCTAssertEqual(regex.titleRegex, "^Main$")
    }

    func testNormalizeSingleTitleAppliesOnDecode() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","bundleId":"com.test.app",\
        "titleSubstring":"Main","titleRegex":"^Main$","layout":"float"}
        """
        let rule = try JSONDecoder().decode(AppRule.self, from: Data(json.utf8))
        XCTAssertNil(rule.titleSubstring)
        XCTAssertEqual(rule.titleRegex, "^Main$")
    }

    func testHasEffect() {
        XCTAssertFalse(AppRule(bundleId: "com.test.app").hasEffect)
        XCTAssertFalse(AppRule(bundleId: "com.test.app", appNameSubstring: "Test").hasEffect)
        XCTAssertTrue(AppRule(bundleId: "com.test.app", layout: .float).hasEffect)
        XCTAssertTrue(AppRule(bundleId: "com.test.app", assignToWorkspace: "2").hasEffect)
        XCTAssertTrue(AppRule(bundleId: "com.test.app", minWidth: 400).hasEffect)
        XCTAssertTrue(AppRule(bundleId: "com.test.app", minHeight: 300).hasEffect)
    }
}
