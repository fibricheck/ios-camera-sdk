//
//  ContentView.swift
//  FibriCheckExample
//
//  Created by Christopher Hex on 04/05/2023.
//

import SwiftUI
import AVFoundation
import FibriCheckCameraSDK

// MARK: - Camera Preview

private class VideoPreviewUIView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoPreviewUIView {
        VideoPreviewUIView(session: session)
    }

    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {}
}

// MARK: - ViewModel

class MeasurementViewModel: ObservableObject {
    var cameraSettings: CameraSettingsInput = CameraSettingsInput(
        values: .modeLocked,
        manualIso: 0,
        manualExposureTime: 0,
        whiteBalanceMode: .locked,
        manualWhiteBalanceRgb: RgbColor(r: 0.0, g: 0.0, b: 0.0),
        manualWhiteBalanceKelvin: 5000,
        focus: .modeLocked,
        manualFocus: 0,
        rawDataEnabled: false,
        logExposure: true,
        logWhiteBalance: true,
        logFocus: true
    )
    
    @Published var heartRate: UInt = 0
    @Published var isRunning = false
    @Published var rawDataEnabled = false {
        didSet {
            guard oldValue != rawDataEnabled else { return }
            self.cameraSettings.rawDataEnabled = rawDataEnabled
            fibriChecker.setCameraSettings(self.cameraSettings)
        }
    }
    @Published var previewEnabled = false {
        didSet {
            guard oldValue != previewEnabled else { return }
            if previewEnabled {
                print("[ContentView][startPreview]")
                fibriChecker.startPreview()
            } else {
                print("[ContentView][stopPreview]")
                fibriChecker.stopPreview()
            }
        }
    }

    private let fibriChecker = FibriChecker()

    var captureSession: AVCaptureSession? {
        fibriChecker.captureSession
    }

    init() {
        requestCameraAccess()
        setupCallbacks()
        fibriChecker.accEnabled = true
        fibriChecker.sampleTime = 10
        fibriChecker.flashEnabled = true
        fibriChecker.setCameraSettings(self.cameraSettings)
    }

    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }

    private func setupCallbacks() {
        fibriChecker.onMeasurementStart = { [weak self] in
            print("Measurement started")
            self?.heartRate = 0
        }

        fibriChecker.onMeasurementFinished = {
            print("Measurement finished")
        }

        fibriChecker.onMeasurementError = { error in
            print("Measurement error: \(error ?? "unknown")")
        }

        fibriChecker.onHeartBeat = { [weak self] hr in
            print("Received HeartRate \(hr)")
            self?.heartRate = hr
        }

        fibriChecker.onMovementDetected = {
            print("Movement detected")
        }

        fibriChecker.onPulseDetected = {
            print("Pulse detected")
        }

        fibriChecker.onMeasurementProcessed = { [weak self] measurement in
            print("OnMeasurement")
            let dict = measurement.mapToDictionary()!
            let cameraSettings = dict["camera_settings"] as? NSMutableDictionary
            let technicalDetails = dict["technical_details"] as! NSMutableDictionary

            if let cameraSettings { dump(cameraSettings) }
            dump(technicalDetails)

            print("Measurement finalized")
            let valid = validateQuadrants(measurement: measurement)
            print("Quadrant validation result: \(valid)")

            self?.isRunning = false
            self?.previewEnabled = false
        }

        fibriChecker.onRawData = { data, _ in
            print("Raw data received: \(data.count) bytes")
        }
        
        fibriChecker.onPreviewStarted = { [weak self] in
            print("onPreviewStarted")
        }
    }

    func startMeasurement() {
        print("[ContentView][startMeasurement]")
        fibriChecker.startMeasurement()
        isRunning = true
        previewEnabled = false
    }

    func stop() {
        print("Stop")
        fibriChecker.stop()
        isRunning = false
        previewEnabled = false
    }
}

// MARK: - Helpers

func validateQuadrants(measurement: FibriCheckCameraSDK.Measurement) -> Bool {
    guard let quadrants = measurement.quadrants else { return false }

    var yuvSampleSums: [Double] = []
    for row in 0...3 {
        let rowData = quadrants[row] as! NSArray
        for col in 0...3 {
            let data = rowData[col] as! FibriCheckCameraSDK.YUV
            let y = (data.y as [AnyObject])[1] as! Double
            let u = (data.u as [AnyObject])[1] as! Double
            let v = (data.v as [AnyObject])[1] as! Double
            yuvSampleSums.append(y + u + v)
        }
    }

    return yuvSampleSums.count == Set(yuvSampleSums).count
}

// MARK: - View

struct ContentView: View {
    @StateObject private var viewModel = MeasurementViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.captureSession != nil,
               let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("FibriCheck Example Application")
            Text("Heart rate: \(viewModel.heartRate)")

            Toggle("Camera Preview", isOn: $viewModel.previewEnabled)
            

            Toggle("Raw Data", isOn: $viewModel.rawDataEnabled)
                .disabled(viewModel.isRunning)

            Button(viewModel.isRunning ? "Stop Measurement" : "Start Measurement") {
                if viewModel.isRunning {
                    viewModel.stop()
                } else {
                    viewModel.startMeasurement()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
