@testable import OmniWM
import XCTest

final class ViewportStateConflictTests: XCTestCase {
    private func state(
        selectedNodeId: NodeId? = nil,
        selectionRevision: UInt64 = 0,
        activeColumnIndex: Int = 0,
        selectionProgress: CGFloat = 0,
        viewOffsetPixels: ViewOffset = .static(0)
    ) -> ViewportState {
        var state = ViewportState()
        state.selectedNodeId = selectedNodeId
        state.selectionRevision = selectionRevision
        state.activeColumnIndex = activeColumnIndex
        state.selectionProgress = selectionProgress
        state.viewOffsetPixels = viewOffsetPixels
        return state
    }

    private func spring(to target: Double = 100) -> SpringAnimation {
        SpringAnimation(from: 0, to: target, startTime: 1.0)
    }

    func testAdoptSelectionRevisionBumpsPastCurrentWhenSelectionChanged() {
        var next = state(selectedNodeId: NodeId(), selectionRevision: 0)
        next.adoptSelectionRevision(from: state(selectedNodeId: NodeId(), selectionRevision: 5))
        XCTAssertEqual(next.selectionRevision, 6)
    }

    func testAdoptSelectionRevisionKeepsHigherLocalRevisionWhenSelectionChanged() {
        var next = state(selectedNodeId: NodeId(), selectionRevision: 10)
        next.adoptSelectionRevision(from: state(selectedNodeId: NodeId(), selectionRevision: 5))
        XCTAssertEqual(next.selectionRevision, 10)
    }

    func testAdoptSelectionRevisionAdoptsCurrentRevisionWhenSelectionUnchanged() {
        let nodeId = NodeId()
        var next = state(selectedNodeId: nodeId, selectionRevision: 0)
        next.adoptSelectionRevision(from: state(selectedNodeId: nodeId, selectionRevision: 5))
        XCTAssertEqual(next.selectionRevision, 5)
    }

    func testAdoptSelectionRevisionEstablishesBaselineWithoutCurrent() {
        var next = state(selectedNodeId: NodeId(), selectionRevision: 0)
        next.adoptSelectionRevision(from: nil)
        XCTAssertEqual(next.selectionRevision, 1)

        var higher = state(selectedNodeId: NodeId(), selectionRevision: 7)
        higher.adoptSelectionRevision(from: nil)
        XCTAssertEqual(higher.selectionRevision, 7)
    }

    func testAdoptSelectionRevisionLeavesRevisionWithoutCurrentOrSelection() {
        var next = state(selectedNodeId: nil, selectionRevision: 0)
        next.adoptSelectionRevision(from: nil)
        XCTAssertEqual(next.selectionRevision, 0)
    }

    func testResolveCommitConflictsRebasesSelectionOntoCurrentWhenBaseIsStale() {
        let currentNodeId = NodeId()
        let current = state(
            selectedNodeId: currentNodeId,
            selectionRevision: 3,
            activeColumnIndex: 4,
            selectionProgress: 0.5
        )
        var next = state(
            selectedNodeId: NodeId(),
            selectionRevision: 2,
            activeColumnIndex: 1,
            selectionProgress: 0.25,
            viewOffsetPixels: .static(42)
        )
        next.resolveCommitConflicts(against: current, baseSelectionRevision: 1)
        XCTAssertEqual(next.selectedNodeId, currentNodeId)
        XCTAssertEqual(next.activeColumnIndex, 4)
        XCTAssertEqual(next.selectionProgress, 0.5)
        XCTAssertEqual(next.selectionRevision, 3)
        XCTAssertEqual(next.viewOffsetPixels, .static(42))
    }

    func testResolveCommitConflictsPreservesLocalSelectionWhenBaseIsCurrent() {
        let localNodeId = NodeId()
        let current = state(selectedNodeId: NodeId(), selectionRevision: 3, activeColumnIndex: 4)
        var next = state(selectedNodeId: localNodeId, selectionRevision: 4, activeColumnIndex: 1)
        next.resolveCommitConflicts(against: current, baseSelectionRevision: 3)
        XCTAssertEqual(next.selectedNodeId, localNodeId)
        XCTAssertEqual(next.activeColumnIndex, 1)
        XCTAssertEqual(next.selectionRevision, 4)
    }

    func testResolveCommitConflictsPreservesLocalSelectionWithoutBaseRevision() {
        let localNodeId = NodeId()
        let current = state(selectedNodeId: NodeId(), selectionRevision: 9, activeColumnIndex: 4)
        var next = state(selectedNodeId: localNodeId, selectionRevision: 2, activeColumnIndex: 1)
        next.resolveCommitConflicts(against: current, baseSelectionRevision: nil)
        XCTAssertEqual(next.selectedNodeId, localNodeId)
        XCTAssertEqual(next.activeColumnIndex, 1)
        XCTAssertEqual(next.selectionRevision, 2)
    }

    func testResolveCommitConflictsReplacesLocalGestureWithCurrentSpring() {
        let animation = spring()
        let current = state(activeColumnIndex: 6, viewOffsetPixels: .spring(animation))
        var next = state(
            activeColumnIndex: 1,
            viewOffsetPixels: .gesture(ViewGesture(currentViewOffset: 10, isTrackpad: true))
        )
        next.resolveCommitConflicts(against: current, baseSelectionRevision: nil)
        XCTAssertEqual(next.viewOffsetPixels, .spring(animation))
        XCTAssertEqual(next.activeColumnIndex, 6)
    }

    func testResolveCommitConflictsKeepsLocalGestureWhenCurrentIsNotSpring() {
        let gesture = ViewGesture(currentViewOffset: 10, isTrackpad: true)
        let current = state(activeColumnIndex: 6, viewOffsetPixels: .static(80))
        var next = state(activeColumnIndex: 1, viewOffsetPixels: .gesture(gesture))
        next.resolveCommitConflicts(against: current, baseSelectionRevision: nil)
        XCTAssertEqual(next.viewOffsetPixels, .gesture(gesture))
        XCTAssertEqual(next.activeColumnIndex, 1)
    }

    func testResolveCommitConflictsKeepsLocalSpringOverCurrentSpring() {
        let localAnimation = spring(to: 50)
        let current = state(activeColumnIndex: 6, viewOffsetPixels: .spring(spring(to: 200)))
        var next = state(activeColumnIndex: 1, viewOffsetPixels: .spring(localAnimation))
        next.resolveCommitConflicts(against: current, baseSelectionRevision: nil)
        XCTAssertEqual(next.viewOffsetPixels, .spring(localAnimation))
        XCTAssertEqual(next.activeColumnIndex, 1)
    }

    func testResolveCommitConflictsAppliesStaleRebaseAndSpringAdoptionTogether() {
        let currentNodeId = NodeId()
        let animation = spring()
        let current = state(
            selectedNodeId: currentNodeId,
            selectionRevision: 8,
            activeColumnIndex: 3,
            selectionProgress: 1.0,
            viewOffsetPixels: .spring(animation)
        )
        var next = state(
            selectedNodeId: NodeId(),
            selectionRevision: 5,
            activeColumnIndex: 0,
            viewOffsetPixels: .gesture(ViewGesture(currentViewOffset: 0, isTrackpad: false))
        )
        next.resolveCommitConflicts(against: current, baseSelectionRevision: 5)
        XCTAssertEqual(next.selectedNodeId, currentNodeId)
        XCTAssertEqual(next.selectionRevision, 8)
        XCTAssertEqual(next.viewOffsetPixels, .spring(animation))
        XCTAssertEqual(next.activeColumnIndex, 3)
    }
}
