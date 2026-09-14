// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import Foundation
import QuartzCore

extension WorkspaceManager {
    func monitorResolutionContext() -> MonitorResolutionContext {
        MonitorResolutionContext(
            monitors: monitors,
            sortedMonitors: sortedMonitors(),
            topologyProfile: currentTopologyProfile(),
            configuredWorkspaceNames: configuredWorkspaceNameSet(),
            monitorDescriptionByWorkspaceName: monitorDescriptionByWorkspaceName()
        )
    }

    func monitorResolutionContext(for monitors: [Monitor]) -> MonitorResolutionContext {
        if monitors == self.monitors {
            return monitorResolutionContext()
        }
        let sortedMonitors = Monitor.sortedByPosition(monitors)
        var descriptions: [String: MonitorDescription] = [:]
        for configuration in settings.monitors.effectiveWorkspaceConfigurations(
            settings.workspaces.configurations,
            for: monitors
        ) {
            descriptions[configuration.name] = configuration.monitorAssignment.toMonitorDescription()
        }
        return MonitorResolutionContext(
            monitors: monitors,
            sortedMonitors: sortedMonitors,
            topologyProfile: TopologyProfile(sortedMonitors: sortedMonitors),
            configuredWorkspaceNames: configuredWorkspaceNameSet(),
            monitorDescriptionByWorkspaceName: descriptions
        )
    }
}
