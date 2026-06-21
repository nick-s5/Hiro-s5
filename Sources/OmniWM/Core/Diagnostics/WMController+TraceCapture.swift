// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

@MainActor
extension WMController {
    var isTraceCaptureActive: Bool {
        traceCaptureCoordinator.isActive
    }

    var traceCaptureStatus: TraceCaptureStatus {
        traceCaptureCoordinator.status
    }

    @discardableResult
    func toggleTraceCaptureForUI(desiredState: TraceCaptureDesiredState = .toggle) -> TraceCaptureOutcome {
        traceCaptureCoordinator.toggle(desiredState: desiredState) { [weak self] in
            self?.diagnosticsReportText() ?? ""
        }
    }
}
