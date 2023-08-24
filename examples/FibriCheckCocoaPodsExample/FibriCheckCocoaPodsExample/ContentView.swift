//
//  ContentView.swift
//  FibriCheckExample
//
//  Created by Christopher Hex on 04/05/2023.
//

import SwiftUI
import FibriCheckCameraSDK

struct ContentView: View {
    @State var heartRate: UInt = 0
    @State var logString: String = ""
    @State var receivedEvents = [
        "onFingerDetected": false,
        "onFingerRemoved": false,
        "onHeartBeat": false,
        "onPulseDetected": false,
        "onCalibrationReady": false,
        "onPulseDetectionTimeExpired": false,
        "onFingerDetectionTimeExpired": false,
        "onMovementDetected": false,
        "onMeasurementStart": false,
        "onMeasurementFinished": false,
        "onMeasurementError": false,
        "onMeasurementProcessed": false,
        "onSampleReady": false,
        "onTimeRemaining": false
        
    ]
    @State var receivedEventsString = ""
    var dateFormatter: DateFormatter
    
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss:SSS"
        var isAuthorized: Bool {
            get async {
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                
                // Determine if the user previously authorized camera access.
                var isAuthorized = status == .authorized
                
                // If the system hasn't determined the user's authorization status,
                // explicitly prompt them for approval.
                if status == .notDetermined {
                    isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
                }
                
                return isAuthorized
            }
        }
        
        Task {
            guard await isAuthorized else {return}
        }
    }
    
    func addToLogString(txt: String) {
        let date = Date()
        self.logString += "\n" + dateFormatter.string(from: date) + " - " + txt
    }
    func logEvent(name: String) {
        
        receivedEvents[name] = true
        
        // Update received Events String
        receivedEventsString = ""
        for (name, val) in receivedEvents {
            
            if(val) {
                receivedEventsString += "✅ " + name + "\n"
            } else {
                receivedEventsString += "❌ " + name + "\n"
            }
        }
        
    }
    func validateMeasurementData(measurement: FibriCheckCameraSDK.Measurement) -> Bool {
        
        addToLogString(txt: "Received Meausrement - Validate Data")
        addToLogString(txt: "HR: " + String(measurement.heartRate))
        addToLogString(txt: "Time Vector Length" + String(measurement.time.count))
        addToLogString(txt: "Quadrants Size:" + String(measurement.quadrants.count))
        addToLogString(txt: "measurement_timestamp" + String(measurement.startTime))
        
        return true
        
    }
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("FibriCheck Example Application")
            Text("Heartrate: " + String(heartRate))
            Button("Start Measurement", action: {
                let viewSelf = self
                
                addToLogString(txt: "Button Press")
                Task.detached {
                    
                    var threadDone = false
                    let fc = FibriChecker()
                    
                    fc.sampleTime = 10;
                    fc.pulseDetectionExpiryTime = 15000;
//                    fc.fingerDetectionExpiryTime = 500000;
                    
                    func onFingerDetected() -> Void {
                        logEvent(name: "onFingerDetected")
                    }
                    fc.onFingerDetected = onFingerDetected
                    
                    func onFingerRemoved(_:Double,_:Double,_:Double) -> Void {
                        logEvent(name: "onFingerRemoved")
                    }
                    fc.onFingerRemoved = onFingerRemoved
                    
                    
                    func onCalibrationReady() -> Void {
                        logEvent(name: "onCalibrationReady")
                    }
                    fc.onCalibrationReady = onCalibrationReady
                    
                    func onPulseDetectionTimeExpired() -> Void {
                        logEvent(name: "onPulseDetectionTimeExpired")
                    }
                    fc.onPulseDetectionTimeExpired = onPulseDetectionTimeExpired
                    
                    func onFingerDetectionTimeExpired() -> Void {
                        logEvent(name: "onFingerDetectionTimeExpired")
                        addToLogString(txt: "onFingerDetectionTimeExpired")
                    }
                    fc.onFingerDetectionTimeExpired = onFingerDetectionTimeExpired
                    
                    func onMeasurementError(_:String?) -> Void {
                        logEvent(name: "onMeasurementError")
                        print("There was a measurement error")
                        threadDone = true
                    }
                    fc.onMeasurementError = onMeasurementError
                    
                    func onMeasurementProcessed(_:FibriCheckCameraSDK.Measurement?) -> Void {
                        logEvent(name: "onMeasurementProcessed")
                    }
                    fc.onMeasurementProcessed = onMeasurementProcessed
                    
                    func onSampleReady(_:Double, _:Double) -> Void {
                        logEvent(name: "onSampleReady")
                    }
                    fc.onSampleReady = onSampleReady
                    
                    func onTimeRemaining(_:UInt) -> Void {
                        logEvent(name: "onTimeRemaining")
                    }
                    fc.onTimeRemaining = onTimeRemaining
                    
                    func onMeasurementStart() -> Void {
                        logEvent(name: "onMeasurementStart")
                        addToLogString(txt: "measurement started")
                    }
                    fc.onMeasurementStart = onMeasurementStart
                    
                    
                    func onMeasurementFinished() -> Void {
                        logEvent(name: "onMeasurementFinished")
                        
                        print("Measurement finished")
                        addToLogString(txt: "measurement finished")
                        threadDone = true
                    }
                    fc.onMeasurementFinished = onMeasurementFinished
                    
                    
                    func onHeartBeat(hr: UInt) -> Void {
                        logEvent(name: "onHeartBeat")
                        print("Received HeartRate " + String(hr))
                        
                        DispatchQueue.main.async {
                            print("Update HeartRate")
                            viewSelf.heartRate = hr
                        }
                        
                    }
                    fc.onHeartBeat = onHeartBeat
                    
                    
                    func onMovementDetected() -> Void {
                        logEvent(name: "onMovementDetected")
                    }
                    fc.onMovementDetected = onMovementDetected
                    
                    func onPulseDetected() -> Void {
                        logEvent(name: "onPulseDetected")
                    }
                    fc.onPulseDetected = onPulseDetected
                    
                    
                    fc.startMeasurement()
                    
                    while !threadDone {
                        usleep(1)
                    }
                }
                
                
                
                
                
                
            }).buttonStyle(.bordered)
            Text(receivedEventsString)
            Text(logString)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
