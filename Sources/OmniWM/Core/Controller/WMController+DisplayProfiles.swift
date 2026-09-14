// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

extension WMController {
    var activeDisplayProfile: DisplayProfile? {
        settings.monitors.activeDisplayProfile(for: workspaceManager.monitors)
    }

    func displayProfileUnavailableReason(_ profile: DisplayProfile) -> String? {
        guard settings.monitors.displayProfiles.filter({ $0.id == profile.id }).count == 1 else {
            return "The profile identity is missing or duplicated."
        }
        return DisplayProfileResolver.unavailableReason(for: profile, monitors: workspaceManager.monitors)
    }

    @discardableResult
    func applyDisplayProfile(id: UUID) -> Bool {
        guard let profile = settings.monitors.displayProfiles.first(where: { $0.id == id }),
              displayProfileUnavailableReason(profile) == nil
        else { return false }
        settings.monitors.selectedDisplayProfileID = id
        settings.monitors.automaticProfilesEnabled = false
        updateWorkspaceConfig()
        return true
    }

    func pauseAutomaticDisplayProfiles() {
        settings.monitors.selectedDisplayProfileID = activeDisplayProfile?.id
        settings.monitors.automaticProfilesEnabled = false
        updateDisplayProfiles()
    }

    func resumeAutomaticDisplayProfiles() {
        settings.monitors.selectedDisplayProfileID = nil
        settings.monitors.automaticProfilesEnabled = true
        updateDisplayProfiles()
    }

    func updateDisplayProfiles() {
        guard workspaceManager.displayProfileAssignmentsChanged(for: workspaceManager.monitors) else {
            workspaceManager.appliedDisplayProfileID = activeDisplayProfile?.id
            return
        }
        updateWorkspaceConfig()
    }
}
