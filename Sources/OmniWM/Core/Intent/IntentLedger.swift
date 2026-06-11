import Foundation

typealias IntentID = UInt64

enum IntentKind: Equatable, Sendable {
    case activateApp(pid: pid_t)
    case focusWindow(token: WindowToken, workspaceId: WorkspaceDescriptor.ID)

    var focusTargetToken: WindowToken? {
        switch self {
        case .activateApp:
            nil
        case let .focusWindow(token, _):
            token
        }
    }

    var targetPid: pid_t {
        switch self {
        case let .activateApp(pid):
            pid
        case let .focusWindow(token, _):
            token.pid
        }
    }
}

enum IntentPhase: Equatable, Sendable {
    case pending
    case confirmed
    case superseded
    case expired
    case cancelled

    var isRetired: Bool {
        self != .pending
    }
}

struct Intent: Equatable, Sendable {
    let id: IntentID
    var kind: IntentKind
    var origin: ManagedFocusOrigin
    let issuedAtSeq: UInt64
    var phase: IntentPhase = .pending
    var retryCount: Int = 0
    var lastActivationSource: ActivationEventSource?
    var correlatedRequestId: UInt64?
    var retiredAt: ContinuousClock.Instant?
}

enum EchoClassification: Equatable {
    case echoOf(Intent)
    case lateEcho(Intent)
    case external
}

@MainActor
final class IntentLedger {
    static let capacity = 256
    private static let lateEchoWindow: Duration = .seconds(1)

    var seqProvider: () -> UInt64 = { 0 }
    var clock: () -> ContinuousClock.Instant = { ContinuousClock().now }

    private(set) var entries: [Intent] = []
    private var nextIntentId: IntentID = 1

    @discardableResult
    func registerFocusWindow(
        token: WindowToken,
        workspaceId: WorkspaceDescriptor.ID,
        origin: ManagedFocusOrigin,
        correlatedRequestId: UInt64? = nil
    ) -> Intent {
        if let index = openIndex(where: { $0.kind == .focusWindow(token: token, workspaceId: workspaceId) }) {
            entries[index].origin = entries[index].origin.merged(with: origin)
            if let correlatedRequestId {
                entries[index].correlatedRequestId = correlatedRequestId
            }
            return entries[index]
        }
        return append(
            kind: .focusWindow(token: token, workspaceId: workspaceId),
            origin: origin,
            correlatedRequestId: correlatedRequestId
        )
    }

    @discardableResult
    func registerActivateApp(pid: pid_t) -> Intent {
        if let index = openIndex(where: { $0.kind == .activateApp(pid: pid) }) {
            return entries[index]
        }
        return append(kind: .activateApp(pid: pid), origin: .keyboardOrProgrammatic, correlatedRequestId: nil)
    }

    func intent(id: IntentID) -> Intent? {
        entries.first { $0.id == id }
    }

    func openIntent(id: IntentID) -> Intent? {
        entries.first { $0.id == id && $0.phase == .pending }
    }

    func openFocusIntent(correlatedRequestId: UInt64) -> Intent? {
        entries.first { $0.correlatedRequestId == correlatedRequestId && $0.phase == .pending }
    }

    func openFocusIntent(token: WindowToken) -> Intent? {
        entries.last { $0.phase == .pending && $0.kind.focusTargetToken == token }
    }

    func openIntents(pid: pid_t) -> [Intent] {
        entries.filter { $0.phase == .pending && $0.kind.targetPid == pid }
    }

    @discardableResult
    func confirm(id: IntentID, source: ActivationEventSource? = nil) -> Intent? {
        retire(id: id, phase: .confirmed, source: source)
    }

    @discardableResult
    func cancel(id: IntentID) -> Intent? {
        retire(id: id, phase: .cancelled, source: nil)
    }

    @discardableResult
    func supersede(id: IntentID) -> Intent? {
        retire(id: id, phase: .superseded, source: nil)
    }

    @discardableResult
    func markExpired(id: IntentID) -> Intent? {
        retire(id: id, phase: .expired, source: nil)
    }

    @discardableResult
    func recordRetry(id: IntentID, source: ActivationEventSource?) -> Intent? {
        guard let index = openIndex(where: { $0.id == id }) else { return nil }
        entries[index].retryCount += 1
        entries[index].lastActivationSource = source
        return entries[index]
    }

    func rekey(from oldToken: WindowToken, to newToken: WindowToken) {
        for index in entries.indices where entries[index].phase == .pending {
            if case let .focusWindow(token, workspaceId) = entries[index].kind, token == oldToken {
                entries[index].kind = .focusWindow(token: newToken, workspaceId: workspaceId)
            }
        }
    }

    func classifyFocusObservation(token: WindowToken) -> EchoClassification {
        if let intent = openFocusIntent(token: token) {
            return .echoOf(intent)
        }
        let now = clock()
        let lateEcho = entries.last { entry in
            guard entry.phase.isRetired,
                  entry.phase != .confirmed,
                  entry.kind.focusTargetToken == token,
                  let retiredAt = entry.retiredAt
            else {
                return false
            }
            return retiredAt.duration(to: now) <= Self.lateEchoWindow
        }
        if let lateEcho {
            return .lateEcho(lateEcho)
        }
        return .external
    }

    func reset() {
        entries.removeAll(keepingCapacity: false)
    }

    private func append(
        kind: IntentKind,
        origin: ManagedFocusOrigin,
        correlatedRequestId: UInt64?
    ) -> Intent {
        let intent = Intent(
            id: nextIntentId,
            kind: kind,
            origin: origin,
            issuedAtSeq: seqProvider(),
            correlatedRequestId: correlatedRequestId
        )
        nextIntentId += 1
        entries.append(intent)
        trim()
        return intent
    }

    private func retire(id: IntentID, phase: IntentPhase, source: ActivationEventSource?) -> Intent? {
        guard let index = entries.firstIndex(where: { $0.id == id && $0.phase == .pending }) else { return nil }
        entries[index].phase = phase
        entries[index].retiredAt = clock()
        if let source {
            entries[index].lastActivationSource = source
        }
        return entries[index]
    }

    private func openIndex(where predicate: (Intent) -> Bool) -> Int? {
        entries.lastIndex { $0.phase == .pending && predicate($0) }
    }

    private func trim() {
        guard entries.count > Self.capacity else { return }
        var overflow = entries.count - Self.capacity
        entries.removeAll { entry in
            guard overflow > 0, entry.phase.isRetired else { return false }
            overflow -= 1
            return true
        }
    }
}
