import XCTest
@testable import FibriCheckTestSequence

@MainActor
final class TestSequenceViewModelTests: XCTestCase {

    var viewModel: TestSequenceViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TestSequenceViewModel()
    }

    func testResetClearsAllState() {
        viewModel.resetSequence()

        XCTAssertEqual(viewModel.heartRate, 0)
        XCTAssertEqual(viewModel.timeRemaining, 0)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.lastEvent, "")
        XCTAssertEqual(viewModel.sequenceManager.currentStepIndex, -1)
    }

    func testHandleFingerDetectedFailsOnFingerTimeoutStep() {
        viewModel.sequenceManager.start()
        viewModel.sequenceManager.onEvent("START") // advance to .fingerTimeout

        viewModel.handleFingerDetected()

        XCTAssertEqual(viewModel.sequenceManager.steps[1].status, .failed)
        XCTAssertNotNil(viewModel.sequenceManager.failureReason)
    }

    func testHandleFingerDetectedIgnoredOnPulseTimeoutStep() {
        advanceToStep(.pulseTimeout)

        viewModel.handleFingerDetected()

        // Should not fail and not advance
        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .pulseTimeout)
        XCTAssertNil(viewModel.sequenceManager.failureReason)
    }

    func testHandleFingerDetectedAdvancesOnPlaceFingerStep() {
        advanceToStep(.placeFinger)

        viewModel.handleFingerDetected()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .sampleReady)
    }

    func testHandlePulseDetectedFailsOnPulseTimeoutStep() {
        advanceToStep(.pulseTimeout)

        viewModel.handlePulseDetected()

        XCTAssertNotNil(viewModel.sequenceManager.failureReason)
    }

    func testHandlePulseDetectedAdvancesOnPulseStep() {
        advanceToStep(.pulse)

        viewModel.handlePulseDetected()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .calibration)
    }

    func testHandleFingerDetectionTimeExpiredAdvancesOnFingerTimeoutStep() {
        viewModel.sequenceManager.start()
        viewModel.sequenceManager.onEvent("START") // advance to .fingerTimeout

        viewModel.handleFingerDetectionTimeExpired()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .pulseTimeout)
    }

    func testHandleFingerDetectionTimeExpiredIgnoredOnPulseTimeoutStep() {
        advanceToStep(.pulseTimeout)

        viewModel.handleFingerDetectionTimeExpired()

        // Should not fail and not advance
        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .pulseTimeout)
        XCTAssertNil(viewModel.sequenceManager.failureReason)
    }

    func testHandleFingerDetectionTimeExpiredFailsOnOtherSteps() {
        advanceToStep(.placeFinger)

        viewModel.handleFingerDetectionTimeExpired()

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Finger detection timed out")
    }

    func testHandlePulseDetectionTimeExpiredAdvancesOnPulseTimeoutStep() {
        advanceToStep(.pulseTimeout)

        viewModel.handlePulseDetectionTimeExpired()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .placeFinger)
    }

    func testHandlePulseDetectionTimeExpiredFailsOnOtherSteps() {
        advanceToStep(.placeFinger)

        viewModel.handlePulseDetectionTimeExpired()

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Pulse detection timed out - hold more steady")
    }

    func testHandleSampleReadyOnlyAdvancesOnSampleReadyStep() {
        advanceToStep(.placeFinger)

        viewModel.handleSampleReady()

        // Should NOT advance - wrong step
        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .placeFinger)
    }

    func testHandleSampleReadyAdvancesOnCorrectStep() {
        advanceToStep(.sampleReady)

        viewModel.handleSampleReady()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .heartbeat)
    }

    func testHandleHeartBeatUpdatesHeartRate() {
        advanceToStep(.heartbeat)

        viewModel.handleHeartBeat(hr: 72)

        XCTAssertEqual(viewModel.heartRate, 72)
    }

    func testHandleTimeRemainingUpdatesTimeRemaining() {
        advanceToStep(.recording)

        viewModel.handleTimeRemaining(remaining: 15)

        XCTAssertEqual(viewModel.timeRemaining, 15)
    }

    func testHandleMeasurementErrorFailsCurrentStep() {
        viewModel.sequenceManager.start()

        viewModel.handleMeasurementError(error: "Camera error")

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Camera error")
        XCTAssertFalse(viewModel.isRunning)
    }

    func testHandleMeasurementErrorUsesDefaultMessageWhenNil() {
        viewModel.sequenceManager.start()

        viewModel.handleMeasurementError(error: nil)

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Unknown error")
    }

    func testHandleFingerRemovedAdvancesOnFingerRemovedStep() {
        advanceToStep(.fingerRemoved)

        viewModel.handleFingerRemoved()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .movementDetected)
    }

    func testHandleMeasurementProcessedFailsOnFingerRemovedStep() {
        advanceToStep(.fingerRemoved)

        viewModel.handleMeasurementProcessed()

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Measurement completed - remove your finger before it finishes")
    }

    func testHandleFingerRemovedIgnoredOnOtherSteps() {
        advanceToStep(.placeFinger)

        viewModel.handleFingerRemoved()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .placeFinger)
        XCTAssertNil(viewModel.sequenceManager.failureReason)
    }

    func testHandleMovementDetectedAdvancesOnMovementDetectedStep() {
        advanceToStep(.movementDetected)

        viewModel.handleMovementDetected()

        XCTAssertEqual(viewModel.sequenceManager.currentStepName, .recordingStart)
    }

    func testHandleMovementDetectedFailsOnOtherSteps() {
        viewModel.sequenceManager.start()

        viewModel.handleMovementDetected()

        XCTAssertEqual(viewModel.sequenceManager.failureReason, "Movement detected - hold steady")
        XCTAssertFalse(viewModel.isRunning)
    }

    func testHandlersUpdateLastEvent() {
        viewModel.sequenceManager.start()

        viewModel.handleCalibrationReady()
        XCTAssertEqual(viewModel.lastEvent, "onCalibrationReady")

        viewModel.handleHeartBeat(hr: 80)
        XCTAssertEqual(viewModel.lastEvent, "onHeartBeat (BPM=80)")

        viewModel.handleTimeRemaining(remaining: 10)
        XCTAssertEqual(viewModel.lastEvent, "onTimeRemaining (10s)")

        viewModel.handleFingerRemoved()
        XCTAssertEqual(viewModel.lastEvent, "onFingerRemoved")
    }

    /// Advances the sequence manager to the given step by sending all preceding expected events
    private func advanceToStep(_ target: StepName) {
        viewModel.sequenceManager.start()

        let events: [(StepName, String)] = [
            (.start, "START"),
            (.fingerTimeout, "onFingerDetectionTimeExpired"),
            (.pulseTimeout, "onPulseDetectionTimeExpired"),
            (.placeFinger, "onFingerDetected"),
            (.sampleReady, "onSampleReady"),
            (.heartbeat, "onHeartBeat"),
            (.pulse, "onPulseDetected"),
            (.calibration, "onCalibrationReady"),
            (.fingerRemoved, "onFingerRemoved"),
            (.movementDetected, "onMovementDetected"),
            (.recordingStart, "onMeasurementStart"),
            (.recording, "onTimeRemaining"),
            (.recordingFinished, "onMeasurementFinished"),
            (.processing, "onMeasurementProcessed"),
        ]

        for (step, event) in events {
            if step == target { break }
            viewModel.sequenceManager.onEvent(event)
        }
    }
}
