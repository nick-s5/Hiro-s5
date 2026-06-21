// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation
import os

final class RawAXNotificationTrace: RuntimeTraceRecording, @unchecked Sendable {
    static let shared = RawAXNotificationTrace()

    let sectionTitle = "Raw AX Notifications"

    struct Record: Sendable {
        let sequence: UInt64
        let timestamp: Date
        let name: String
        let pid: pid_t
        let windowId: Int?
    }

    private struct State {
        var buffer: RingBuffer<Record>
        var nextSequence: UInt64 = 0
        var captureStart: UInt64?
        var captureEnd: UInt64?
    }

    private static let capacity = 512
    private let lockedState = OSAllocatedUnfairLock(
        initialState: State(buffer: RingBuffer(capacity: RawAXNotificationTrace.capacity))
    )

    static func record(name: String, pid: pid_t, windowId: Int?) {
        shared.record(name: name, pid: pid, windowId: windowId)
    }

    func record(name: String, pid: pid_t, windowId: Int?) {
        lockedState.withLock { state in
            let record = Record(
                sequence: state.nextSequence,
                timestamp: Date(),
                name: name,
                pid: pid,
                windowId: windowId
            )
            state.nextSequence += 1
            state.buffer.append(record)
        }
    }

    func beginCapture() {
        lockedState.withLock { state in
            state.captureStart = state.nextSequence
            state.captureEnd = nil
        }
    }

    func endCapture() {
        lockedState.withLock { state in
            state.captureEnd = state.nextSequence
        }
    }

    func dump() -> String {
        let records: [Record] = lockedState.withLock { state in
            guard let start = state.captureStart else { return [] }
            let end = state.captureEnd ?? state.nextSequence
            return state.buffer.snapshot().filter { $0.sequence >= start && $0.sequence < end }
        }
        return format(records)
    }

    func recentDump() -> String {
        format(lockedState.withLock { $0.buffer.snapshot() })
    }

    private func format(_ records: [Record]) -> String {
        guard !records.isEmpty else { return "none" }
        return records
            .map { record in
                var line = "\(record.timestamp.ISO8601Format()) ax=\(record.name) pid=\(record.pid)"
                if let windowId = record.windowId {
                    line += " win=\(windowId)"
                }
                return line
            }
            .joined(separator: "\n")
    }
}
