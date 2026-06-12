@testable import OmniWM
import XCTest

final class ViewportStateConflictTests: XCTestCase {
    private func state(
        selectedNodeId: NodeId? = nil,
        activeColumnIndex: Int = 0,
        selectionProgress: CGFloat = 0,
        viewOffset: CGFloat = 0
    ) -> ViewportState {
        var state = ViewportState()
        state.selectedNodeId = selectedNodeId
        state.activeColumnIndex = activeColumnIndex
        state.selectionProgress = selectionProgress
        state.viewOffset = viewOffset
        return state
    }

    func testResolveCommitConflictsRebasesSelectionOntoCurrentWhenStale() {
        let currentNodeId = NodeId()
        let current = state(
            selectedNodeId: currentNodeId,
            activeColumnIndex: 4,
            selectionProgress: 0.5
        )
        var next = state(
            selectedNodeId: NodeId(),
            activeColumnIndex: 1,
            selectionProgress: 0.25,
            viewOffset: 42
        )
        next.resolveCommitConflicts(against: current, hasStaleSelection: true)
        XCTAssertEqual(next.selectedNodeId, currentNodeId)
        XCTAssertEqual(next.activeColumnIndex, 4)
        XCTAssertEqual(next.selectionProgress, 0.5)
        XCTAssertEqual(next.viewOffset, 42)
    }

    func testResolveCommitConflictsPreservesLocalSelectionWhenCurrent() {
        let localNodeId = NodeId()
        let current = state(selectedNodeId: NodeId(), activeColumnIndex: 4)
        var next = state(selectedNodeId: localNodeId, activeColumnIndex: 1)
        next.resolveCommitConflicts(against: current, hasStaleSelection: false)
        XCTAssertEqual(next.selectedNodeId, localNodeId)
        XCTAssertEqual(next.activeColumnIndex, 1)
    }

    @MainActor
    func testViewportCommitWithStaleSelectionSeqRebasesSelection() {
        let workspaceId = WorkspaceDescriptor.ID()
        let liveNodeId = NodeId()
        var live = ViewportState()
        live.selectedNodeId = liveNodeId
        live.activeColumnIndex = 2

        var committed = ViewportState()
        committed.selectedNodeId = NodeId()
        committed.activeColumnIndex = 5
        committed.viewOffset = 33

        let snapshot = ReconcileSnapshot(
            topologyProfile: TopologyProfile(monitors: [Monitor.fallback()]),
            focusSession: FocusSessionSnapshot(),
            windows: [],
            viewports: [workspaceId: live],
            selectionSeqs: [workspaceId: 12]
        )

        let stalePlan = StateReducer.reduce(
            event: .viewportCommitted(
                workspaceId: workspaceId,
                state: committed,
                plannedSeq: 11,
                source: .workspaceManager
            ),
            existingEntry: nil,
            currentSnapshot: snapshot,
            monitors: [Monitor.fallback()]
        )
        guard case let .set(_, staleState) = stalePlan.viewport else {
            return XCTFail("expected viewport set plan")
        }
        XCTAssertEqual(staleState.selectedNodeId, liveNodeId)
        XCTAssertEqual(staleState.activeColumnIndex, 2)
        XCTAssertEqual(staleState.viewOffset, 33)

        let currentPlan = StateReducer.reduce(
            event: .viewportCommitted(
                workspaceId: workspaceId,
                state: committed,
                plannedSeq: 12,
                source: .workspaceManager
            ),
            existingEntry: nil,
            currentSnapshot: snapshot,
            monitors: [Monitor.fallback()]
        )
        guard case let .set(_, currentState) = currentPlan.viewport else {
            return XCTFail("expected viewport set plan")
        }
        XCTAssertEqual(currentState.selectedNodeId, committed.selectedNodeId)
        XCTAssertEqual(currentState.activeColumnIndex, 5)
    }
}
