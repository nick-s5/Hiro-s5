// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

enum HotkeyAdvisoryDetector {
    private struct Advisory {
        let actionID: String
        let command: HotkeyCommand
        let text: String
    }

    private static let knownSystemConflicts: [Advisory] = [
        Advisory(
            actionID: "openCommandPalette",
            command: .openCommandPalette,
            text: "The Command Palette shortcut (Control+Option+Space) is also the macOS "
                + "“Select the previous input source” shortcut, so both can fire together. If pressing it "
                + "switches your keyboard input source, reassign this hotkey or clear the macOS shortcut in "
                + "System Settings → Keyboard → Keyboard Shortcuts → Input Sources."
        )
    ]

    static func issues(currentBindings: [HotkeyBinding], defaults: [HotkeyBinding]) -> [DiagnosticsIssue] {
        guard !knownSystemConflicts.isEmpty, !currentBindings.isEmpty else { return [] }
        let currentByID = Dictionary(currentBindings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let defaultsByID = Dictionary(defaults.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return knownSystemConflicts
            .sorted { $0.command.displayName < $1.command.displayName }
            .compactMap { advisory in
                guard let current = currentByID[advisory.actionID],
                      let defaultBinding = defaultsByID[advisory.actionID],
                      current.binding == defaultBinding.binding,
                      case let .chord(chord) = current.binding,
                      !chord.isUnassigned
                else { return nil }
                return DiagnosticsIssue(kind: .hotkeyCoFireAdvisory(
                    actionID: advisory.actionID,
                    command: advisory.command.displayName,
                    chord: chord.displayString,
                    advisory: advisory.text
                ))
            }
    }
}
