import Foundation

public enum StepStatus: Equatable, Sendable {
    case todo
    case done
}

public struct Step: Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var status: StepStatus

    public init(id: UUID = UUID(), text: String, status: StepStatus = .todo) {
        self.id = id
        self.text = text
        self.status = status
    }
}
