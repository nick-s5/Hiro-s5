// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation
import QuartzCore

enum AXWriteLatencyTrace {
    struct Record: Sendable {
        let mediaTime: CFTimeInterval
        let pid: pid_t
        let count: Int
        let totalMs: Double
        let slowestMs: Double
        let enhancedUI: Bool
    }

    static let shared = SessionTraceRecorder<Record>(
        sectionTitle: "AX Write Latency",
        capacity: 2048
    ) { record in
        let timing = String(format: "total=%.2fms slowest=%.2fms", record.totalMs, record.slowestMs)
        let mediaTime = String(format: "%.3f", record.mediaTime)
        return "t=\(mediaTime) pid=\(record.pid) count=\(record.count) \(timing)"
            + " enhancedUI=\(record.enhancedUI)"
    }
}
