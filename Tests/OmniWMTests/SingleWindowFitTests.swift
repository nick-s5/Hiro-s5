import CoreGraphics
import Foundation
@testable import OmniWM
import XCTest

final class SingleWindowFitTests: XCTestCase {
    func testDefaultIsFullScreen() {
        XCTAssertEqual(SingleWindowFit().mode, .fill)
        XCTAssertEqual(SingleWindowFit.fullScreen.mode, .fill)
    }

    func testSerializedRoundTrips() {
        XCTAssertEqual(SingleWindowFit(mode: .fill).serialized, "fill")
        XCTAssertEqual(SingleWindowFit(mode: .columnWidth).serialized, "column_width")
        XCTAssertEqual(SingleWindowFit(mode: .custom, width: 1920, height: 1080).serialized, "1920x1080")
        XCTAssertEqual(SingleWindowFit(mode: .custom, width: 1600, height: 900).serialized, "1600x900")
    }

    func testDecodeNewFormats() {
        XCTAssertEqual(SingleWindowFit(serialized: "fill"), SingleWindowFit(mode: .fill))
        XCTAssertEqual(SingleWindowFit(serialized: "column_width"), SingleWindowFit(mode: .columnWidth))
        XCTAssertEqual(
            SingleWindowFit(serialized: "1920x1080"),
            SingleWindowFit(mode: .custom, width: 1920, height: 1080)
        )
        XCTAssertEqual(
            SingleWindowFit(serialized: " 1600X900 "),
            SingleWindowFit(mode: .custom, width: 1600, height: 900)
        )
    }

    func testMigratesLegacyDwindleAndNiriValues() {
        XCTAssertEqual(SingleWindowFit(serialized: "none").mode, .fill)
        XCTAssertEqual(SingleWindowFit(serialized: "16:9"), SingleWindowFit(mode: .custom, width: 1920, height: 1080))
        XCTAssertEqual(SingleWindowFit(serialized: "4:3"), SingleWindowFit(mode: .custom, width: 1440, height: 1080))
        XCTAssertEqual(SingleWindowFit(serialized: "21:9"), SingleWindowFit(mode: .custom, width: 2520, height: 1080))
        XCTAssertEqual(SingleWindowFit(serialized: "3:2"), SingleWindowFit(mode: .custom, width: 1620, height: 1080))
        XCTAssertEqual(SingleWindowFit(serialized: "1:1"), SingleWindowFit(mode: .custom, width: 1080, height: 1080))
    }

    func testDecodeGarbageFallsBackToFullScreen() {
        XCTAssertEqual(SingleWindowFit(serialized: "").mode, .fill)
        XCTAssertEqual(SingleWindowFit(serialized: "wat").mode, .fill)
        XCTAssertEqual(SingleWindowFit(serialized: "0x0").mode, .fill)
        XCTAssertEqual(SingleWindowFit(serialized: "-5x100").mode, .fill)
        XCTAssertEqual(SingleWindowFit(serialized: "ax9").mode, .fill)
    }

    func testFrameFillReturnsWorkingFrame() {
        let working = CGRect(x: 100, y: 50, width: 2000, height: 1200)
        XCTAssertEqual(SingleWindowFit(mode: .fill).frame(in: working), working)
        XCTAssertEqual(SingleWindowFit(mode: .columnWidth).frame(in: working), working)
    }

    func testFrameCustomCentersWhenSmaller() {
        let working = CGRect(x: 100, y: 50, width: 2000, height: 1200)
        let frame = SingleWindowFit(mode: .custom, width: 1920, height: 1080).frame(in: working)
        XCTAssertEqual(frame, CGRect(x: 140, y: 110, width: 1920, height: 1080))
    }

    func testFrameCustomClampsWhenLarger() {
        let working = CGRect(x: 100, y: 50, width: 2000, height: 1200)
        let frame = SingleWindowFit(mode: .custom, width: 3000, height: 1500).frame(in: working)
        XCTAssertEqual(frame, working)
    }

    func testFrameCustomInvalidSizeFallsBackToWorkingFrame() {
        let working = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(SingleWindowFit(mode: .custom, width: 0, height: 1080).frame(in: working), working)
        XCTAssertEqual(SingleWindowFit(mode: .custom, width: 1920, height: -1).frame(in: working), working)
    }
}

final class DwindleSingleWindowFitEngineTests: XCTestCase {
    private struct Fixture {
        let engine: DwindleLayoutEngine
        let workspaceId: WorkspaceDescriptor.ID
        let token: WindowToken
    }

    private func makeSingleWindowFixture() -> Fixture {
        let engine = DwindleLayoutEngine()
        let workspaceId = WorkspaceDescriptor.ID()
        let token = WindowToken(pid: 1, windowId: 1)
        _ = engine.addWindow(token: token, to: workspaceId, activeWindowFrame: nil)
        return Fixture(engine: engine, workspaceId: workspaceId, token: token)
    }

    func testFullScreenFillsTheScreen() {
        let fixture = makeSingleWindowFixture()
        fixture.engine.settings.singleWindowFit = SingleWindowFit(mode: .fill)
        let screen = CGRect(x: 0, y: 0, width: 2560, height: 1440)

        let frame = fixture.engine.calculateLayout(for: fixture.workspaceId, screen: screen)[fixture.token]

        XCTAssertEqual(frame, screen)
    }

    func testCustomSizeIsCenteredAndFinite() {
        let fixture = makeSingleWindowFixture()
        fixture.engine.settings.singleWindowFit = SingleWindowFit(mode: .custom, width: 1920, height: 1080)
        let screen = CGRect(x: 0, y: 0, width: 2560, height: 1440)

        let frame = fixture.engine.calculateLayout(for: fixture.workspaceId, screen: screen)[fixture.token]

        XCTAssertEqual(frame, CGRect(x: 320, y: 180, width: 1920, height: 1080))
        XCTAssertEqual(frame?.height.isFinite, true)
    }
}
