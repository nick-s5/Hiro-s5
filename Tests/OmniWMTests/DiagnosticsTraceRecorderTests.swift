// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation
@testable import OmniWM
import OmniWMIPC
import XCTest

final class DiagnosticsTraceRecorderTests: XCTestCase {
    func testSessionTraceRecorderGatingEvictionAndReset() {
        let recorder = SessionTraceRecorder<Int>(sectionTitle: "Nums", capacity: 3) { "\($0)" }

        recorder.record(1)
        XCTAssertEqual(recorder.dump(), "none", "records dropped while capture inactive")

        recorder.beginCapture()
        recorder.record(1)
        recorder.record(2)
        recorder.record(3)
        recorder.record(4)
        XCTAssertEqual(recorder.dump(), "2\n3\n4", "ring evicts oldest beyond capacity")

        recorder.endCapture()
        recorder.record(5)
        XCTAssertEqual(recorder.dump(), "2\n3\n4", "records dropped after capture ends")

        recorder.beginCapture()
        XCTAssertEqual(recorder.dump(), "none", "beginCapture resets the ring")
    }

    func testSessionTraceRecorderDoesNotEvaluateWhenInactive() {
        let recorder = SessionTraceRecorder<Int>(sectionTitle: "Nums", capacity: 4) { "\($0)" }
        var evaluations = 0
        let make: () -> Int = {
            evaluations += 1
            return 7
        }

        recorder.record(make())
        XCTAssertEqual(evaluations, 0, "autoclosure must not run while inactive")

        recorder.beginCapture()
        recorder.record(make())
        XCTAssertEqual(evaluations, 1)
    }

    func testLogErrorTapCapturesOnlyErrorAndFault() {
        LogErrorTap.shared.reset()

        Log.config.error("boom-error")
        Log.terminal.fault("boom-fault")
        Log.layout.debug("boom-debug")
        Log.ax.info("boom-info")
        Log.ipc.notice("boom-notice")

        let dump = LogErrorTap.shared.dump()
        XCTAssertTrue(dump.contains("boom-error"))
        XCTAssertTrue(dump.contains("boom-fault"))
        XCTAssertFalse(dump.contains("boom-debug"))
        XCTAssertFalse(dump.contains("boom-info"))
        XCTAssertFalse(dump.contains("boom-notice"))
        XCTAssertTrue(dump.contains("[error] config"))
        XCTAssertTrue(dump.contains("[fault] terminal"))

        LogErrorTap.shared.reset()
        XCTAssertEqual(LogErrorTap.shared.dump(), "none")
    }

    @MainActor
    func testCaptureCoordinatorTogglesDomainRecorders() {
        RawAXNotificationTrace.record(name: "ax.before", pid: 1, windowId: nil)
        XCTAssertFalse(RawAXNotificationTrace.shared.dump().contains("ax.before"))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMTraceRecorder-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = RuntimeTraceCaptureCoordinator(diagnosticsDirectory: directory)
        let startOutcome = coordinator.toggle(desiredState: .active) { "report" }
        guard case .started = startOutcome else {
            return XCTFail("expected capture to start")
        }

        RawAXNotificationTrace.record(name: "ax.during", pid: 7, windowId: 42)
        NiriLayoutTrace.record(.viewport, workspaceId: nil, "jump 0→10 col=0")
        XCTAssertTrue(RawAXNotificationTrace.shared.dump().contains("ax.during"))
        XCTAssertTrue(NiriLayoutTrace.shared.dump().contains("jump 0→10"))

        let outcome = coordinator.toggle(desiredState: .inactive) { "report" }
        guard case let .stopped(artifact) = outcome else {
            return XCTFail("expected capture to stop with an artifact")
        }
        let body = (try? String(contentsOf: artifact.url, encoding: .utf8)) ?? ""
        XCTAssertTrue(body.contains("== Raw AX Notifications =="))
        XCTAssertTrue(body.contains("== Niri Layout Trace =="))
        XCTAssertTrue(body.contains("== Frame Apply Trace =="))
        XCTAssertTrue(body.contains("== Mouse Trace =="))
        try? FileManager.default.removeItem(at: artifact.url)

        RawAXNotificationTrace.record(name: "ax.after", pid: 1, windowId: nil)
        XCTAssertFalse(RawAXNotificationTrace.shared.dump().contains("ax.after"))
    }
}
