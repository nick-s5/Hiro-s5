// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import SwiftUI

struct DisplayProfilesSection: View {
    @Bindable var settings: SettingsStore
    @Bindable var controller: WMController
    let monitors: [Monitor]

    @State private var inspectedProfileID: UUID?
    @State private var editingProfile: DisplayProfile?
    @State private var pendingDelete: DisplayProfile?
    @State private var applyError: String?

    private var profiles: [DisplayProfile] {
        settings.monitors.displayProfiles
    }

    private var inspectedProfile: DisplayProfile? {
        profiles.first { $0.id == inspectedProfileID } ?? profiles.first
    }

    var body: some View {
        Section("Display Profiles") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        settings.monitors
                            .automaticProfilesEnabled ? "Automatic switching on" : "Automatic switching paused",
                        systemImage: settings.monitors.automaticProfilesEnabled ? "arrow.triangle.2.circlepath" : "pause.circle"
                    )
                    Text(controller.activeDisplayProfile
                        .map { "Active: \($0.name)" } ?? "Using base workspace assignments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(settings.monitors.automaticProfilesEnabled ? "Pause" : "Resume Automatic") {
                    if settings.monitors.automaticProfilesEnabled {
                        controller.pauseAutomaticDisplayProfiles()
                    } else {
                        controller.resumeAutomaticDisplayProfiles()
                    }
                }
                .disabled(profiles.isEmpty && !settings.monitors.automaticProfilesEnabled)
            }

            SettingsCaption(
                "Profiles match when all required displays are connected. The first available match wins; "
                    + "move more specific setups above general ones. Selecting a profile previews it without applying it."
            )

            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                profileRow(profile, index: index)
            }

            if let profile = inspectedProfile {
                DisplayProfileDiagram(displays: DisplayProfilePresentation.displays(
                    profile: profile, configurations: settings.workspaces.configurations, monitors: monitors
                ))

                if let reason = controller.displayProfileUnavailableReason(profile) {
                    Label(reason, systemImage: "display.trianglebadge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Edit Profile…") { editingProfile = profile }
                    Button("Duplicate") { duplicate(profile) }
                    Spacer()
                    Button("Apply \(profile.name)") {
                        applyError = controller.applyDisplayProfile(id: profile.id) ? nil :
                            "This profile could not be applied. Check its required displays and workspace assignments."
                    }
                    .disabled(controller.displayProfileUnavailableReason(profile) != nil)
                    .help("Apply these workspace homes and pause automatic switching")
                }
                if let applyError {
                    Label(applyError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Save a setup for each desk",
                    systemImage: "display.2",
                    description: Text(
                        "Assign workspaces to your displays, then switch automatically when you connect them."
                    )
                )
            }

            HStack {
                Button(action: addProfile) { Label("New Profile…", systemImage: "plus") }
                Button("Use Base Assignments") {
                    settings.monitors.selectedDisplayProfileID = nil
                    settings.monitors.automaticProfilesEnabled = false
                    controller.updateDisplayProfiles()
                    applyError = nil
                }
                .disabled(settings.monitors.selectedDisplayProfileID == nil && !settings.monitors
                    .automaticProfilesEnabled)
                Spacer()
                if let profile = inspectedProfile {
                    Button("Delete Profile", role: .destructive) { pendingDelete = profile }
                }
            }

            SettingsCaption(
                "A display can have zero assigned workspaces, including the built-in display. "
                    + "Profiles change workspace homes; macOS display positions and OmniWM routing stay separate."
            )
        }
        .sheet(item: $editingProfile) { profile in
            DisplayProfileEditor(
                profile: profile,
                configurations: settings.workspaces.configurations,
                monitors: monitors,
                savedProfiles: profiles,
                onSave: save,
                onCancel: { editingProfile = nil }
            )
        }
        .alert("Delete Display Profile?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { profile in
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                delete(profile)
                pendingDelete = nil
            }
        } message: { profile in
            Text(
                "Delete “\(profile.name)”? If it is active, workspace homes will use the next matching profile or base assignments."
            )
        }
        .onChange(of: inspectedProfileID) { _, _ in applyError = nil }
    }

    private func profileRow(_ profile: DisplayProfile, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Button {
                inspectedProfileID = profile.id
            } label: {
                HStack {
                    Image(systemName: inspectedProfile?.id == profile.id ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(inspectedProfile?.id == profile.id ? Color.accentColor : .secondary)
                    Text(profile.name).foregroundStyle(.primary)
                    Spacer()
                    if controller.activeDisplayProfile?.id == profile.id {
                        Text("Active").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(profile.name), priority \(index + 1)")
            .accessibilityAddTraits(inspectedProfile?.id == profile.id ? .isSelected : [])

            Button { move(profile, by: -1) } label: {
                Label("Raise priority", systemImage: "arrow.up").labelStyle(.iconOnly)
            }
            .disabled(index == 0)
            .accessibilityLabel("Raise priority of \(profile.name)")
            Button { move(profile, by: 1) } label: {
                Label("Lower priority", systemImage: "arrow.down").labelStyle(.iconOnly)
            }
            .disabled(index == profiles.count - 1)
            .accessibilityLabel("Lower priority of \(profile.name)")
        }
        .padding(.vertical, 3)
    }

    private func addProfile() {
        let active = controller.activeDisplayProfile
        let assignments = settings.workspaces.configurations.map { configuration in
            let assignment = active.map { DisplayProfilePresentation.assignment(for: configuration, in: $0) }
                ?? configuration.monitorAssignment
            let pinned = DisplayProfilePresentation.output(for: assignment, monitors: monitors)
                .map { MonitorAssignment.specificDisplay($0) } ?? assignment
            return DisplayProfileAssignment(workspaceName: configuration.name, monitorAssignment: pinned)
        }
        editingProfile = DisplayProfile(
            name: "New Profile",
            requiredDisplays: monitors.map { OutputId(from: $0) },
            assignments: assignments
        )
    }

    private func duplicate(_ profile: DisplayProfile) {
        editingProfile = DisplayProfile(
            name: profile.name + " Copy",
            requiredDisplays: profile.requiredDisplays,
            assignments: profile.assignments
        )
    }

    private func save(_ profile: DisplayProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            settings.monitors.displayProfiles[index] = profile
        } else {
            settings.monitors.displayProfiles.append(profile)
        }
        inspectedProfileID = profile.id
        editingProfile = nil
        controller.updateDisplayProfiles()
    }

    private func move(_ profile: DisplayProfile, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }),
              profiles.indices.contains(index + offset) else { return }
        settings.monitors.displayProfiles.swapAt(index, index + offset)
        controller.updateDisplayProfiles()
    }

    private func delete(_ profile: DisplayProfile) {
        settings.monitors.displayProfiles.removeAll { $0.id == profile.id }
        controller.updateDisplayProfiles()
    }
}
