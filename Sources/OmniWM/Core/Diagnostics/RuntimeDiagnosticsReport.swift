// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import CoreGraphics
import Foundation

@MainActor
enum RuntimeDiagnosticsReport {
    static func build(_ controller: WMController, traceLimit: Int) -> String {
        [
            systemSection(controller),
            section("Active Issues", issuesSection(controller)),
            section("Private API Capability", PrivateAPIHealthDiagnostics.snapshot().formatted()),
            section("Recent Errors", LogErrorTap.shared.dump()),
            monitorSection(),
            section("Space Topology", controller.workspaceManager.spaceTopology.debugSummary),
            focusedWindowSection(controller),
            section("Input / Hotkey Health", InputDiagnostics.inputHealth(controller).formatted()),
            section("Owned Windows / Surface", InputDiagnostics.ownedSurfaces(controller).formatted()),
            section("Interaction Monitor Writes", InteractionMonitorWriteRecorder.shared.dump()),
            section("Reconcile Snapshot", controller.workspaceManager.reconcileSnapshotDump()),
            section("Reconcile Trace", controller.workspaceManager.reconcileTraceDump(limit: traceLimit)),
            section("Invariant Violations", controller.workspaceManager.invariantViolationCountsDump()),
            section("AX Frame State", controller.axManager.frameStateDump()),
            section("Recent AX Notifications", RawAXNotificationTrace.shared.recentDump()),
            section("Layout Build Metrics", controller.layoutRefreshController.layoutBuildMetricsDump()),
            section("Create-Focus Trace", controller.axEventHandler.createFocusTraceDump()),
            section("Managed Replacement Trace", controller.axEventHandler.managedReplacementTraceDump()),
            settingsSection(controller)
        ]
        .joined(separator: "\n\n")
    }

    private static func section(_ title: String, _ body: String) -> String {
        "== \(title) ==\n\(body)"
    }

    private static func issuesSection(_ controller: WMController) -> String {
        let issues = DiagnosticsIssueAggregator.applicableIssues(controller: controller)
        guard !issues.isEmpty else { return "none" }
        return issues
            .map { issue in
                let label = issue.severity == .critical ? "CRITICAL" : "WARNING"
                return "[\(label)] \(issue.title) — \(issue.message)"
            }
            .joined(separator: "\n")
    }

    private static func systemSection(_ controller: WMController) -> String {
        let lines = [
            "generatedAt=\(Date().ISO8601Format())",
            "appVersion=\(OmniWMBuildInfo.version)",
            "build=\(OmniWMBuildInfo.build)",
            "gitHash=\(OmniWMBuildInfo.gitHash)",
            "os=\(ProcessInfo.processInfo.operatingSystemVersionString)",
            "accessibilityGranted=\(controller.accessibilityPermissionGranted)",
            "enabled=\(controller.isEnabled)"
        ]
        return section("OmniWM Diagnostics", lines.joined(separator: "\n"))
    }

    private static func monitorSection() -> String {
        let monitors = Monitor.current()
        guard !monitors.isEmpty else { return section("Monitors", "none") }
        let body = monitors
            .map { "id=\($0.id) name=\($0.name) frame=\(format($0.frame)) visible=\(format($0.visibleFrame))" }
            .joined(separator: "\n")
        return section("Monitors", body)
    }

    private static func focusedWindowSection(_ controller: WMController) -> String {
        section("Focused Window Decision", controller.focusedWindowDecisionDebugSnapshot()?.formattedDump() ?? "none")
    }

    private static func settingsSection(_ controller: WMController) -> String {
        let body: String
        do {
            let encoded = try SettingsTOMLCodec.encode(controller.settings.toExport())
            body = String(bytes: encoded, encoding: .utf8) ?? ""
        } catch {
            body = "settings encode failed: \(error.localizedDescription)"
        }
        return section("Settings (TOML)", body)
    }

    private static func format(_ rect: CGRect) -> String {
        "x=\(Int(rect.minX.rounded())) y=\(Int(rect.minY.rounded())) w=\(Int(rect.width.rounded())) h=\(Int(rect.height.rounded()))"
    }
}
