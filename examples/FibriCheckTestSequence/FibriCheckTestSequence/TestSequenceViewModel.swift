import Foundation
import Combine
import AVFoundation
import FibriCheckCameraSDK

@MainActor
class TestSequenceViewModel: ObservableObject {

    @Published private(set) var sequenceManager = TestSequenceManager()
    @Published private(set) var heartRate: UInt = 0
    @Published private(set) var timeRemaining: UInt = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastEvent: String = ""
    @Published var showSuccessAlert: Bool = false

    private var fibriChecker: FibriChecker?
    private var skipFingerDetection: Bool = false
    private var cancellable: AnyCancellable?

    init() {
        cancellable = sequenceManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        requestCameraPermission()
    }

    private func requestCameraPermission() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .notDetermined {
                await AVCaptureDevice.requestAccess(for: .video)
            }
        }
    }

    func startSequence() {
        sequenceManager.start()
        skipFingerDetection = false
        lastEvent = ""
        sequenceManager.onEvent("START")
        updateLastEvent("START")
        startMeasurement()
    }

    func stopMeasurement() {
        tearDownFibriChecker()
        resetSequence()
    }

    func resetSequence() {
        tearDownFibriChecker()
        heartRate = 0
        timeRemaining = 0
        skipFingerDetection = false
        lastEvent = ""
        sequenceManager.reset()
    }

    func retryStep() {
        sequenceManager.retryCurrentStep()
        startMeasurement()
    }

    private func tearDownFibriChecker() {
        fibriChecker?.stop()
        fibriChecker = nil
        isRunning = false
    }

    private func restartMeasurementForNextStep(skipFingerDetection: Bool) {
        tearDownFibriChecker()
        self.skipFingerDetection = skipFingerDetection

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if !self.sequenceManager.isCompleted && self.sequenceManager.failureReason == nil {
                self.startMeasurement()
            }
        }
    }

    private func startMeasurement() {
        isRunning = true

        Task.detached { [weak self] in
            let fc = FibriChecker()

            await MainActor.run {
                self?.fibriChecker = fc
            }

            fc.onFingerDetected = {
                DispatchQueue.main.async { self?.handleFingerDetected() }
            }
            fc.onFingerRemoved = { _, _, _ in
                DispatchQueue.main.async { self?.handleFingerRemoved() }
            }
            fc.onFingerDetectionTimeExpired = {
                DispatchQueue.main.async { self?.handleFingerDetectionTimeExpired() }
            }
            fc.onPulseDetected = {
                DispatchQueue.main.async { self?.handlePulseDetected() }
            }
            fc.onPulseDetectionTimeExpired = {
                DispatchQueue.main.async { self?.handlePulseDetectionTimeExpired() }
            }
            fc.onSampleReady = { _, _ in
                DispatchQueue.main.async { self?.handleSampleReady() }
            }
            fc.onHeartBeat = { hr in
                DispatchQueue.main.async { self?.handleHeartBeat(hr: hr) }
            }
            fc.onCalibrationReady = {
                DispatchQueue.main.async { self?.handleCalibrationReady() }
            }
            fc.onMeasurementStart = {
                DispatchQueue.main.async { self?.handleMeasurementStart() }
            }
            fc.onTimeRemaining = { remaining in
                DispatchQueue.main.async { self?.handleTimeRemaining(remaining: remaining) }
            }
            fc.onMeasurementFinished = {
                DispatchQueue.main.async { self?.handleMeasurementFinished() }
            }
            fc.onMeasurementProcessed = { _ in
                DispatchQueue.main.async { self?.handleMeasurementProcessed() }
            }
            fc.onMeasurementError = { error in
                DispatchQueue.main.async { self?.handleMeasurementError(error: error) }
            }
            fc.onMovementDetected = {
                DispatchQueue.main.async { self?.handleMovementDetected() }
            }

            fc.flashEnabled = true
            fc.sampleTime = 20

            let (currentStep, shouldSkipFinger) = await MainActor.run {
                (self?.sequenceManager.currentStepName, self?.skipFingerDetection ?? false)
            }

            self?.configureTimeouts(for: currentStep, on: fc)
            fc.skippedFingerDetection = shouldSkipFinger

            fc.startMeasurement()
        }
    }

    private func configureTimeouts(for step: StepName?, on fc: FibriChecker) {
        if step == .fingerTimeout {
            fc.fingerDetectionExpiryTime = 3000
            fc.pulseDetectionExpiryTime = 10000
        } else if step == .pulseTimeout {
            fc.fingerDetectionExpiryTime = -1    // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 1000   // 1 second for quick pulse timeout test
        } else {
            fc.fingerDetectionExpiryTime = -1    // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 30000  // 30 seconds for pulse detection
        }
    }

    private func handleFingerDetected() {
        updateLastEvent("onFingerDetected")
        let step = sequenceManager.currentStepName

        if step == .fingerTimeout {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Finger detected - do NOT place finger during this test")
            return
        }

        // Don't advance when finger is detected during pulse timeout test
        if step == .pulseTimeout {
            return
        }

        sequenceManager.onEvent("onFingerDetected")
    }

    private func handleFingerRemoved() {
        updateLastEvent("onFingerRemoved")
    }

    private func handleFingerDetectionTimeExpired() {
        updateLastEvent("onFingerDetectionTimeExpired")
        let step = sequenceManager.currentStepName

        if step == .fingerTimeout {
            sequenceManager.onEvent("onFingerDetectionTimeExpired")
            restartMeasurementForNextStep(skipFingerDetection: true)
            return
        }

        // Ignore finger timeout during pulse timeout test
        if step == .pulseTimeout {
            return
        }

        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: "Finger detection timed out")
    }

    private func handlePulseDetected() {
        updateLastEvent("onPulseDetected")
        let step = sequenceManager.currentStepName

        if step == .pulseTimeout {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Pulse detected - finger should be loose for this test")
            return
        }

        sequenceManager.onEvent("onPulseDetected")
    }

    private func handlePulseDetectionTimeExpired() {
        updateLastEvent("onPulseDetectionTimeExpired")
        let step = sequenceManager.currentStepName

        if step == .pulseTimeout {
            sequenceManager.onEvent("onPulseDetectionTimeExpired")
            restartMeasurementForNextStep(skipFingerDetection: false)
            return
        }

        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: "Pulse detection timed out - hold more steady")
    }

    private func handleSampleReady() {
        if sequenceManager.currentStepName == .sampleReady {
            sequenceManager.onEvent("onSampleReady")
        }
    }

    private func handleHeartBeat(hr: UInt) {
        heartRate = hr
        updateLastEvent("onHeartBeat", extra: "BPM=\(hr)")
        sequenceManager.onEvent("onHeartBeat")
    }

    private func handleCalibrationReady() {
        updateLastEvent("onCalibrationReady")
        sequenceManager.onEvent("onCalibrationReady")
    }

    private func handleMeasurementStart() {
        updateLastEvent("onMeasurementStart")
        sequenceManager.onEvent("onMeasurementStart")
    }

    private func handleTimeRemaining(remaining: UInt) {
        timeRemaining = remaining
        updateLastEvent("onTimeRemaining", extra: "\(remaining)s")
        sequenceManager.onEvent("onTimeRemaining")
    }

    private func handleMeasurementFinished() {
        updateLastEvent("onMeasurementFinished")
        sequenceManager.onEvent("onMeasurementFinished")
    }

    private func handleMeasurementProcessed() {
        updateLastEvent("onMeasurementProcessed")
        sequenceManager.onEvent("onMeasurementProcessed")
        fibriChecker = nil
        isRunning = false
    }

    private func handleMeasurementError(error: String?) {
        updateLastEvent("onMeasurementError", extra: error)
        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: error ?? "Unknown error")
    }

    private func handleMovementDetected() {
        updateLastEvent("onMovementDetected")
        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: "Movement detected - hold steady")
    }

    private func updateLastEvent(_ event: String, extra: String? = nil) {
        if let extra = extra {
            lastEvent = "\(event) (\(extra))"
        } else {
            lastEvent = event
        }
    }
}
