// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import os

final class FallbackFiringRecorder: @unchecked Sendable {
    static let shared = FallbackFiringRecorder()

    static let categories = ["skylight", "ax", "input", "capture", "monitor", "system"]

    private let counts = OSAllocatedUnfairLock(initialState: [String: Int]())

    func note(_ category: String, _ key: String, _ amount: Int = 1) {
        guard amount > 0 else { return }
        counts.withLock { $0["\(category)/\(key)", default: 0] += amount }
    }

    func dump() -> String {
        let snapshot = counts.withLock { $0 }
        guard !snapshot.isEmpty else { return "none — no fallback/failure has fired since launch" }
        var lines: [String] = []
        for category in Self.categories {
            let entries = snapshot
                .filter { $0.key.hasPrefix("\(category)/") }
                .sorted { $0.key < $1.key }
            guard !entries.isEmpty else { continue }
            lines.append("[\(category)]")
            for (key, value) in entries {
                lines.append("  \(key.dropFirst(category.count + 1))=\(value)")
            }
        }
        let other = snapshot
            .filter { entry in !Self.categories.contains { entry.key.hasPrefix("\($0)/") } }
            .sorted { $0.key < $1.key }
        if !other.isEmpty {
            lines.append("[other]")
            for (key, value) in other {
                lines.append("  \(key)=\(value)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
