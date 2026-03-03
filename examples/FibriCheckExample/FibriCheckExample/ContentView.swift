//
//  ContentView.swift
//  FibriCheckExample
//
//  Created by Christopher Hex on 04/05/2023.
//

import SwiftUI
import FibriCheckCameraSDK


func validateQuadrants(measurement: FibriCheckCameraSDK.Measurement) -> Bool {
    
    var yuvSampleSums: [Double] = []
    
    guard let quadrants = measurement.quadrants else {
        return false
    }
    
    //Get sum of first YUV item in every quadrant
    for row in 0...3 {
        let rowData = quadrants[row] as! NSArray
        for col in 0...3 {
            let data = rowData[col] as! FibriCheckCameraSDK.YUV

            let y = (data.y as [AnyObject])[1] as! Double
            let u = (data.u as [AnyObject])[1] as! Double
            let v = (data.v as [AnyObject])[1] as! Double
            yuvSampleSums.append(y+u+v)
        }
    }
    
    // Create a set out of the sumData array
    let yuvSampleSumsSet: Set<Double> = Set(yuvSampleSums)
    
    //If array length equals set length, there are no unique values, which is what we want
    let isUnique: Bool = yuvSampleSums.count == yuvSampleSumsSet.count
    
    return isUnique
}

struct ContentView: View {
    @State var heartRate: UInt = 0
    
    
    init() {
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
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("FibriCheck Example Application")
            Text("Heartrate: " + String(heartRate))
            Button("Start Measurement", action: {
                            let viewSelf = self
                            
                            
                            Task.detached {
                            
                                var threadDone = false
                            
                                func handleError(_: String?) -> Void {
                                    print("There was a measurement error")
                                    threadDone = true
                                }

                                func handleMeasurementStart() -> Void {
                                    print("Measurement started")

                                }

                                func handleMeasurementFinished() -> Void {
                                    print("Measurement finished")
                                    threadDone = true
                                }

                                func handleHeartRate(hr: UInt) -> Void {
                                    print("Received HeartRate " + String(hr))
                                    DispatchQueue.main.async {
                                        print("Update HeartRate")
                                        viewSelf.heartRate = hr
                                    }

                                }

                                func handleMovementDetected() -> Void {
                                    print("Movement Detected")
                                }
                                
                                
                                func handlePulseDetection() -> Void {
                                    print("Pulse Detected")
                                }
                                
                                func handleMeasurementProcessed(measurement: FibriCheckCameraSDK.Measurement?) -> Void {
                                    
                                    guard let measurement = measurement else { return }
                                    let _ = measurement.mapToJson()
                                    let dict = measurement.mapToDictionary()!
                                    let cameraSettings = dict["camera_settings"] as? NSMutableDictionary;
                                    let technicalDetails = dict["technical_details"] as! NSMutableDictionary;
                                    
                                    if (cameraSettings != nil) {
                                        dump(cameraSettings);
                                    }
                                    
                                    dump(technicalDetails);
             
                                    print("Measurement Finalized")
                                    let validationResult = validateQuadrants(measurement: measurement)
                                    print("Quadrant Validation Result: " + String(validationResult))
                                    
                                }
                           
                                let fc = FibriChecker()

                                fc.onMeasurementError = handleError
                                fc.onMeasurementStart = handleMeasurementStart
                                fc.onMovementDetected = handleMovementDetected
                                fc.onMeasurementFinished = handleMeasurementFinished
                                fc.onMeasurementProcessed = handleMeasurementProcessed
                                fc.onHeartBeat = handleHeartRate
                                fc.onPulseDetected = handlePulseDetection
                                
                                fc.accEnabled = true;
                                fc.sampleTime = 10;
                                
                                fc.setCameraSettings(
                                    CameraSettingsInput(
                                        values: CameraSettingMode.modeLocked,
                                        manualIso: 0,
                                        manualExposureTime: 0,
                                        
                                        whiteBalanceMode: WhiteBalanceMode.locked,
                                        manualWhiteBalanceRgb: RgbColor(r: 0.0, g: 0.0, b: 0.0),
                                        manualWhiteBalanceKelvin: 5000,
                                        
                                        focus: CameraSettingMode.modeLocked,
                                        manualFocus: 0,
                                        
                                        hdrMode: HdrMode.auto,
                                        
                                        logExposure: true,
                                        logWhiteBalance: true,
                                        logFocus: true,
                                        logHdr: true
                                        
                                    )
                                )

                                fc.startMeasurement()
                                
                                while !threadDone {
                                    usleep(1)
                                }
                            }
                            
                            
                            
                            
                            
                            
            }).buttonStyle(.bordered)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
