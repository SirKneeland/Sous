import Foundation

public enum StepStatus: Equatable, Sendable {
    case todo
    case done
}

public struct Step: Equatable, Sendable {
    public let id: UUID
    public var text: String
    /// Optional ordered sub-steps. When present and non-empty, done state is
    /// derived from children: the parent is `.done` iff all sub-steps are done.
    public var subSteps: [Step]?
    /// Step-attached notes, not checkable.
    public var notes: [String]?

    // Backing storage for leaf-step status. For parent steps (those with
    // subSteps), this value is unused at read time — effectiveStatus is derived.
    private var _status: StepStatus

    /// Canonical status. For parent steps, derived from sub-step completion.
    /// For leaf steps, identical to the stored status.
    public var effectiveStatus: StepStatus {
        guard let subs = subSteps, !subs.isEmpty else { return _status }
        return subs.allSatisfy { $0.effectiveStatus == .done } ? .done : .todo
    }

    /// Read/write status. The getter returns `effectiveStatus`. The setter is a
    /// no-op when attempting to set `.done` on a parent step that still has at
    /// least one incomplete sub-step — done state for parent steps is derived
    /// from children, not set directly.
    public var status: StepStatus {
        get { effectiveStatus }
        set {
            if newValue == .done,
               let subs = subSteps, !subs.isEmpty,
               subs.contains(where: { $0.effectiveStatus != .done }) {
                return
            }
            _status = newValue
        }
    }

    public init(id: UUID = UUID(), text: String, status: StepStatus = .todo, subSteps: [Step]? = nil, notes: [String]? = nil) {
        self.id = id
        self.text = text
        self._status = status
        self.subSteps = subSteps
        self.notes = notes
    }
}

// MARK: - Step + Codable
//
// Explicit implementation required because `_status` is a private backing store
// that must be encoded under the public key "status" for backward compatibility.
// `subSteps` is encoded only when present (omitted for leaf steps so old readers
// are unaffected).

extension Step: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, text, status, subSteps, notes
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(_status, forKey: .status)
        try c.encodeIfPresent(subSteps, forKey: .subSteps)
        try c.encodeIfPresent(notes, forKey: .notes)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id       = try c.decode(UUID.self,         forKey: .id)
        let text     = try c.decode(String.self,       forKey: .text)
        let status   = try c.decode(StepStatus.self,   forKey: .status)
        let subSteps = try c.decodeIfPresent([Step].self,   forKey: .subSteps)
        let notes    = try c.decodeIfPresent([String].self, forKey: .notes)
        self.init(id: id, text: text, status: status, subSteps: subSteps, notes: notes)
    }
}
