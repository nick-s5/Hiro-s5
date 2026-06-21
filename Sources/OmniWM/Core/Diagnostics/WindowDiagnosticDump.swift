// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

struct WindowDiagnosticOmniWMBlock: Codable, Equatable, Sendable {
    var tokenPid: Int32
    var tokenWindowId: Int
    var appName: String?
    var bundleId: String?
    var workspaceName: String?
    var input: WindowClassificationInput
    var expected: WindowClassificationExpectation
}

struct WindowDiagnosticDump: Codable, Equatable, Sendable {
    var generatedAt: String
    var os: String
    var appVersion: String?
    var omniwm: WindowDiagnosticOmniWMBlock
    var ax: AXWindowAXTreeDump
}
