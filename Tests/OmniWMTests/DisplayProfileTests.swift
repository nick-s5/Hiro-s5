// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import ApplicationServices
import CoreGraphics
import Foundation
@testable import OmniWM
import TOML
import XCTest

final class DisplayProfileTests: XCTestCase {
    private let firstUUID = "11111111-1111-1111-1111-111111111111"
    private let secondUUID = "22222222-2222-2222-2222-222222222222"

    private func monitor(_ displayID: CGDirectDisplayID, uuid: String, x: CGFloat = 0) -> Monitor {
        let frame = CGRect(x: x, y: 0, width: 1920, height: 1080)
        return Monitor(
            id: .init(displayId: displayID), displayId: displayID,
            frame: frame, visibleFrame: frame, hasNotch: false,
            name: "Display", displayUUID: uuid
        )
    }

    private func profile(for monitor: Monitor, name: String = "Desk") -> DisplayProfile {
        DisplayProfile(name: name, requiredDisplays: [OutputId(from: monitor)], assignments: [
            DisplayProfileAssignment(workspaceName: "1", monitorAssignment: .specificDisplay(OutputId(from: monitor)))
        ])
    }

    func testFirstEligibleProfileWinsWithAdditionalConnectedDisplays() {
        let first = monitor(1, uuid: firstUUID)
        let second = monitor(2, uuid: secondUUID, x: 1920)
        let broad = profile(for: first, name: "Broad")
        let specific = DisplayProfile(
            name: "Both", requiredDisplays: [OutputId(from: first), OutputId(from: second)],
            assignments: broad.assignments
        )
        XCTAssertEqual(DisplayProfileResolver.selectedProfile(
            in: [broad, specific], automatic: true, selectedID: nil, monitors: [first, second]
        )?.id, broad.id)
        XCTAssertEqual(DisplayProfileResolver.selectedProfile(
            in: [specific, broad], automatic: true, selectedID: nil, monitors: [first, second]
        )?.id, specific.id)
    }

    func testMissingRequiredDisplayAndMissingAssignmentDestinationAreIneligible() {
        let first = monitor(1, uuid: firstUUID)
        let second = monitor(2, uuid: secondUUID)
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: profile(for: second), monitors: [first]))
        var assignmentMissing = profile(for: first)
        assignmentMissing.assignments[0].monitorAssignment = .specificDisplay(OutputId(from: second))
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: assignmentMissing, monitors: [first]))
        assignmentMissing.assignments[0].monitorAssignment = .secondary
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: assignmentMissing, monitors: [first]))
    }

    func testUUIDIdentitySurvivesDisplayIDChangeButRejectsAmbiguousCollision() {
        let original = monitor(1, uuid: firstUUID)
        let reconnected = monitor(99, uuid: firstUUID)
        let saved = profile(for: original)
        XCTAssertNil(DisplayProfileResolver.unavailableReason(for: saved, monitors: [reconnected]))
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: saved, monitors: [original, reconnected]))
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(
            for: saved, monitors: [monitor(1, uuid: secondUUID)]
        ))
    }

    func testManualSelectionDoesNotFollowPriorityAndDisabledDefaultsUseBase() {
        let connected = monitor(1, uuid: firstUUID)
        let first = profile(for: connected)
        let second = profile(for: connected, name: "Manual")
        XCTAssertEqual(DisplayProfileResolver.selectedProfile(
            in: [first, second], automatic: false, selectedID: second.id, monitors: [connected]
        )?.id, second.id)
        XCTAssertNil(DisplayProfileResolver.selectedProfile(
            in: [first, second], automatic: false, selectedID: nil, monitors: [connected]
        ))
        XCTAssertNil(DisplayProfileResolver.selectedProfile(
            in: [first, first], automatic: true, selectedID: nil, monitors: [connected]
        ))
    }

    func testInvalidDuplicateRequirementsOrAssignmentsAreRejected() {
        let connected = monitor(1, uuid: firstUUID)
        var saved = profile(for: connected)
        saved.requiredDisplays.append(OutputId(from: connected))
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: saved, monitors: [connected]))
        saved.requiredDisplays.removeLast()
        saved.assignments.append(saved.assignments[0])
        XCTAssertNotNil(DisplayProfileResolver.unavailableReason(for: saved, monitors: [connected]))
    }

    func testOverlayPreservesBaselineIdentityNamesLayoutsAndUnlistedWorkspaces() {
        let connected = monitor(1, uuid: firstUUID)
        let saved = profile(for: connected)
        let base = [
            WorkspaceConfiguration(name: "1", displayName: "Code", monitorAssignment: .main, layoutType: .dwindle),
            WorkspaceConfiguration(name: "2", monitorAssignment: .secondary, layoutType: .niri)
        ]
        let effective = DisplayProfileResolver.applying(saved, to: base)
        XCTAssertEqual(base[0].monitorAssignment, .main)
        XCTAssertEqual(effective[0].id, base[0].id)
        XCTAssertEqual(effective[0].name, base[0].name)
        XCTAssertEqual(effective[0].displayName, base[0].displayName)
        XCTAssertEqual(effective[0].layoutType, base[0].layoutType)
        XCTAssertEqual(effective[0].monitorAssignment, saved.assignments[0].monitorAssignment)
        XCTAssertEqual(effective[1], base[1])
        XCTAssertEqual(DisplayProfileResolver.applying(nil, to: base), base)
    }

    func testTOMLRoundTripAndOlderRoutingDefaults() throws {
        var export = SettingsExport.defaults()
        let saved = profile(for: monitor(1, uuid: firstUUID))
        export.routing.displayProfiles = [saved]
        export.routing.automaticProfilesEnabled = true
        export.routing.selectedDisplayProfileID = saved.id
        let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export))
        XCTAssertEqual(decoded, export)
        let defaults = try SettingsTOMLCodec.encode(.defaults())
        var tree = try TOMLDecoder().decode([String: TOMLNode].self, from: defaults)
        guard case var .table(routing) = tree["routing"] else { return XCTFail("Missing routing table") }
        routing.removeValue(forKey: "displayProfiles")
        routing.removeValue(forKey: "automaticProfilesEnabled")
        routing.removeValue(forKey: "selectedDisplayProfileID")
        tree["routing"] = .table(routing)
        let legacy = try SettingsTOMLCodec.decode(TOMLEncoder().encode(tree))
        XCTAssertTrue(legacy.routing.displayProfiles.isEmpty)
        XCTAssertFalse(legacy.routing.automaticProfilesEnabled)
        XCTAssertNil(legacy.routing.selectedDisplayProfileID)
    }

    func testUnknownProfileAndAssignmentKeysSurviveReorderAndEdit() throws {
        let connected = monitor(1, uuid: firstUUID)
        var export = SettingsExport.defaults()
        let saved = profile(for: connected)
        export.routing.displayProfiles = [saved, profile(for: connected, name: "Other")]
        var tree = try TOMLDecoder().decode([String: TOMLNode].self, from: SettingsTOMLCodec.encode(export))
        guard case var .table(routing) = tree["routing"],
              case var .array(profiles) = routing["displayProfiles"],
              case var .table(first) = profiles[0],
              case var .array(assignments) = first["assignments"],
              case var .table(assignment) = assignments[0],
              case var .array(outputs) = first["requiredDisplays"],
              case var .table(output) = outputs[0]
        else { return XCTFail("Missing profile tables") }
        first["profileExtension"] = .string("keep profile")
        assignment["assignmentExtension"] = .string("keep assignment")
        output["outputExtension"] = .string("keep output")
        assignments[0] = .table(assignment)
        outputs[0] = .table(output)
        first["assignments"] = .array(assignments)
        first["requiredDisplays"] = .array(outputs)
        profiles[0] = .table(first)
        routing["displayProfiles"] = .array(profiles)
        tree["routing"] = .table(routing)
        let previous = try TOMLEncoder().encode(tree)
        export.routing.displayProfiles[0].name = "Renamed"
        export.routing.displayProfiles[0].assignments[0].monitorAssignment = .main
        export.routing.displayProfiles.reverse()
        let updated = try SettingsTOMLCodec.encode(export, preservingUnknownKeysFrom: previous)
        let unknown = SettingsTOMLCodec.unknownKeyPaths(in: updated)
        XCTAssertTrue(unknown.contains { $0.hasSuffix("profileExtension") })
        XCTAssertTrue(unknown.contains { $0.hasSuffix("assignmentExtension") })
        XCTAssertTrue(unknown.contains { $0.hasSuffix("outputExtension") })
        XCTAssertEqual(try SettingsTOMLCodec.decode(updated), export)
    }
}

@MainActor
final class DisplayProfileRuntimeTests: XCTestCase {
    private func settings() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OmniWMProfiles-\(UUID().uuidString)")
        return SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config"), startWatching: false, deferSaves: false
            ),
            runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
            autosaveEnabled: false
        )
    }

    private func monitor(_ displayID: CGDirectDisplayID, x: CGFloat = 0) -> Monitor {
        let frame = CGRect(x: x, y: 0, width: 1920, height: 1080)
        return Monitor(
            id: .init(displayId: displayID), displayId: displayID,
            frame: frame, visibleFrame: frame, hasNotch: false, name: "Display \(displayID)"
        )
    }

    func testAutomaticTopologyTransitionsRestoreBaseAndAllowZeroWorkspacesOnBuiltIn() throws {
        let settings = settings()
        let builtIn = monitor(1)
        let external = monitor(2, x: 1920)
        let base = ["1", "2", "3"].map {
            WorkspaceConfiguration(name: $0, monitorAssignment: .specificDisplay(OutputId(from: builtIn)))
        }
        settings.workspaces.configurations = base
        settings.monitors.displayProfiles = [DisplayProfile(
            name: "Docked", requiredDisplays: [OutputId(from: external)],
            assignments: base.map {
                DisplayProfileAssignment(
                    workspaceName: $0.name,
                    monitorAssignment: .specificDisplay(OutputId(from: external))
                )
            }
        )]
        settings.monitors.automaticProfilesEnabled = true
        let manager = WorkspaceManager(settings: settings)
        manager.applyMonitorConfigurationChange([builtIn, external])
        XCTAssertTrue(manager.workspaces(on: builtIn.id).isEmpty)
        XCTAssertEqual(manager.workspaces(on: external.id).count, 3)
        XCTAssertNil(manager.visibleWorkspaceId(on: builtIn.id))
        XCTAssertEqual(manager.expectedVisibleMonitorIds(), [external.id])
        XCTAssertEqual(settings.workspaces.configurations, base)
        manager.applyMonitorConfigurationChange([builtIn])
        XCTAssertEqual(manager.workspaces(on: builtIn.id).count, 3)
        XCTAssertEqual(settings.workspaces.configurations, base)
        manager.applyMonitorConfigurationChange([builtIn, external])
        XCTAssertTrue(manager.workspaces(on: builtIn.id).isEmpty)
        XCTAssertEqual(manager.workspaces(on: external.id).count, 3)
    }

    func testInactiveProfileEditAndPausePreserveRuntimeWorkspaceMove() throws {
        let settings = settings()
        let first = monitor(1)
        let second = monitor(2, x: 1920)
        settings.workspaces.configurations = [
            WorkspaceConfiguration(name: "1", monitorAssignment: .specificDisplay(OutputId(from: first)))
        ]
        settings.monitors.displayProfiles = [first, second].map { display in
            DisplayProfile(name: display.name, requiredDisplays: [OutputId(from: display)], assignments: [
                DisplayProfileAssignment(
                    workspaceName: "1",
                    monitorAssignment: .specificDisplay(OutputId(from: display))
                )
            ])
        }
        settings.monitors.automaticProfilesEnabled = true
        let controller = WMController(settings: settings)
        let manager = controller.workspaceManager
        manager.applyMonitorConfigurationChange([first, second])
        let workspaceID = try XCTUnwrap(manager.workspaceId(named: "1"))
        XCTAssertEqual(manager.moveWorkspaceToMonitor(workspaceID, to: second.id, force: true).status, .executed)
        settings.monitors.displayProfiles[1].name = "Renamed inactive profile"
        controller.updateDisplayProfiles()
        XCTAssertNotNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
        controller.pauseAutomaticDisplayProfiles()
        XCTAssertNotNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
        XCTAssertFalse(settings.monitors.automaticProfilesEnabled)
        XCTAssertTrue(controller.applyDisplayProfile(id: settings.monitors.displayProfiles[0].id))
        XCTAssertNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, first.id)
    }

    func testProfileChangeDefersNativeFullscreenWithoutExistingOverride() throws {
        let settings = settings()
        let first = monitor(1)
        let second = monitor(2, x: 1920)
        settings.workspaces.configurations = [
            WorkspaceConfiguration(name: "1", monitorAssignment: .specificDisplay(OutputId(from: first)))
        ]
        settings.monitors.displayProfiles = [DisplayProfile(
            name: "External", requiredDisplays: [OutputId(from: second)], assignments: [
                DisplayProfileAssignment(
                    workspaceName: "1",
                    monitorAssignment: .specificDisplay(OutputId(from: second))
                )
            ]
        )]
        let manager = WorkspaceManager(settings: settings)
        manager.applyMonitorConfigurationChange([first, second])
        let workspaceID = try XCTUnwrap(manager.workspaceId(named: "1"))
        let token = manager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(975001), windowId: 975101),
            pid: 975001, windowId: 975101, to: workspaceID, mode: .tiling
        )
        XCTAssertNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertTrue(manager.markNativeFullscreenSuspended(token, ownsNativeFocus: false))
        settings.monitors.automaticProfilesEnabled = true
        manager.applySettings()
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, first.id)
        XCTAssertNotNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertTrue(manager.pendingRuntimeMonitorOverrideClearWorkspaceIds.contains(workspaceID))
        XCTAssertTrue(manager.restoreNativeFullscreenRecord(for: token))
        XCTAssertNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
    }

    func testProfileChangeDefersFullscreenOnFallbackForDisconnectedBaseHome() throws {
        let settings = settings()
        let first = monitor(700001)
        let second = monitor(700002, x: 1920)
        let absent = monitor(700003, x: 3840)
        settings.workspaces.configurations = [
            WorkspaceConfiguration(name: "1", monitorAssignment: .specificDisplay(OutputId(from: absent)))
        ]
        settings.monitors.displayProfiles = [DisplayProfile(
            name: "External", requiredDisplays: [OutputId(from: second)], assignments: [
                DisplayProfileAssignment(
                    workspaceName: "1",
                    monitorAssignment: .specificDisplay(OutputId(from: second))
                )
            ]
        )]
        let manager = WorkspaceManager(settings: settings)
        manager.applyMonitorConfigurationChange([first, second])
        let workspaceID = try XCTUnwrap(manager.workspaceId(named: "1"))
        manager.updateWorkspace(workspaceID) { $0.assignedMonitorPoint = first.workspaceAnchorPoint }
        manager.ensureVisibleWorkspaces()
        let token = manager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(975003), windowId: 975103),
            pid: 975003, windowId: 975103, to: workspaceID, mode: .tiling
        )
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, first.id)
        XCTAssertTrue(manager.markNativeFullscreenSuspended(token, ownsNativeFocus: false))
        settings.monitors.automaticProfilesEnabled = true
        manager.applySettings()
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, first.id)
        XCTAssertTrue(manager.pendingRuntimeMonitorOverrideClearWorkspaceIds.contains(workspaceID))
        XCTAssertTrue(manager.restoreNativeFullscreenRecord(for: token))
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
    }

    func testSecondaryRoleChangeDefersFullscreenBeforeTopologyCommit() throws {
        let settings = settings()
        let first = monitor(700001)
        let second = monitor(700002, x: 1920)
        let inserted = monitor(700003, x: 960)
        settings.workspaces.configurations = [WorkspaceConfiguration(name: "1", monitorAssignment: .main)]
        settings.monitors.displayProfiles = [DisplayProfile(
            name: "Secondary", requiredDisplays: [OutputId(from: first)], assignments: [
                DisplayProfileAssignment(workspaceName: "1", monitorAssignment: .secondary)
            ]
        )]
        settings.monitors.automaticProfilesEnabled = true
        let manager = WorkspaceManager(settings: settings)
        manager.applyMonitorConfigurationChange([first, second])
        let workspaceID = try XCTUnwrap(manager.workspaceId(named: "1"))
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
        let token = manager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(975002), windowId: 975102),
            pid: 975002, windowId: 975102, to: workspaceID, mode: .tiling
        )
        XCTAssertTrue(manager.markNativeFullscreenSuspended(token, ownsNativeFocus: false))
        manager.applyMonitorConfigurationChange([first, inserted, second])
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, second.id)
        XCTAssertTrue(manager.pendingRuntimeMonitorOverrideClearWorkspaceIds.contains(workspaceID))
        XCTAssertTrue(manager.restoreNativeFullscreenRecord(for: token))
        XCTAssertEqual(manager.monitorForWorkspace(workspaceID)?.id, inserted.id)
        XCTAssertNil(manager.descriptor(for: workspaceID)?.runtimeMonitorOverride)
    }

    func testManualSelectionAndResumeUseSameOverlay() throws {
        let settings = settings()
        let first = monitor(1)
        let second = monitor(2, x: 1920)
        settings.workspaces.configurations = [WorkspaceConfiguration(name: "1")]
        settings.monitors.displayProfiles = [first, second].map { display in
            DisplayProfile(name: display.name, requiredDisplays: [OutputId(from: display)], assignments: [
                DisplayProfileAssignment(
                    workspaceName: "1",
                    monitorAssignment: .specificDisplay(OutputId(from: display))
                )
            ])
        }
        let manager = WorkspaceManager(settings: settings)
        manager.applyMonitorConfigurationChange([first, second])
        settings.monitors.selectedDisplayProfileID = settings.monitors.displayProfiles[1].id
        manager.applySettings()
        XCTAssertEqual(manager.workspaces(on: second.id).count, 1)
        settings.monitors.automaticProfilesEnabled = true
        manager.applySettings()
        XCTAssertEqual(manager.workspaces(on: first.id).count, 1)
        settings.monitors.displayProfiles[0].assignments[0].monitorAssignment = .specificDisplay(OutputId(from: second))
        manager.applySettings()
        XCTAssertEqual(manager.workspaces(on: second.id).count, 1)
        manager.applyMonitorConfigurationChange([first, second, monitor(3, x: 3840)])
        XCTAssertEqual(manager.workspaces(on: second.id).count, 1)
        XCTAssertTrue(manager.workspaces(on: first.id).isEmpty)
        settings.monitors.displayProfiles.removeFirst()
        manager.applySettings()
        XCTAssertEqual(manager.workspaces(on: second.id).count, 1)
        settings.monitors.displayProfiles.removeAll()
        manager.applySettings()
        XCTAssertEqual(settings.workspaces.configurations[0].monitorAssignment, .main)
    }
}
