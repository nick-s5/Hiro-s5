import Foundation

struct ReconcileInvariantViolation: Equatable {
    enum Severity: Equatable {
        case assert
        case trace
    }

    let code: String
    let message: String
    var severity: Severity = .assert

    var traceNote: String {
        "invariant[\(code)]=\(message)"
    }
}

struct ReconcileTxn: Equatable {
    let seq: UInt64
    let timestamp: Date
    let event: WMEvent
    let normalizedEvent: WMEvent
    let plan: ActionPlan
    let snapshot: ReconcileSnapshot
    let invariantViolations: [ReconcileInvariantViolation]
}
