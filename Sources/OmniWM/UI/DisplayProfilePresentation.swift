// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import SwiftUI

enum DisplayProfilePresentation {
    static func outputs(profiles: [DisplayProfile], monitors: [Monitor]) -> [OutputId] {
        var outputs = monitors.map { OutputId(from: $0) }
        for profile in profiles {
            for output in profile.requiredDisplays + profile.assignments.compactMap({ assignment in
                if case let .specificDisplay(output) = assignment.monitorAssignment { return output }
                return nil
            }) where !outputs.contains(output) {
                outputs.append(output)
            }
        }
        return outputs
    }

    static func label(_ output: OutputId, among outputs: [OutputId], monitors: [Monitor]) -> String {
        let duplicates = outputs.filter { $0.name == output.name }
        let suffix = duplicates.count > 1 ? " · \((duplicates.firstIndex(of: output) ?? 0) + 1)" : ""
        let status = output.resolveMonitor(in: monitors) == nil ? " (Disconnected)" : ""
        return output.name + suffix + status
    }

    static func assignment(
        for configuration: WorkspaceConfiguration,
        in profile: DisplayProfile
    ) -> MonitorAssignment {
        profile.assignments.first { $0.workspaceName == configuration.name }?.monitorAssignment
            ?? configuration.monitorAssignment
    }

    static func output(for assignment: MonitorAssignment, monitors: [Monitor]) -> OutputId? {
        switch assignment {
        case .main,
             .secondary:
            return assignment.toMonitorDescription()
                .resolveMonitor(sortedMonitors: Monitor.sortedByPosition(monitors))
                .map { OutputId(from: $0) }
        case let .specificDisplay(output):
            return output
        }
    }

    static func displays(
        profile: DisplayProfile,
        configurations: [WorkspaceConfiguration],
        monitors: [Monitor]
    ) -> [DisplayProfileDiagram.Display] {
        let outputs = outputs(profiles: [profile], monitors: monitors)
        return outputs.enumerated().map { index, output in
            DisplayProfileDiagram.Display(
                id: index,
                name: label(output, among: outputs, monitors: monitors),
                isConnected: output.resolveMonitor(in: monitors) != nil,
                isBuiltIn: output.resolveMonitor(in: monitors).map { CGDisplayIsBuiltin($0.displayId) != 0 } ?? false,
                isRequired: profile.requiredDisplays.contains(output),
                workspaceNames: configurations.filter {
                    Self.output(for: assignment(for: $0, in: profile), monitors: monitors) == output
                }.map(\.name)
            )
        }
    }
}
