// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

extension WorkspaceManager {
    func effectiveWorkspaceMonitorAssignments(for monitors: [Monitor]) -> [String: MonitorAssignment] {
        var assignments: [String: MonitorAssignment] = [:]
        for configuration in settings.monitors.effectiveWorkspaceConfigurations(
            settings.workspaces.configurations,
            for: monitors
        ) {
            assignments[configuration.name] = configuration.monitorAssignment
        }
        return assignments
    }

    func effectiveWorkspaceMonitorTargets(for monitors: [Monitor]) -> [String: OutputId] {
        let sortedMonitors = Monitor.sortedByPosition(monitors)
        return effectiveWorkspaceMonitorAssignments(for: monitors).compactMapValues { assignment in
            assignment.toMonitorDescription().resolveMonitor(sortedMonitors: sortedMonitors).map(OutputId.init(from:))
        }
    }

    func displayProfileAssignmentsChanged(for monitors: [Monitor]) -> Bool {
        appliedWorkspaceMonitorAssignments != effectiveWorkspaceMonitorAssignments(for: monitors) ||
            appliedWorkspaceMonitorTargets != effectiveWorkspaceMonitorTargets(for: monitors)
    }

    func prepareDisplayProfileTransition(to newMonitors: [Monitor]) {
        guard appliedDisplayProfileID != nil || settings.monitors.activeDisplayProfile(for: newMonitors) != nil else {
            return
        }
        let assignments = effectiveWorkspaceMonitorAssignments(for: newMonitors)
        let previousVisibleWorkspaces = activeVisibleWorkspaceMap()
        let sortedNewMonitors = Monitor.sortedByPosition(newMonitors)
        for workspace in sortedWorkspaces() where workspace.runtimeMonitorOverride == nil {
            guard let nextAssignment = assignments[workspace.name],
                  let source = previousDisplayProfileMonitor(
                      for: workspace,
                      visibleWorkspaces: previousVisibleWorkspaces
                  ),
                  let retainedSource = OutputId(from: source).resolveMonitor(in: newMonitors),
                  let target = nextAssignment.toMonitorDescription().resolveMonitor(sortedMonitors: sortedNewMonitors),
                  retainedSource.id != target.id,
                  isWorkspaceMonitorMoveUnsafe(
                      workspace.id,
                      sourceMonitorId: source.id,
                      visibleWorkspaces: previousVisibleWorkspaces
                  )
            else { continue }
            updateWorkspace(workspace.id) {
                $0.runtimeMonitorOverride = OutputId(from: source)
            }
        }
    }

    private func previousDisplayProfileMonitor(
        for workspace: WorkspaceDescriptor,
        visibleWorkspaces: [Monitor.ID: WorkspaceDescriptor.ID]
    ) -> Monitor? {
        if let visibleMonitorID = visibleWorkspaces.first(where: { $0.value == workspace.id })?.key,
           let visibleMonitor = monitor(byId: visibleMonitorID)
        {
            return visibleMonitor
        }
        if let configuredMonitor = appliedWorkspaceMonitorTargets[workspace.name]?.resolveMonitor(in: monitors) {
            return configuredMonitor
        }
        guard let anchor = workspace.assignedMonitorPoint else { return sortedMonitors().first }
        return monitors.min { lhs, rhs in
            let lhsDistance = lhs.workspaceAnchorPoint.distanceSquared(to: anchor)
            let rhsDistance = rhs.workspaceAnchorPoint.distanceSquared(to: anchor)
            return lhsDistance == rhsDistance
                ? MonitorRestoreOrder(monitor: lhs) < MonitorRestoreOrder(monitor : rhs):
                lhsDistance < rhsDistance
        }
    }
}
