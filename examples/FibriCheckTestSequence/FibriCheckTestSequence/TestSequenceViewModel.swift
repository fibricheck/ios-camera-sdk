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
            fc.onMeasurementProcessed = { measurement in
                DispatchQueue.main.async { self?.handleMeasurementProcessed(measurement: measurement) }
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

    private nonisolated func configureTimeouts(for step: StepName?, on fc: FibriChecker) {
        if step == .fingerTimeout {
            fc.fingerDetectionExpiryTime = 3
            fc.pulseDetectionExpiryTime = 10
        } else if step == .pulseTimeout {
            fc.fingerDetectionExpiryTime = UInt.max    // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 1   // 1 second for quick pulse timeout test
        } else {
            fc.fingerDetectionExpiryTime = UInt.max    // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 30  // 30 seconds for pulse detection
        }
    }

    func handleFingerDetected() {
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

    func handleFingerRemoved() {
        updateLastEvent("onFingerRemoved")

        if sequenceManager.currentStepName == .fingerRemoved {
            sequenceManager.onEvent("onFingerRemoved")
            restartMeasurementForNextStep(skipFingerDetection: false)
        }
    }

    func handleFingerDetectionTimeExpired() {
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

    func handlePulseDetected() {
        updateLastEvent("onPulseDetected")
        let step = sequenceManager.currentStepName

        if step == .pulseTimeout {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Pulse detected - finger should be loose for this test")
            return
        }

        sequenceManager.onEvent("onPulseDetected")
    }

    func handlePulseDetectionTimeExpired() {
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

    func handleSampleReady() {
        if sequenceManager.currentStepName == .sampleReady {
            sequenceManager.onEvent("onSampleReady")
        }
    }

    func handleHeartBeat(hr: UInt) {
        heartRate = hr
        updateLastEvent("onHeartBeat", extra: "BPM=\(hr)")
        sequenceManager.onEvent("onHeartBeat")
    }

    func handleCalibrationReady() {
        updateLastEvent("onCalibrationReady")
        sequenceManager.onEvent("onCalibrationReady")
    }

    func handleMeasurementStart() {
        updateLastEvent("onMeasurementStart")
        sequenceManager.onEvent("onMeasurementStart")
    }

    func handleTimeRemaining(remaining: UInt) {
        timeRemaining = remaining
        updateLastEvent("onTimeRemaining", extra: "\(remaining)s")
        sequenceManager.onEvent("onTimeRemaining")
    }

    func handleMeasurementFinished() {
        updateLastEvent("onMeasurementFinished")
        sequenceManager.onEvent("onMeasurementFinished")
    }

    func handleMeasurementProcessed(measurement: FibriCheckCameraSDK.Measurement? = nil) {
        updateLastEvent("onMeasurementProcessed")

        if sequenceManager.currentStepName == .fingerRemoved {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Measurement completed - remove your finger before it finishes")
            return
        }

        sequenceManager.onEvent("onMeasurementProcessed")
        fibriChecker = nil
        isRunning = false

        if let error = validateMeasurement(measurement) {
            sequenceManager.failCurrentStep(reason: error)
        } else {
            sequenceManager.onEvent("onMeasurementValidated")
        }
    }

    private func validateMeasurement(_ measurement: FibriCheckCameraSDK.Measurement?) -> String? {
        guard let measurement = measurement else { return "Measurement is nil" }
        guard let dict = measurement.mapToDictionary() as? [String: Any] else { return "Could not map measurement to dictionary" }

        // Check top-level arrays are present and non-empty
        guard let quadrants = dict["quadrants"] as? [[Any]], !quadrants.isEmpty else { return "quadrants is missing or empty" }
        guard let time = dict["time"] as? [Any], !time.isEmpty else { return "time is missing or empty" }

        // Check scalar fields
        if dict["measurement_timestamp"] == nil { return "measurement_timestamp is missing" }
        if dict["heartrate"] == nil { return "heartrate is missing" }

        // Check technical_details and its subkeys
        guard let technicalDetails = dict["technical_details"] as? [String: Any] else { return "technical_details is missing" }
        guard let cameraHdr = technicalDetails["camera_hdr"] as? String, !cameraHdr.isEmpty else { return "technical_details.camera_hdr is missing or empty" }

        // Check camera_settings and its subkeys
        guard let cameraSettings = dict["camera_settings"] as? [String: Any] else { return "camera_settings is missing" }
        guard let hdrProfile = cameraSettings["hdr_profile"] as? String, !hdrProfile.isEmpty else { return "camera_settings.hdr_profile is missing or empty" }

        return nil
    }

    func handleMeasurementError(error: String?) {
        updateLastEvent("onMeasurementError", extra: error)
        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: error ?? "Unknown error")
    }

    func handleMovementDetected() {
        updateLastEvent("onMovementDetected")

        if sequenceManager.currentStepName == .movementDetected {
            sequenceManager.onEvent("onMovementDetected")
            restartMeasurementForNextStep(skipFingerDetection: false)
            return
        }

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
