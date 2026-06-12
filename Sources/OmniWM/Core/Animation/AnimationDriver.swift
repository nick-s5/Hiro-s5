import Foundation
import QuartzCore

@MainActor
final class AnimationDriver {
    nonisolated static let gestureWorkingAreaMovement: Double = 1200.0

    final class ViewportGesture {
        let tracker = SwipeTracker()
        let isTrackpad: Bool
        private(set) var normFactor: Double = 1.0

        init(isTrackpad: Bool) {
            self.isTrackpad = isTrackpad
        }

        var relativeOffset: Double {
            tracker.position * normFactor
        }

        var velocity: Double {
            tracker.velocity() * normFactor
        }

        func update(delta: Double, timestamp: TimeInterval, viewportWidth: Double) {
            tracker.push(delta: delta, timestamp: timestamp)
            if isTrackpad {
                normFactor = viewportWidth / AnimationDriver.gestureWorkingAreaMovement
            }
        }
    }

    enum ViewportMotion {
        case gesture(ViewportGesture)
        case spring(SpringAnimation)
    }

    struct GestureEndSample {
        let relativeOffset: Double
        let relativeProjectedOffset: Double
    }

    private var motions: [WorkspaceDescriptor.ID: ViewportMotion] = [:]

    func hasMotion(in workspaceId: WorkspaceDescriptor.ID) -> Bool {
        motions[workspaceId] != nil
    }

    func hasGesture(in workspaceId: WorkspaceDescriptor.ID) -> Bool {
        if case .gesture = motions[workspaceId] { return true }
        return false
    }

    func trackpadGestureActive(in workspaceId: WorkspaceDescriptor.ID) -> Bool {
        if case let .gesture(gesture) = motions[workspaceId] { return gesture.isTrackpad }
        return false
    }

    func liveViewOffset(
        in workspaceId: WorkspaceDescriptor.ID,
        semanticOffset: CGFloat,
        at time: TimeInterval = CACurrentMediaTime()
    ) -> CGFloat? {
        switch motions[workspaceId] {
        case let .gesture(gesture):
            semanticOffset + CGFloat(gesture.relativeOffset)
        case let .spring(animation):
            CGFloat(animation.value(at: time))
        case nil:
            nil
        }
    }

    func plannedRenderOffset(
        in workspaceId: WorkspaceDescriptor.ID,
        localState: ViewportState,
        storeOffset: CGFloat,
        at time: TimeInterval = CACurrentMediaTime()
    ) -> CGFloat {
        let transition = localState.offsetTransition
        switch transition.kind {
        case .spring:
            let base = liveViewOffset(in: workspaceId, semanticOffset: storeOffset, at: time) ?? storeOffset
            return base + transition.rebaseDelta
        case .jump:
            return localState.viewOffset
        case nil:
            switch motions[workspaceId] {
            case .gesture:
                return liveViewOffset(in: workspaceId, semanticOffset: localState.viewOffset, at: time)
                    ?? localState.viewOffset
            case let .spring(animation):
                return CGFloat(animation.value(at: time)) + transition.rebaseDelta
            case nil:
                return localState.viewOffset
            }
        }
    }

    func beginGesture(in workspaceId: WorkspaceDescriptor.ID, isTrackpad: Bool) {
        motions[workspaceId] = .gesture(ViewportGesture(isTrackpad: isTrackpad))
    }

    func updateGesture(
        in workspaceId: WorkspaceDescriptor.ID,
        delta: Double,
        timestamp: TimeInterval,
        isTrackpad: Bool,
        viewportWidth: Double
    ) {
        guard case let .gesture(gesture) = motions[workspaceId], gesture.isTrackpad == isTrackpad else { return }
        gesture.update(delta: delta, timestamp: timestamp, viewportWidth: viewportWidth)
    }

    func sampleGestureEnd(
        in workspaceId: WorkspaceDescriptor.ID,
        isTrackpad: Bool? = nil,
        viewportWidth: Double,
        timestamp: TimeInterval?
    ) -> GestureEndSample? {
        guard case let .gesture(gesture) = motions[workspaceId] else { return nil }
        if let isTrackpad, gesture.isTrackpad != isTrackpad { return nil }
        gesture.update(delta: 0, timestamp: timestamp ?? CACurrentMediaTime(), viewportWidth: viewportWidth)
        return GestureEndSample(
            relativeOffset: gesture.relativeOffset,
            relativeProjectedOffset: gesture.tracker.projectedEndPosition() * gesture.normFactor
        )
    }

    func reconcileViewportCommit(
        workspaceId: WorkspaceDescriptor.ID,
        previous: ViewportState?,
        next: ViewportState,
        transition: OffsetTransition
    ) {
        let rebaseDelta = Double(transition.rebaseDelta)
        if rebaseDelta != 0, case let .spring(animation) = motions[workspaceId] {
            animation.offsetBy(rebaseDelta)
        }

        switch transition.kind {
        case nil:
            break

        case .jump:
            motions.removeValue(forKey: workspaceId)

        case let .spring(config):
            let time = CACurrentMediaTime()
            let from: Double
            let velocity: Double
            switch motions[workspaceId] {
            case let .gesture(gesture):
                from = Double(previous?.viewOffset ?? next.viewOffset) + rebaseDelta + gesture.relativeOffset
                velocity = gesture.velocity
            case let .spring(animation):
                from = animation.value(at: time)
                velocity = animation.velocity(at: time)
            case nil:
                from = Double(previous?.viewOffset ?? next.viewOffset) + rebaseDelta
                velocity = 0
            }
            motions[workspaceId] = .spring(
                SpringAnimation(
                    from: from,
                    to: Double(next.viewOffset),
                    initialVelocity: velocity,
                    startTime: time,
                    config: config,
                    displayRefreshRate: next.displayRefreshRate
                )
            )
        }
    }

    func tick(in workspaceId: WorkspaceDescriptor.ID, at time: TimeInterval) -> Bool {
        switch motions[workspaceId] {
        case .gesture:
            return true
        case let .spring(animation):
            if animation.isComplete(at: time) {
                motions.removeValue(forKey: workspaceId)
                return false
            }
            return true
        case nil:
            return false
        }
    }

    func removeMotions<S: Sequence>(for workspaceIds: S) where S.Element == WorkspaceDescriptor.ID {
        for workspaceId in workspaceIds {
            motions.removeValue(forKey: workspaceId)
        }
    }
}
