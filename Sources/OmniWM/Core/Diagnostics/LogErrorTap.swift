// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

final class LogErrorTap: @unchecked Sendable {
    static let shared = LogErrorTap()

    struct Entry: Sendable {
        let timestamp: Date
        let category: String
        let level: String
        let message: String
    }

    private static let limit = 256

    private let buffer = LockedRingBuffer<Entry>(capacity: LogErrorTap.limit)

    func record(category: String, level: String, message: String) {
        buffer.append(Entry(timestamp: Date(), category: category, level: level, message: message))
    }

    func dump() -> String {
        let entries = buffer.snapshot()
        guard !entries.isEmpty else { return "none" }
        return entries
            .map { "\($0.timestamp.ISO8601Format()) [\($0.level)] \($0.category): \($0.message)" }
            .joined(separator: "\n")
    }

    func reset() {
        buffer.removeAll()
    }
}
