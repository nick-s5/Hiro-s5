// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Carbon
@testable import OmniWM
import XCTest

final class SidedHyperBindingDetectorTests: XCTestCase {
    private func hyperBinding(id: String, side: ModifierSide) -> HotkeyBinding {
        let chord = KeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: KeySymbolMapper.hyperModifiers)
            .settingSide(side)
        return HotkeyBinding(id: id, command: .focusPrevious, binding: chord)
    }

    func testFiresForLeftSidedHyperBinding() {
        let issues = SidedHyperBindingDetector.issues(currentBindings: [hyperBinding(id: "a", side: .left)])
        XCTAssertEqual(issues.map(\.id), ["hotkey-sided-hyper:a"])
        XCTAssertTrue(issues.first?.message.contains("Left-side") ?? false)
    }

    func testFiresForRightSidedHyperBinding() {
        let issues = SidedHyperBindingDetector.issues(currentBindings: [hyperBinding(id: "b", side: .right)])
        XCTAssertEqual(issues.map(\.id), ["hotkey-sided-hyper:b"])
        XCTAssertTrue(issues.first?.message.contains("Right-side") ?? false)
    }

    func testIgnoresUnsidedHyperBinding() {
        let binding = HotkeyBinding(
            id: "c",
            command: .focusPrevious,
            binding: KeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: KeySymbolMapper.hyperModifiers)
        )
        XCTAssertTrue(SidedHyperBindingDetector.issues(currentBindings: [binding]).isEmpty)
    }

    func testIgnoresSidedNonHyperBinding() {
        let binding = HotkeyBinding(
            id: "d",
            command: .focusPrevious,
            binding: KeyBinding(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(shiftKey)).settingSide(.left)
        )
        XCTAssertTrue(SidedHyperBindingDetector.issues(currentBindings: [binding]).isEmpty)
    }
}
