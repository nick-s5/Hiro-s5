import Carbon
import CoreGraphics
@testable import OmniWM
import XCTest

final class HotkeyChordTests: XCTestCase {
    func testHotkeyTriggerRejectsSequenceText() {
        XCTAssertNil(HotkeyTrigger.fromHumanReadable("Option+A, B"))
        XCTAssertNil(HotkeyTrigger.fromHumanReadable("Leader, A"))
    }

    func testHotkeyTriggerRoundTripsChordEncoding() throws {
        let trigger = HotkeyTrigger.chord(KeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)))
        let data = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(HotkeyTrigger.self, from: data)

        XCTAssertEqual(decoded, trigger)
    }

    func testChordConflictDetectionUsesOnlyChordBindings() {
        let lhs = HotkeyTrigger.chord(KeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)))
        let same = HotkeyTrigger.chord(KeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey)))
        let different = HotkeyTrigger.chord(KeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(optionKey)))

        XCTAssertTrue(lhs.conflicts(with: same, hyperTrigger: .default))
        XCTAssertFalse(lhs.conflicts(with: different, hyperTrigger: .default))
        XCTAssertFalse(lhs.conflicts(with: .unassigned, hyperTrigger: .default))
    }

    func testRegistrationPlanMarksDuplicateChordBindings() {
        let binding = KeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey))
        let bindings = [
            HotkeyBinding(id: "focus.left", command: .focus(.left), binding: binding),
            HotkeyBinding(id: "focus.right", command: .focus(.right), binding: binding)
        ]

        let plan = HotkeyCenter.registrationPlan(for: bindings)

        XCTAssertEqual(plan.failures[.focus(.left)], .duplicateBinding)
        XCTAssertEqual(plan.failures[.focus(.right)], .duplicateBinding)
        XCTAssertTrue(plan.registrations.isEmpty)
        XCTAssertTrue(plan.virtualHyperRegistrations.isEmpty)
    }

    func testRegistrationPlanMarksPhysicalHyperTriggerConflict() {
        let binding = KeyBinding(keyCode: UInt32(kVK_CapsLock), modifiers: 0)
        let bindings = [
            HotkeyBinding(id: "focus.left", command: .focus(.left), binding: binding)
        ]

        let plan = HotkeyCenter.registrationPlan(
            for: bindings,
            hyperTrigger: .key(UInt32(kVK_CapsLock))
        )

        XCTAssertEqual(plan.failures[.focus(.left)], .hyperTriggerConflict)
        XCTAssertTrue(plan.registrations.isEmpty)
        XCTAssertTrue(plan.virtualHyperRegistrations.isEmpty)
    }

    func testRegistrationPlanProducesDirectAndVirtualHyperRegistrations() {
        let directBinding = KeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey))
        let hyperBinding = KeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: 0, usesHyper: true)
        let bindings = [
            HotkeyBinding(id: "focus.left", command: .focus(.left), binding: directBinding),
            HotkeyBinding(id: "focus.right", command: .focus(.right), binding: hyperBinding)
        ]

        let plan = HotkeyCenter.registrationPlan(
            for: bindings,
            hyperTrigger: .key(UInt32(kVK_CapsLock))
        )

        XCTAssertEqual(
            plan.registrations,
            [HotkeyPlannedRegistration(binding: directBinding, command: .focus(.left))]
        )
        XCTAssertEqual(
            plan.virtualHyperRegistrations,
            [HotkeyPlannedRegistration(binding: hyperBinding, command: .focus(.right))]
        )
        XCTAssertTrue(plan.failures.isEmpty)
    }

    func testRegistrationPlanRoutesSideSpecificModifierHyperThroughEventTap() {
        let hyperBinding = KeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: 0, usesHyper: true)
        let bindings = [
            HotkeyBinding(id: "focus.right", command: .focus(.right), binding: hyperBinding)
        ]

        let plan = HotkeyCenter.registrationPlan(
            for: bindings,
            hyperTrigger: .key(UInt32(kVK_RightOption))
        )

        XCTAssertTrue(plan.registrations.isEmpty)
        XCTAssertEqual(
            plan.virtualHyperRegistrations,
            [HotkeyPlannedRegistration(binding: hyperBinding, command: .focus(.right))]
        )
        XCTAssertTrue(plan.failures.isEmpty)
    }

    func testRegistrationPlanMapsSystemHyperToRealFourModifierChord() {
        let hyperBinding = KeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: 0, usesHyper: true)
        let bindings = [
            HotkeyBinding(id: "focus.right", command: .focus(.right), binding: hyperBinding)
        ]

        let plan = HotkeyCenter.registrationPlan(for: bindings, hyperTrigger: .system)

        XCTAssertEqual(
            plan.registrations,
            [
                HotkeyPlannedRegistration(
                    binding: KeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: KeySymbolMapper.hyperModifiers),
                    command: .focus(.right)
                )
            ]
        )
        XCTAssertTrue(plan.virtualHyperRegistrations.isEmpty)
        XCTAssertTrue(plan.failures.isEmpty)
    }

    func testSideSpecificHyperTriggerConflictsOnlyWithMatchingSide() {
        let leftOptionBinding = KeyBinding(keyCode: UInt32(kVK_Option), modifiers: 0)
        let rightOptionBinding = KeyBinding(keyCode: UInt32(kVK_RightOption), modifiers: 0)
        let bindings = [
            HotkeyBinding(id: "focus.left", command: .focus(.left), binding: leftOptionBinding),
            HotkeyBinding(id: "focus.right", command: .focus(.right), binding: rightOptionBinding)
        ]

        let plan = HotkeyCenter.registrationPlan(
            for: bindings,
            hyperTrigger: .key(UInt32(kVK_RightOption))
        )

        XCTAssertNil(plan.failures[.focus(.left)])
        XCTAssertEqual(plan.failures[.focus(.right)], .hyperTriggerConflict)
    }

    func testHyperTriggerEncodingUsesSideSpecificModifierNames() throws {
        let data = try JSONEncoder().encode(HyperKeyTrigger.default)
        let encoded = String(decoding: data, as: UTF8.self)
        let decoded = try JSONDecoder().decode(HyperKeyTrigger.self, from: data)

        XCTAssertEqual(encoded, #""Left Option""#)
        XCTAssertEqual(decoded, .key(UInt32(kVK_Option)))
    }

    func testCapsLockHyperMappingPreservesUnrelatedMappingsWhenApplying() {
        let unrelated = HIDKeyboardModifierMapping(source: 100, destination: 200)
        let existingCapsLock = HIDKeyboardModifierMapping(
            source: CapsLockHyperMapping.capsLockSource,
            destination: 300
        )

        let mappings = CapsLockHyperMapping.applying(to: [unrelated, existingCapsLock])

        XCTAssertEqual(mappings, [unrelated, CapsLockHyperMapping.omniMapping])
    }

    func testCapsLockHyperMappingRestoresOnlyOmniMapping() {
        let unrelated = HIDKeyboardModifierMapping(source: 100, destination: 200)
        let originalCapsLock = HIDKeyboardModifierMapping(
            source: CapsLockHyperMapping.capsLockSource,
            destination: 300
        )

        let mappings = CapsLockHyperMapping.restoring(
            current: [unrelated, CapsLockHyperMapping.omniMapping],
            original: [originalCapsLock]
        )

        XCTAssertEqual(mappings, [unrelated, originalCapsLock])
    }

    func testCapsLockHyperMappingKeepsExternalCapsLockChangeOnRestore() {
        let externalCapsLock = HIDKeyboardModifierMapping(
            source: CapsLockHyperMapping.capsLockSource,
            destination: 400
        )

        let mappings = CapsLockHyperMapping.restoring(
            current: [CapsLockHyperMapping.omniMapping, externalCapsLock],
            original: []
        )

        XCTAssertEqual(mappings, [externalCapsLock])
    }

    func testVirtualHyperStateDispatchesAndConsumesMatchedCombo() {
        var state = VirtualHyperEventState()
        let trigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertEqual(state.handleTriggerKeyDown(UInt32(kVK_ANSI_H), trigger: trigger), true)
        XCTAssertEqual(
            state.handleKeyDown(
                keyCode: UInt32(kVK_ANSI_J),
                isAutorepeat: false,
                trigger: trigger,
                command: .focus(.down)
            ),
            .dispatch(.focus(.down))
        )
        XCTAssertEqual(state.handleTriggerKeyUp(UInt32(kVK_ANSI_J), trigger: trigger), true)
    }

    func testVirtualHyperStatePassesThroughUnmatchedCombo() {
        var state = VirtualHyperEventState()
        let trigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertEqual(state.handleTriggerKeyDown(UInt32(kVK_ANSI_H), trigger: trigger), true)
        XCTAssertEqual(
            state.handleKeyDown(
                keyCode: UInt32(kVK_ANSI_J),
                isAutorepeat: false,
                trigger: trigger,
                command: nil
            ),
            .passThrough
        )
        XCTAssertEqual(state.handleTriggerKeyUp(UInt32(kVK_ANSI_J), trigger: trigger), false)
    }

    func testVirtualHyperStateSupportsQuickTapCancellation() {
        var state = VirtualHyperEventState()
        let trigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertEqual(state.beginPendingKeyDown(UInt32(kVK_ANSI_H), trigger: trigger), true)
        XCTAssertEqual(state.pendingKeyMatches(UInt32(kVK_ANSI_H), trigger: trigger), true)
        XCTAssertEqual(state.cancelPending(), true)
        XCTAssertEqual(state.isPending, false)
    }

    func testVirtualHyperStateDormantTracksActivePendingAndConsumedInputs() {
        var state = VirtualHyperEventState()
        let trigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertTrue(state.isDormant)

        XCTAssertEqual(state.handleTriggerKeyDown(UInt32(kVK_ANSI_H), trigger: trigger), true)
        XCTAssertFalse(state.isDormant)

        state.reset()
        XCTAssertTrue(state.beginPendingKeyDown(UInt32(kVK_ANSI_H), trigger: trigger))
        XCTAssertFalse(state.isDormant)

        XCTAssertTrue(state.cancelPending())
        XCTAssertTrue(state.isDormant)

        state.consumeKeyCode(UInt32(kVK_ANSI_J))
        XCTAssertFalse(state.isDormant)

        state.reset()
        state.consumedMouseButtons.insert(3)
        XCTAssertFalse(state.isDormant)
    }

    func testVirtualHyperStateConsumedKeyKeepsDormantFastPathDisabledUntilKeyUp() {
        var state = VirtualHyperEventState()
        let trigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        state.consumeKeyCode(UInt32(kVK_ANSI_J))

        XCTAssertFalse(state.isDormant)
        XCTAssertEqual(state.handleTriggerKeyUp(UInt32(kVK_ANSI_J), trigger: trigger), true)
        XCTAssertTrue(state.isDormant)
    }

    func testDormantVirtualHyperPredicateHandlesTriggerEvents() {
        let keyTrigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyDown,
                keyCode: UInt32(kVK_ANSI_H),
                trigger: keyTrigger
            )
        )
        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyUp,
                keyCode: UInt32(kVK_ANSI_H),
                trigger: keyTrigger
            )
        )
        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .flagsChanged,
                keyCode: UInt32(kVK_ANSI_H),
                trigger: keyTrigger
            )
        )

        let mouseTrigger = HyperKeyTrigger.mouseButton(4)

        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .otherMouseDown,
                mouseButton: 4,
                trigger: mouseTrigger
            )
        )
        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .otherMouseUp,
                mouseButton: 4,
                trigger: mouseTrigger
            )
        )
    }

    func testDormantVirtualHyperPredicateSkipsNonTriggerEvents() {
        let keyTrigger = HyperKeyTrigger.key(UInt32(kVK_ANSI_H))

        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyDown,
                keyCode: UInt32(kVK_ANSI_J),
                trigger: keyTrigger
            )
        )
        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyUp,
                keyCode: UInt32(kVK_ANSI_J),
                trigger: keyTrigger
            )
        )
        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .flagsChanged,
                keyCode: UInt32(kVK_ANSI_J),
                trigger: keyTrigger
            )
        )

        let mouseTrigger = HyperKeyTrigger.mouseButton(4)

        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .otherMouseDown,
                mouseButton: 5,
                trigger: mouseTrigger
            )
        )
        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .otherMouseUp,
                mouseButton: 5,
                trigger: mouseTrigger
            )
        )
    }

    func testDormantVirtualHyperPredicateUsesEffectiveCapsLockRemapTrigger() {
        let remappedTrigger = HyperKeyTrigger.key(CapsLockHyperMapping.f18KeyCode)

        XCTAssertTrue(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyDown,
                keyCode: CapsLockHyperMapping.f18KeyCode,
                trigger: remappedTrigger
            )
        )
        XCTAssertFalse(
            HotkeyCenter.dormantEventMatchesHyperTrigger(
                type: .keyDown,
                keyCode: UInt32(kVK_CapsLock),
                trigger: remappedTrigger
            )
        )
    }

    func testSettingsTOMLDoesNotEmitLeaderOrSequenceTimeout() throws {
        let data = try SettingsTOMLCodec.encode(.defaults())
        let toml = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(toml.contains("leaderKey"))
        XCTAssertFalse(toml.contains("sequenceTimeoutMilliseconds"))
    }
}
