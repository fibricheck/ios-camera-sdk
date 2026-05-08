import XCTest
@testable import FibriCheckTestSequence

final class TestSequenceManagerTests: XCTestCase {

    var manager: TestSequenceManager!

    override func setUp() {
        super.setUp()
        manager = TestSequenceManager()
    }

    // MARK: - Initialization
    
    func testInit_stepsAreInCorrectOrder() {
        let actualNames = manager.steps.map { $0.name }
        XCTAssertEqual(actualNames, StepName.allCases)
    }

    func testInit_allStepsArePending() {
        XCTAssertTrue(manager.steps.allSatisfy { $0.status == .pending })
    }

    func testInit_hasNoCurrentStepAndIsNotCompleted() {
        XCTAssertEqual(manager.currentStepIndex, -1)
        XCTAssertFalse(manager.isCompleted)
        XCTAssertNil(manager.failureReason)
        XCTAssertNil(manager.currentStep)
        XCTAssertNil(manager.currentStepName)
    }

    func testInit_eachStepHasUniqueExpectedEvent() {
        let events = manager.steps.map { $0.expectedEvent }
        let uniqueEvents = Set(events)
        XCTAssertEqual(events.count, uniqueEvents.count,
                       "Each step should have a unique expected event")
    }

    // MARK: - start()

    func testStart_setsFirstStepToCurrentAndClearsFailure() {
        manager.start()

        XCTAssertEqual(manager.currentStepIndex, 0)
        XCTAssertEqual(manager.steps[0].status, .current)
        XCTAssertEqual(manager.currentStepName, .start)
        XCTAssertFalse(manager.isCompleted)
        XCTAssertNil(manager.failureReason)
    }

    func testStart_afterProgress_resetsAllStepsToPending() {
        manager.start()
        manager.onEvent("START")
        manager.onEvent("onFingerDetectionTimeExpired")

        manager.start()

        XCTAssertEqual(manager.currentStepIndex, 0)
        XCTAssertEqual(manager.steps[0].status, .current)
        for i in 1..<manager.steps.count {
            XCTAssertEqual(manager.steps[i].status, .pending,
                           "Step \(i) should be pending after restart")
        }
    }

    // MARK: - onEvent()

    func testOnEvent_matchingEvent_completesCurrentAndAdvancesToNext() {
        manager.start()
        manager.onEvent("START")

        XCTAssertEqual(manager.currentStepIndex, 1)
        XCTAssertEqual(manager.steps[0].status, .completed)
        XCTAssertEqual(manager.steps[1].status, .current)
        XCTAssertEqual(manager.currentStepName, .fingerTimeout)
    }

    func testOnEvent_nonMatchingEvent_doesNotAdvance() {
        manager.start()
        manager.onEvent("onFingerDetected")

        XCTAssertEqual(manager.currentStepIndex, 0)
        XCTAssertEqual(manager.steps[0].status, .current)
    }

    func testOnEvent_beforeStart_isIgnored() {
        manager.onEvent("START")

        XCTAssertEqual(manager.currentStepIndex, -1)
    }

    func testOnEvent_afterCompletion_isIgnored() {
        manager.start()
        let allEvents = manager.steps.map { $0.expectedEvent }
        for event in allEvents {
            manager.onEvent(event)
        }
        XCTAssertTrue(manager.isCompleted)

        manager.onEvent("START")

        XCTAssertTrue(manager.isCompleted)
        XCTAssertEqual(manager.currentStepIndex, manager.steps.count)
    }

    func testOnEvent_allEventsInOrder_completesEntireSequence() {
        let expectedEvents = [
            "START",
            "onFingerDetectionTimeExpired",
            "onPulseDetectionTimeExpired",
            "onFingerDetected",
            "onSampleReady",
            "onHeartBeat",
            "onPulseDetected",
            "onCalibrationReady",
            "onFingerRemoved",
            "onMovementDetected",
            "onMeasurementStart",
            "onTimeRemaining",
            "onMeasurementFinished",
            "onMeasurementProcessed",
            "onMeasurementValidated"
        ]

        manager.start()

        for event in expectedEvents {
            XCTAssertFalse(manager.isCompleted)
            manager.onEvent(event)
        }

        XCTAssertTrue(manager.isCompleted)
        XCTAssertTrue(manager.steps.allSatisfy { $0.status == .completed })
    }

    func testOnEvent_eachEvent_advancesToCorrectNextStep() {
        let transitions: [(event: String, nextStep: StepName)] = [
            ("START", .fingerTimeout),
            ("onFingerDetectionTimeExpired", .pulseTimeout),
            ("onPulseDetectionTimeExpired", .placeFinger),
            ("onFingerDetected", .sampleReady),
            ("onSampleReady", .heartbeat),
            ("onHeartBeat", .pulse),
            ("onPulseDetected", .calibration),
            ("onCalibrationReady", .fingerRemoved),
            ("onFingerRemoved", .movementDetected),
            ("onMovementDetected", .recordingStart),
            ("onMeasurementStart", .recording),
            ("onTimeRemaining", .recordingFinished),
            ("onMeasurementFinished", .processing),
            ("onMeasurementProcessed", .measurementValidation),
        ]

        manager.start()

        for (event, expectedNext) in transitions {
            manager.onEvent(event)
            XCTAssertEqual(manager.currentStepName, expectedNext,
                           "After \(event), expected step \(expectedNext)")
            XCTAssertEqual(manager.currentStep?.status, .current)
        }

        manager.onEvent("onMeasurementValidated")
        XCTAssertTrue(manager.isCompleted)
    }

    // MARK: - failCurrentStep()

    func testFailCurrentStep_setsStatusToFailedAndStoresReason() {
        manager.start()
        manager.failCurrentStep(reason: "Test failure")

        XCTAssertEqual(manager.steps[0].status, .failed)
        XCTAssertEqual(manager.failureReason, "Test failure")
    }

    func testFailCurrentStep_beforeStart_isIgnored() {
        manager.failCurrentStep(reason: "Should not apply")

        XCTAssertNil(manager.failureReason)
    }

    // MARK: - retryCurrentStep()

    func testRetryCurrentStep_resetsStatusToCurrentAndClearsFailure() {
        manager.start()
        manager.failCurrentStep(reason: "Test failure")
        manager.retryCurrentStep()

        XCTAssertEqual(manager.steps[0].status, .current)
        XCTAssertNil(manager.failureReason)
    }

    func testRetryCurrentStep_doesNotChangeStepIndex() {
        manager.start()
        manager.failCurrentStep(reason: "Test failure")
        manager.retryCurrentStep()

        XCTAssertEqual(manager.currentStepIndex, 0)
        XCTAssertEqual(manager.currentStepName, .start)
    }

    // MARK: - reset()

    func testReset_afterProgress_clearsAllState() {
        manager.start()
        manager.onEvent("START")
        manager.onEvent("onFingerDetectionTimeExpired")
        manager.failCurrentStep(reason: "Some error")

        manager.reset()

        XCTAssertEqual(manager.currentStepIndex, -1)
        XCTAssertFalse(manager.isCompleted)
        XCTAssertNil(manager.failureReason)
        XCTAssertTrue(manager.steps.allSatisfy { $0.status == .pending })
    }

    // MARK: - Computed Properties

    func testCurrentStep_afterStart_returnsFirstStepWithCorrectEvent() {
        manager.start()

        XCTAssertEqual(manager.currentStep?.name, .start)
        XCTAssertEqual(manager.currentStep?.expectedEvent, "START")
    }

    func testCurrentStep_beforeStart_returnsNil() {
        XCTAssertNil(manager.currentStep)
    }

    func testCurrentStepName_beforeStart_returnsNil() {
        XCTAssertNil(manager.currentStepName)
    }
}
