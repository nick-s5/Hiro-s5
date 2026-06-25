// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import CoreGraphics
import QuartzCore

enum ScrollTickTrace {
    struct Record: Sendable {
        let mediaTime: CFTimeInterval
        let displayId: CGDirectDisplayID
        let animsMs: Double
        let snapshotMs: Double
        let buildMs: Double
        let commitMs: Double
        let totalMs: Double
        let show: Int
        let hide: Int
        let frames: Int
        let windowCount: Int
        let isAnimationTick: Bool
    }

    static let shared = SessionTraceRecorder<Record>(
        sectionTitle: "Scroll Tick Breakdown",
        capacity: 2048
    ) { record in
        let spans = String(
            format: "anims=%.2fms snapshot=%.2fms build=%.2fms commit=%.2fms total=%.2fms",
            record.animsMs,
            record.snapshotMs,
            record.buildMs,
            record.commitMs,
            record.totalMs
        )
        let mediaTime = String(format: "%.3f", record.mediaTime)
        return "t=\(mediaTime) disp=\(record.displayId) \(spans)"
            + " show=\(record.show) hide=\(record.hide) frames=\(record.frames)"
            + " win=\(record.windowCount) anim=\(record.isAnimationTick)"
    }
}
