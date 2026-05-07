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
    @Published var lastCameraSettings: [String: Any]? = nil
    @Published private(set) var captureSession: AVCaptureSession? = nil
    @Published var showCameraSettingsSheet: Bool = false
    @Published private(set) var measurementNotes: [String] = []

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
        lastCameraSettings = nil
        sequenceManager.start()
        skipFingerDetection = false
        lastEvent = ""
        sequenceManager.onEvent("START")
        updateLastEvent("START")
        startMeasurement()
    }

    func stopMeasurement() {
        resetSequence()
    }

    func resetSequence() {
        tearDownFibriChecker()
        heartRate = 0
        timeRemaining = 0
        skipFingerDetection = false
        lastEvent = ""
        lastCameraSettings = nil
        measurementNotes = []
        sequenceManager.reset()
    }

    func retryStep() {
        tearDownFibriChecker(keepPreview: true)
        sequenceManager.retryCurrentStep()
        if sequenceManager.currentStepName == .movementDetected {
            sequenceManager.updateCurrentStepInstruction("Place finger on camera — waiting for recording to start")
        }
        startMeasurement()
    }

    func skipCurrentStep() {
        tearDownFibriChecker(keepPreview: true)
        sequenceManager.skipCurrentStep()
        startMeasurement()
    }

    private func skipStepAndRestart() {
        isRunning = false
        sequenceManager.skipCurrentStep()
        startMeasurement()
    }

    private func tearDownFibriChecker(keepPreview: Bool = false) {
        fibriChecker?.stop()
        fibriChecker = nil
        isRunning = false
        if !keepPreview {
            captureSession = nil
        }
    }

    private func restartMeasurementForNextStep(skipFingerDetection: Bool) {
        tearDownFibriChecker(keepPreview: true)
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

            let (currentStep, shouldSkipFinger) = await MainActor.run {
                (self?.sequenceManager.currentStepName, self?.skipFingerDetection ?? false)
            }

            self?.configureTimeouts(for: currentStep, on: fc)
            fc.flashEnabled = true
            fc.sampleTime = 10

            // Uncomment only for experimental testing!
            // fc.fingerDetectionExpiryTime = 3;
            // fc.pulseDetectionExpiryTime = 10;
            // fc.movementDetectionEnabled = false;

            let shouldSkip =
                (currentStep == .movementDetected && !fc.movementDetectionEnabled) ||
                (currentStep == .fingerTimeout && fc.fingerDetectionExpiryTime == 0) ||
                (currentStep == .pulseTimeout && fc.pulseDetectionExpiryTime == 0) ||
                (currentStep == .placeFinger && fc.fingerDetectionExpiryTime == 0)

            if shouldSkip {
                await self?.skipStepAndRestart()
                return
            }

            fc.startMeasurement()

            await MainActor.run {
                self?.fibriChecker = fc
                self?.captureSession = fc.captureSession
            }
        }
    }

    private nonisolated func configureTimeouts(for step: StepName?, on fc: FibriChecker) {
        if step == .fingerTimeout {
            fc.fingerDetectionExpiryTime = 3
            fc.pulseDetectionExpiryTime = 10
        } else if step == .pulseTimeout {
            fc.fingerDetectionExpiryTime = UInt.max  // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 1          // 1 second for quick pulse timeout test
        } else if step == .calibration || step == .movementDetected || step == .recordingStart {
            fc.fingerDetectionExpiryTime = UInt.max  // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = UInt.max   // No timeout - finger is already on camera
        } else {
            fc.fingerDetectionExpiryTime = UInt.max  // No timeout - wait for user to place finger
            fc.pulseDetectionExpiryTime = 30         // 30 seconds for pulse detection
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

        if step == .pulseTimeout {
            return
        }

        sequenceManager.onEvent("onFingerDetected")
    }

    func handleFingerRemoved() {
        updateLastEvent("onFingerRemoved")

        if sequenceManager.currentStepName == .fingerRemoved {
            sequenceManager.onEvent("onFingerRemoved")
            // Now on .movementDetected — set phase-specific instruction since finger was just removed
            sequenceManager.updateCurrentStepInstruction("Place finger on camera & wait for recording to start before moving")
            restartMeasurementForNextStep(skipFingerDetection: false)
        }
    }

    func handleFingerDetectionTimeExpired() {
        updateLastEvent("onFingerDetectionTimeExpired")
        let step = sequenceManager.currentStepName

        if let step = step, step.rawValue >= StepName.recording.rawValue {
            return
        }

        if step == .fingerTimeout {
            sequenceManager.onEvent("onFingerDetectionTimeExpired")
            restartMeasurementForNextStep(skipFingerDetection: true)
            return
        }

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

        if let step = step, step.rawValue >= StepName.recording.rawValue {
            return
        }

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
            // When pulse detection is skipped, onHeartBeat (requires isValidPulse set by
            // pulse detection) and onPulseDetected will never fire. Skip both steps now
            // while still before onCalibrationReady, so step 8 receives it correctly.
            if fibriChecker?.pulseDetectionExpiryTime == 0 {
                sequenceManager.skipCurrentStep() // heartbeat
                sequenceManager.skipCurrentStep() // pulse
            }
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
        // When finger detection is disabled, onFingerRemoved won't fire and there is no
        // measurement restart for movementDetected's shouldSkip check to run. Skip both
        // now so onMeasurementStart (queued next on main) lands correctly on recordingStart.
        if fibriChecker?.fingerDetectionExpiryTime == 0 {
            sequenceManager.skipCurrentStep() // fingerRemoved
            sequenceManager.skipCurrentStep() // movementDetected
        }
    }

    func handleMeasurementStart() {
        updateLastEvent("onMeasurementStart")
        if sequenceManager.currentStepName == .movementDetected {
            sequenceManager.updateCurrentStepInstruction("Recording in progress — shake the device now!")
        }
        sequenceManager.onEvent("onMeasurementStart")
    }

    func handleTimeRemaining(remaining: UInt) {
        timeRemaining = remaining
        updateLastEvent("onTimeRemaining", extra: "\(remaining)s")
        // Show countdown in the instruction — step advances via handleMeasurementFinished
        let step = sequenceManager.currentStepName
        if step == .recording || step == .recordingStart {
            sequenceManager.updateCurrentStepInstruction("Recording... \(remaining)s remaining")
        }
    }

    func handleMeasurementFinished() {
        updateLastEvent("onMeasurementFinished")
        let step = sequenceManager.currentStepName

        if step == .fingerRemoved {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Recording finished before finger was removed - retry and lift finger sooner")
            return
        }
        if step == .movementDetected {
            tearDownFibriChecker()
            sequenceManager.failCurrentStep(reason: "Recording finished before movement was detected - retry and shake sooner")
            return
        }
        // Advance .recording if still on it before completing .recordingFinished
        if step == .recording {
            sequenceManager.onEvent("onTimeRemaining")
        }
        sequenceManager.onEvent("onMeasurementFinished")
    }

    func handleMeasurementProcessed(measurement: FibriCheckCameraSDK.Measurement? = nil) {
        updateLastEvent("onMeasurementProcessed")
        let step = sequenceManager.currentStepName

        // Ignore early completions — can happen if sampleTime is too short and the
        // recording finishes before the user reaches the processing step.
        guard step == .processing || step == .measurementValidation else {
            isRunning = false
            return
        }

        sequenceManager.onEvent("onMeasurementProcessed")
        fibriChecker = nil
        captureSession = nil
        isRunning = false

        if let error = validateMeasurement(measurement) {
            sequenceManager.failCurrentStep(reason: error)
        } else {
            sequenceManager.onEvent("onMeasurementValidated")
            if let dict = measurement?.mapToDictionary() as? [String: Any],
               let cs = dict["camera_settings"] as? [String: Any] {
                lastCameraSettings = cs
            }
            if let m = measurement {
                measurementNotes = [
                    "skippedFingerDetection: \(m.skippedFingerDetection)",
                    "skippedPulseDetection: \(m.skippedPulseDetection)",
                    "skippedMovementDetection: \(m.skippedMovementDetection)"
                ]
            }
        }
    }

    private func validateMeasurement(_ measurement: FibriCheckCameraSDK.Measurement?) -> String? {
        guard let measurement = measurement else { return "Measurement is nil" }
        guard let dict = measurement.mapToDictionary() as? [String: Any] else { return "Could not map measurement to dictionary" }

        guard let quadrants = dict["quadrants"] as? [[Any]], !quadrants.isEmpty else { return "quadrants is missing or empty" }
        guard let time = dict["time"] as? [Any], !time.isEmpty else { return "time is missing or empty" }

        if dict["measurement_timestamp"] == nil { return "measurement_timestamp is missing" }

        guard let technicalDetails = dict["technical_details"] as? [String: Any] else { return "technical_details is missing" }
        guard let cameraHdr = technicalDetails["camera_hdr"] as? String, !cameraHdr.isEmpty else { return "technical_details.camera_hdr is missing or empty" }

        guard let cameraSettings = dict["camera_settings"] as? [String: Any] else { return "camera_settings is missing" }
        guard let exposureMode = cameraSettings["exposure_mode"] as? String, !exposureMode.isEmpty else { return "camera_settings.exposure_mode is missing or empty" }
        guard let hdrProfile = cameraSettings["hdr_profile"] as? String, !hdrProfile.isEmpty else { return "camera_settings.hdr_profile is missing or empty" }
        guard let hdrMode = cameraSettings["hdr_mode"] as? String, !hdrMode.isEmpty else { return "camera_settings.hdr_mode is missing or empty" }
        guard let focusMode = cameraSettings["focus_mode"] as? String, !focusMode.isEmpty else { return "camera_settings.focus_mode is missing or empty" }
        guard let focus = cameraSettings["focus"] as? [[Any]], !focus.isEmpty else { return "camera_settings.focus is missing or empty" }
        guard let whiteBalance = cameraSettings["white_balance"] as? [[Any]], !whiteBalance.isEmpty else { return "camera_settings.white_balance is missing or empty" }

        return nil
    }

    func handleMeasurementError(error: String?) {
        updateLastEvent("onMeasurementError", extra: error)
        let step = sequenceManager.currentStepName

        // Errors during or after recording are expected (e.g. movement, finger removal)
        if let step = step, step.rawValue >= StepName.recording.rawValue {
            return
        }

        tearDownFibriChecker()
        sequenceManager.failCurrentStep(reason: error ?? "Unknown error")
    }

    func handleMovementDetected() {
        updateLastEvent("onMovementDetected")
        guard let step = sequenceManager.currentStepName else { return }

        // Shaking generates many events. Once step 10 (.movementDetected) is done, all
        // subsequent steps must be protected from lingering shake events.
        if step.rawValue >= StepName.recordingStart.rawValue {
            return
        }

        if step == .movementDetected {
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
