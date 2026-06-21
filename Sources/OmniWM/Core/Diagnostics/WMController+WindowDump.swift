// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import Foundation

@MainActor
extension WMController {
    func makeFocusedWindowDiagnosticDump() async -> WindowDiagnosticDump? {
        guard let token = focusedOrFrontmostWindowTokenForAutomation(),
              let axRef = dumpableAXWindowRef(for: token)
        else { return nil }

        let evaluation = evaluateWindowDisposition(axRef: axRef, pid: token.pid)
        guard let axTree = await factResolver.dumpWindowAXTree(axRef: axRef, pid: token.pid) else { return nil }

        let input = WindowClassificationInput(
            appName: evaluation.facts.appName,
            ax: AXWindowFactsDTO(from: evaluation.facts.ax),
            sizeConstraints: evaluation.facts.sizeConstraints.map(WindowSizeConstraintsDTO.init(from:)),
            windowServer: evaluation.facts.windowServer.map(WindowServerInfoDTO.init(from:)),
            appFullscreen: evaluation.appFullscreen,
            manualOverride: evaluation.manualOverride,
            rules: settings.appRules
        )
        let omniwm = WindowDiagnosticOmniWMBlock(
            tokenPid: token.pid,
            tokenWindowId: token.windowId,
            appName: evaluation.facts.appName,
            bundleId: evaluation.facts.ax.bundleId,
            workspaceName: evaluation.decision.workspaceName,
            input: input,
            expected: WindowClassificationExpectation(from: evaluation.decision)
        )
        return WindowDiagnosticDump(
            generatedAt: Date().ISO8601Format(),
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: OmniWMBuildInfo.version,
            omniwm: omniwm,
            ax: axTree
        )
    }

    @discardableResult
    func writeWindowDiagnosticDump(_ dump: WindowDiagnosticDump) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dump)
        let directory = diagnosticsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(
            "omniwm-window-\(dump.omniwm.tokenWindowId)-\(Int(Date().timeIntervalSince1970 * 1000)).json",
            isDirectory: false
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    private func dumpableAXWindowRef(for token: WindowToken) -> AXWindowRef? {
        workspaceManager.entry(for: token)?.axRef
            ?? AXWindowService.axWindowRef(for: UInt32(token.windowId), pid: token.pid)
    }
}
