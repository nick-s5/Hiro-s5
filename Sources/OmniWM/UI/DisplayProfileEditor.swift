// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import SwiftUI

struct DisplayProfileEditor: View {
    @State var profile: DisplayProfile
    let configurations: [WorkspaceConfiguration]
    let monitors: [Monitor]
    let savedProfiles: [DisplayProfile]
    let onSave: (DisplayProfile) -> Void
    let onCancel: () -> Void

    private var outputs: [OutputId] {
        DisplayProfilePresentation.outputs(profiles: [profile] + savedProfiles, monitors: monitors)
    }

    private var validName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Display Profile").font(.headline)
                Spacer()
            }
            .padding(20)

            Form {
                Section {
                    TextField("Profile Name", text: $profile.name)
                    DisplayProfileDiagram(displays: DisplayProfilePresentation.displays(
                        profile: profile, configurations: configurations, monitors: monitors
                    ))
                    SettingsCaption("Preview workspace homes below. Assigning zero workspaces to a display is allowed.")
                }

                Section("Required Connected Displays") {
                    ForEach(outputs, id: \.self) { output in
                        Toggle(isOn: requiredBinding(output)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DisplayProfilePresentation.label(output, among: outputs, monitors: monitors))
                                if output.displayUUID == nil {
                                    Text("Session identity only").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    SettingsCaption(
                        profile.requiredDisplays.isEmpty ?
                            "Choose at least one required display before saving. A built-in display can anchor a general profile." :
                            "Every checked display must be connected. Additional displays are allowed. "
                            + "Saved disconnected displays remain available here."
                    )
                }

                Section("Workspace Assignments") {
                    ForEach(configurations) { configuration in
                        Picker(selection: assignmentBinding(configuration)) {
                            Text("Main Display").tag(MonitorAssignment.main)
                            Text("Secondary Display").tag(MonitorAssignment.secondary)
                            Divider()
                            ForEach(outputs, id: \.self) { output in
                                Text(DisplayProfilePresentation.label(output, among: outputs, monitors: monitors))
                                    .tag(MonitorAssignment.specificDisplay(output))
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Workspace \(configuration.name)")
                                if configuration.effectiveDisplayName != configuration.name {
                                    Text(configuration.effectiveDisplayName).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityLabel("Home display for workspace \(configuration.name)")
                    }
                    SettingsCaption(
                        "Main and Secondary follow the current macOS roles. Choose a named display to keep a fixed home. "
                            + "A profile waits until its assigned displays are available. "
                            + "Create or rename workspaces in Workspaces settings."
                    )
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text("Saving updates this profile immediately if it is active or becomes the automatic match.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save Profile") {
                    var saved = profile
                    saved.name = validName
                    saved.assignments = configurations.map { configuration in
                        DisplayProfileAssignment(
                            workspaceName: configuration.name,
                            monitorAssignment: DisplayProfilePresentation.assignment(for: configuration, in: profile)
                        )
                    }
                    onSave(saved)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validName.isEmpty || profile.requiredDisplays.isEmpty || configurations.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 660, height: 720)
    }

    private func requiredBinding(_ output: OutputId) -> Binding<Bool> {
        Binding(
            get: { profile.requiredDisplays.contains(output) },
            set: { required in
                profile.requiredDisplays.removeAll { $0 == output }
                if required { profile.requiredDisplays.append(output) }
            }
        )
    }

    private func assignmentBinding(_ configuration: WorkspaceConfiguration) -> Binding<MonitorAssignment> {
        Binding(
            get: { DisplayProfilePresentation.assignment(for: configuration, in: profile) },
            set: { assignment in
                profile.assignments.removeAll { $0.workspaceName == configuration.name }
                profile.assignments.append(DisplayProfileAssignment(
                    workspaceName: configuration.name,
                    monitorAssignment: assignment
                ))
            }
        )
    }
}
