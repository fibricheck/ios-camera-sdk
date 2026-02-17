import Foundation

enum TestStepStatus {
    case pending
    case current
    case completed
    case failed
}

enum StepName: Int, CaseIterable {
    case start = 1
    case fingerTimeout
    case pulseTimeout
    case placeFinger
    case sampleReady
    case heartbeat
    case pulse
    case calibration
    case fingerRemoved
    case movementDetected
    case recordingStart
    case recording
    case recordingFinished
    case processing
}

struct TestStep: Identifiable {
    let id: Int
    let name: StepName
    let title: String
    let instruction: String
    let expectedEvent: String
    var status: TestStepStatus

    init(name: StepName, title: String, instruction: String, expectedEvent: String) {
        self.id = name.rawValue
        self.name = name
        self.title = title
        self.instruction = instruction
        self.expectedEvent = expectedEvent
        self.status = .pending
    }
}
