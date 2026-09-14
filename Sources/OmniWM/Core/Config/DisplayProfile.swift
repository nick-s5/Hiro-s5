// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation
import OmniWMIPC

struct DisplayProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var requiredDisplays: [OutputId]
    var assignments: [DisplayProfileAssignment]

    init(
        id: UUID = UUID(),
        name: String,
        requiredDisplays: [OutputId],
        assignments: [DisplayProfileAssignment]
    ) {
        self.id = id
        self.name = name
        self.requiredDisplays = requiredDisplays
        self.assignments = assignments
    }
}

struct DisplayProfileAssignment: Codable, Equatable {
    var workspaceName: String
    var monitorAssignment: MonitorAssignment
}

enum DisplayProfileResolver {
    static func unavailableReason(for profile: DisplayProfile, monitors: [Monitor]) -> String? {
        guard !monitors.isEmpty else { return "No displays are connected." }
        guard !profile.requiredDisplays.isEmpty else { return "Choose at least one required display." }
        guard !profile.assignments.isEmpty else { return "Assign at least one workspace." }
        guard Set(profile.requiredDisplays).count == profile.requiredDisplays.count else {
            return "A required display appears more than once."
        }
        for output in profile.requiredDisplays where output.resolveMonitor(in: monitors) == nil {
            return "Required display \(output.name) is unavailable or ambiguous."
        }
        var names = Set<String>()
        let sortedMonitors = Monitor.sortedByPosition(monitors)
        for assignment in profile.assignments {
            guard WorkspaceIDPolicy.normalizeRawID(assignment.workspaceName) != nil else {
                return "Workspace \(assignment.workspaceName) is invalid."
            }
            guard names.insert(assignment.workspaceName).inserted else {
                return "Workspace \(assignment.workspaceName) is assigned more than once."
            }
            guard assignment.monitorAssignment.toMonitorDescription()
                .resolveMonitor(sortedMonitors: sortedMonitors) != nil
            else {
                return "The destination for workspace \(assignment.workspaceName) is unavailable or ambiguous."
            }
        }
        return nil
    }

    static func selectedProfile(
        in profiles: [DisplayProfile],
        automatic: Bool,
        selectedID: UUID?,
        monitors: [Monitor]
    ) -> DisplayProfile? {
        let uniqueIDs = Dictionary(grouping: profiles, by: \.id)
        return profiles.first { profile in
            (automatic || profile.id == selectedID) &&
                uniqueIDs[profile.id]?.count == 1 &&
                unavailableReason(for: profile, monitors: monitors) == nil
        }
    }

    static func applying(
        _ profile: DisplayProfile?,
        to configurations: [WorkspaceConfiguration]
    ) -> [WorkspaceConfiguration] {
        guard let profile else { return configurations }
        var assignments: [String: MonitorAssignment] = [:]
        for assignment in profile.assignments {
            assignments[assignment.workspaceName] = assignment.monitorAssignment
        }
        return configurations.map { configuration in
            guard let assignment = assignments[configuration.name] else { return configuration }
            var updated = configuration
            updated.monitorAssignment = assignment
            return updated
        }
    }
}
