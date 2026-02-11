import Foundation
import SwiftUI

class TestSequenceManager: ObservableObject {

    @Published var steps: [TestStep] = []
    @Published var currentStepIndex: Int = -1
    @Published var isCompleted: Bool = false
    @Published var failureReason: String? = nil

    /// Returns the current step name, or nil if not started
    var currentStepName: StepName? {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex].name
    }

    init() {
        initializeSteps()
    }

    private func initializeSteps() {
        steps = [
            TestStep(name: .start, title: "Start Measurement",
                     instruction: "Tap the START button to begin",
                     expectedEvent: "START"),

            TestStep(name: .fingerTimeout, title: "Test Finger Timeout",
                     instruction: "Do NOT place finger - wait for timeout",
                     expectedEvent: "onFingerDetectionTimeExpired"),

            TestStep(name: .pulseTimeout, title: "Test Pulse Timeout",
                     instruction: "Place finger loosely - wait for pulse timeout",
                     expectedEvent: "onPulseDetectionTimeExpired"),

            TestStep(name: .placeFinger, title: "Place Finger",
                     instruction: "Now cover the camera firmly with your finger",
                     expectedEvent: "onFingerDetected"),

            TestStep(name: .sampleReady, title: "Sample Ready",
                     instruction: "Verifying camera data stream...",
                     expectedEvent: "onSampleReady"),

            TestStep(name: .heartbeat, title: "Detect Heartbeat",
                     instruction: "Keep your finger steady - detecting heartbeat...",
                     expectedEvent: "onHeartBeat"),

            TestStep(name: .pulse, title: "Detect Pulse",
                     instruction: "Hold still - detecting pulse pattern...",
                     expectedEvent: "onPulseDetected"),

            TestStep(name: .calibration, title: "Calibration",
                     instruction: "Calibrating camera settings...",
                     expectedEvent: "onCalibrationReady"),

            TestStep(name: .recordingStart, title: "Recording Started",
                     instruction: "Recording has begun!",
                     expectedEvent: "onMeasurementStart"),

            TestStep(name: .recording, title: "Recording in Progress",
                     instruction: "Keep finger on camera until timer ends",
                     expectedEvent: "onTimeRemaining"),

            TestStep(name: .recordingFinished, title: "Recording Finished",
                     instruction: "Recording complete!",
                     expectedEvent: "onMeasurementFinished"),

            TestStep(name: .processing, title: "Processing",
                     instruction: "Processing measurement data...",
                     expectedEvent: "onMeasurementProcessed")
        ]
    }

    func start() {
        currentStepIndex = 0
        isCompleted = false
        failureReason = nil
        for i in 0..<steps.count {
            steps[i].status = .pending
        }
        steps[0].status = .current
    }

    func reset() {
        currentStepIndex = -1
        isCompleted = false
        failureReason = nil
        for i in 0..<steps.count {
            steps[i].status = .pending
        }
    }

    func onEvent(_ eventName: String) {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return }

        let currentStep = steps[currentStepIndex]

        if currentStep.expectedEvent == eventName {
            completeCurrentStep()
        }
    }

    func failCurrentStep(reason: String) {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return }

        steps[currentStepIndex].status = .failed
        failureReason = reason
    }

    func retryCurrentStep() {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return }

        steps[currentStepIndex].status = .current
        failureReason = nil
    }

    private func completeCurrentStep() {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return }

        steps[currentStepIndex].status = .completed
        currentStepIndex += 1

        if currentStepIndex < steps.count {
            steps[currentStepIndex].status = .current
        } else {
            isCompleted = true
        }
    }

    var currentStep: TestStep? {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
}
