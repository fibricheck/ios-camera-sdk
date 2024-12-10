#import "MeasurementController.h"
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>

#import "DataPoint.h"
#import "Measurement.h"
#import "BeatListener.h"
#import "ImageProcessor.h"
#import "ImageProcessorConfig.h"

#define FINGER_GOOD_COUNT 25
#define FINGER_BAD_COUNT 7
#define CALIBRATION_DELAY 1

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

@interface MeasurementController()

@property BOOL fingerDetected;
@property BOOL isFingerDetectionGracePeriodActive;
@property BOOL initialFingerDetectionState;
@property BOOL calibrationReadyDispatched;

@property NSTimeInterval recordingStartTime;
@property NSTimeInterval fingerDetectionStartTime;
@property NSTimeInterval pulseDetectionStartTime;
@property NSTimeInterval calibrationStartTime;
@property AVCaptureSession* session;
@property AVCaptureDevice* camera;
@property CMMotionManager* motionManager;

@property NSInteger fingerBadCount;
@property NSInteger fingerGoodCount;
@property NSInteger previousTime;
@property NSString* dimensions;
@property float iso;
@property float exposure;
@property float accelerationFactor;

@property MeasurementControllerState state;
@property MeasurementControllerState previousState;
@property MeasurementControllerEvent event;

@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@end

@implementation MeasurementController

-(instancetype)init {
    self = [super init];
    if (self) {
        _state = MeasurementControllerStateDetectingFinger;
        _previousState = MeasurementControllerStateDetectingFinger;
        _event = MeasurementControllerEventInit;
        _accelerationFactor = 9.81;
        _calibrationReadyDispatched = NO;
        _isFingerDetectionGracePeriodActive = NO;
        _fingerBadCount = 0;
        _fingerGoodCount = 0;
        _fingerDetected = NO;
        _initialFingerDetectionState = YES;
        _previousTime = _sampleTime;
        _attempts = 0;
    }
    return self;
}

- (void)startMeasurement {
    // Reset Values
    [self resetState];

    // Init Helpers
    ImageProcessorConfig * config = [self configImageProcessor];
    self.measurement = [[Measurement alloc] initWithConfig:config];
    self.imageProcessor = [[ImageProcessor alloc] initWithConfig:config];
    self.beatListener = [BeatListener new];

    //Motion
    [self startMovementDetection];
    [self registerForNotifications];

    self.dispatchQueue = dispatch_queue_create("MeasureControllerDispatchQueue", DISPATCH_QUEUE_SERIAL);

    [self startCamera];
}

- (void)startRecording {
    self.state = MeasurementControllerStateRecording;
}

- (void)unloadAll {
    // NSLog(@"---------Removing observers-------");
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.motionManager = nil;
    self.measurement = nil;
    self.imageProcessor = nil;
    self.beatListener = nil;

    [self stopCamera];
}

#pragma mark - Private API

- (ImageProcessorConfig*)configImageProcessor {
    return [[ImageProcessorConfig alloc] initWithRowSize:self.quadrantRows
                                                 colSize:self.quadrantCols
                                                    maxY:self.maxYValue
                                                    minY:self.minYValue
                                              maxStdDevY:self.maxStdDevYValue
                                                    minV:self.minVValue];
}

- (void)resetState {
    [self setCameraExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    self.fingerBadCount = self.fingerGoodCount = 0;
    self.calibrationReadyDispatched = self.fingerDetected = NO;
    self.initialFingerDetectionState = YES;
}

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetState)
                                                 name:UIApplicationWillResignActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startCamera)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)startMovementDetection {
    if (self.motionManager == nil) {
        self.motionManager = [CMMotionManager new];
    }
    if (self.motionManager.accelerometerAvailable && !self.motionManager.accelerometerActive) {
        [self.motionManager startAccelerometerUpdates];
    }
    if (self.motionManager.gyroAvailable && !self.motionManager.gyroActive) {
        [self.motionManager startGyroUpdates];
    }
    if (self.motionManager.deviceMotionAvailable && !self.motionManager.deviceMotionActive) {
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical];
    }
}

- (void)startCamera {
    self.session = [AVCaptureSession new];
    self.camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError * error = nil;
    AVCaptureInput * cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:_camera error:&error];
    if (cameraInput) {
        [self.session addInput:cameraInput];
        [self.session setSessionPreset:AVCaptureSessionPresetLow];
    } else{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveError)]) {
            [self.delegate measurementControllerDidReceiveError];
        }
    }

    AVCaptureInput *input = [self.session.inputs objectAtIndex:0];
    AVCaptureInputPort *port = [input.ports objectAtIndex:0];
    
    NSLog(@"Register observer to input port format description change");

    // Register as an observer for the AVCaptureInputPortFormatDescriptionDidChangeNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputPortFormatDescriptionDidChange:)
                                                 name:AVCaptureInputPortFormatDescriptionDidChangeNotification
                                               object:port];

    if ([self.camera lockForConfiguration:NULL]) {
        [self.camera setActiveVideoMinFrameDuration:CMTimeMake(10,300)];
        [self.camera setActiveVideoMaxFrameDuration:CMTimeMake(10,300)];
        [self.camera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [self.camera unlockForConfiguration];
    }

    AVCaptureVideoDataOutput * videoOutput = [AVCaptureVideoDataOutput new];
    [videoOutput setSampleBufferDelegate:self queue:self.dispatchQueue];
    videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:
                                      @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    videoOutput.alwaysDiscardsLateVideoFrames=NO;

    [self.session addOutput:videoOutput];
    [self.session startRunning];

    
    

    if (self.flashEnabled && [self.camera isTorchModeSupported:AVCaptureTorchModeOn]) {
        [self.camera lockForConfiguration:nil];
        self.camera.torchMode = AVCaptureTorchModeOn;
        [self.camera unlockForConfiguration];
    }
}

// Method called when the notification is received
- (void)inputPortFormatDescriptionDidChange:(NSNotification *)notification {
    // Handle the format description change
    NSLog(@"Camera input port format description changed");
    if (self.session.inputs.count > 0) {
        AVCaptureInput *input = [self.session.inputs objectAtIndex:0];
        AVCaptureInputPort *port = [input.ports objectAtIndex:0];
        CMFormatDescriptionRef formatDescription = port.formatDescription;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
        self.dimensions = [NSString stringWithFormat:@"%dx%d", dimensions.width, dimensions.height];
        
    } else {
        NSLog(@"Camera Port Format Inputs not accessible");
    }
}

- (void)stopCamera {
    if (self.session) {
        [self.session stopRunning];
    }

    AVCaptureDevice * camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (camera) {
        if (self.flashEnabled && [camera isTorchModeSupported:AVCaptureTorchModeOff]){
            [camera lockForConfiguration:nil];
            camera.torchMode = AVCaptureTorchModeOff;
            [camera unlockForConfiguration];
        }
    }
}

- (void)setCameraExposureMode:(AVCaptureExposureMode)exposureMode {
    [self.camera lockForConfiguration:nil];
    [self.camera setExposureMode:AVCaptureExposureModeCustom];
    
    float maxIso = self.camera.activeFormat.maxISO;
    float minIso = self.camera.activeFormat.minISO;
    
    self.iso = self.camera.ISO > maxIso ? maxIso : self.camera.ISO;
    self.iso = self.iso < minIso ? minIso : self.iso;
    
    CMTime currentExposure = self.camera.exposureDuration;
    self.exposure = CMTimeGetSeconds(currentExposure);
    
    // NSLog(@"--------------------------Current iso: %f, current exposure: %f", self.iso, self.exposure);
    [self.camera setExposureModeCustomWithDuration:currentExposure ISO:self.iso completionHandler:nil];
    [self.camera unlockForConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    DataPoint *dp = [self.imageProcessor processImageBuffer:sampleBuffer];
    [self detectFinger:dp];
    switch (_state) {
        case MeasurementControllerStateDetectingFinger:
            if (_fingerDetectionExpiryTime == 0 || _event == MeasurementControllerEventFingerDetected || _event == MeasurementControllerEventFingerDetectionTimeExpired) {
                _state = MeasurementControllerStateDetectingPulse;
                break;
            }
            if (_previousState != MeasurementControllerStateDetectingFinger) {
                [self resetState];
                _fingerDetectionStartTime = currentTime;

                [self notifyDelegateDidChangeState:MeasurementControllerStateDetectingFinger];
                _previousState = MeasurementControllerStateDetectingFinger;
            }
            [self checkFingerDetectionTimer];

            break;
        case MeasurementControllerStateDetectingPulse:
            if (_pulseDetectionExpiryTime == 0 || _event == MeasurementControllerEventPulseDetected || _event == MeasurementControllerEventPulseDetectionTimeExpired) {
                // NSLog(@"Going to calibration state: %lu", _pulseDetectionExpiryTime);
                _state = MeasurementControllerStateCalibrating;
                break;
            }
            if (_previousState != MeasurementControllerStateDetectingPulse) {
                // NSLog(@"Checking pulse now: %lu", _pulseDetectionExpiryTime);
                [self.beatListener clear];
                _pulseDetectionStartTime = currentTime;

                [self notifyDelegateDidChangeState:MeasurementControllerStateDetectingPulse];
                _previousState = MeasurementControllerStateDetectingPulse;
            }

            [self.beatListener correlateWithValue:dp.filterValue];
            [self notifyDelegateDidReceiveSample:dp];
            [self detectPulse];
            [self checkPulseDetectionTimer];

            break;
        case MeasurementControllerStateCalibrating:
            if (_previousState != MeasurementControllerStateCalibrating) {
                [self setCameraExposureMode:AVCaptureExposureModeLocked];
                _calibrationStartTime = [[NSDate date] timeIntervalSince1970];

                [self notifyDelegateDidChangeState: MeasurementControllerStateCalibrating];
                _previousState = MeasurementControllerStateCalibrating;
            }

            [self.beatListener correlateWithValue:dp.filterValue];
            [self notifyDelegateDidReceiveSample:dp];
            [self checkCalibrationTimer];

            break;
        case MeasurementControllerStateRecording:
            if (_event == MeasurementControllerEventTimerAboveSampleTime) {
                _state = MeasurementControllerStateFinished;
            }
            if (_previousState != MeasurementControllerStateRecording) {
                _measurement = [[Measurement alloc] initWithConfig:[self configImageProcessor]];
                _recordingStartTime = currentTime;
                _attempts += 1;

                [self notifyDelegateDidStartRecording];
                [self notifyDelegateDidChangeState: MeasurementControllerStateRecording];
                
                _previousState = MeasurementControllerStateRecording;
            }

            [self checkMeasurementCompletion];

            [self collectMotionData:dp];
            dp.tms = (currentTime - self.recordingStartTime) * 1000;
            [self.beatListener correlateWithValue:dp.filterValue];
            [self notifyDelegateDidReceiveSample:dp];
            [self.measurement addDataPoint:dp];

            if (_beatListener.isPeakDetected && _beatListener.isValidPulse) {
                [self notifyDelegateHeartRateUpdated:self.beatListener.heartRate];
            }
            [self checkMeasurementCompletion];

            break;
        case MeasurementControllerStateFinished:
            if (_previousState != MeasurementControllerStateFinished) {
                self.measurement.technical_details[@"camera_resolution"] = self.dimensions;
                self.measurement.technical_details[@"camera_iso"] = [NSNumber numberWithFloat: self.iso];
                self.measurement.technical_details[@"camera_exposure_time"] = [NSNumber numberWithFloat: self.exposure*1000000000.0];
                self.measurement.startTime = self.recordingStartTime;
                self.measurement.heartRate = self.beatListener.heartRate;
                self.measurement.skippedMovementDetection = self.skippedMovementDetection;
                self.measurement.skippedFingerDetection = self.skippedFingerDetection;
                self.measurement.skippedPulseDetection = self.skippedPulseDetection;
                self.measurement.attempts = self.attempts;

                [self notifyDelegateDidChangeState:MeasurementControllerStateFinished];
                _previousState = MeasurementControllerStateFinished;
            }
            break;
        default:
            break;
    }
}

- (void) detectFinger: (DataPoint*)dp {
    if (_fingerDetectionExpiryTime == 0) {
        return;
    }

    if ([self.imageProcessor fingerOnCamera:dp]) {
        self.fingerGoodCount++;
        self.fingerBadCount = 0;
    } else if(!_isFingerDetectionGracePeriodActive) {
        self.fingerBadCount++;
        self.fingerGoodCount = 0;
    }

    if (self.fingerDetectionExpiryTime != 0 && (self.initialFingerDetectionState || self.fingerDetected) && self.fingerBadCount >= FINGER_BAD_COUNT) {
        self.fingerDetected = NO;
        self.initialFingerDetectionState = NO;
        self.state = MeasurementControllerStateDetectingFinger;
        self.event = MeasurementControllerEventFingerRemoved;
        [self notifyDelegateDidReceiveFingerRemoved:dp];
    }

    if (!self.fingerDetected && self.fingerGoodCount > FINGER_GOOD_COUNT) {
        self.isFingerDetectionGracePeriodActive = YES;
        self.initialFingerDetectionState = NO;
        self.fingerDetected = YES;
        self.event = MeasurementControllerEventFingerDetected;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.isFingerDetectionGracePeriodActive = NO;
        });
        [self notifyDelegateDidReceiveFingerDetected];
    }
}

- (void) detectPulse {
    if ([self.beatListener isPulseDetected]) {
        self.event = MeasurementControllerEventPulseDetected;
        [self notifyDelegateDidReceivePulseDetected];
    }
}

- (void) detectMovementWithAccX: (float) accx accY:(float)accy accZ:(float)accz {
    double accVector =  sqrt( pow(accx,2) + pow(accy,2) + pow(accz,2) );
    if (accVector == 0 && self.movementDetectionEnabled) {
        [self notifyDelegateDidReceiveBrokenAccSensorData];
        [self stopCamera];
    }

    if (accVector > self.movementVectorUpperLimit || accVector < self.movementVectorLowerLimit) {
        if (self.movementDetectionEnabled) {
            self.state = MeasurementControllerStateDetectingFinger;
        }
        [self notifyDelegateDidReceiveMovement];
    }
}

- (void) collectMotionData: (DataPoint*) dp {
    float accx = self.motionManager.accelerometerData.acceleration.x * self.accelerationFactor;
    float accy = self.motionManager.accelerometerData.acceleration.y * self.accelerationFactor;
    float accz = self.motionManager.accelerometerData.acceleration.z * self.accelerationFactor;

    if (self.accEnabled) {
        dp.hasAcc = YES;
        dp.accx = accx;
        dp.accy = accy;
        dp.accz = accz;
    }
    if (self.gyroEnabled) {
        dp.hasGyr = YES;
        dp.gyrx = RADIANS_TO_DEGREES(self.motionManager.gyroData.rotationRate.x);
        dp.gyry = RADIANS_TO_DEGREES(self.motionManager.gyroData.rotationRate.y);
        dp.gyrz = RADIANS_TO_DEGREES(self.motionManager.gyroData.rotationRate.z);
    }
    if (self.gravEnabled) {
        dp.hasGrav = YES;
        dp.gravx = self.motionManager.deviceMotion.gravity.x;
        dp.gravy = self.motionManager.deviceMotion.gravity.y;
        dp.gravz = self.motionManager.deviceMotion.gravity.z;
    }
    if (self.rotationEnabled) {
        dp.hasOri = YES;
        dp.orix = RADIANS_TO_DEGREES(self.motionManager.deviceMotion.attitude.pitch);
        dp.oriy = RADIANS_TO_DEGREES(self.motionManager.deviceMotion.attitude.roll) ;
        dp.oriz = RADIANS_TO_DEGREES(self.motionManager.deviceMotion.attitude.yaw);
    }

    [self detectMovementWithAccX:accx accY:accy accZ:accz];
}

- (void) checkCalibrationTimer {
    if (!self.calibrationReadyDispatched && ([[NSDate date] timeIntervalSince1970] - self.calibrationStartTime) > CALIBRATION_DELAY) {
        [self notifyDelegateCalibrationReady];
        self.calibrationReadyDispatched = YES;
    }

    if (self.calibrationReadyDispatched && !self.waitForStartRecordingSignal) {
        self.state = MeasurementControllerStateRecording;
    }
}

- (void) checkFingerDetectionTimer {
    if (self.fingerDetectionExpiryTime > 0 && ([[NSDate date] timeIntervalSince1970] - self.fingerDetectionStartTime) > self.fingerDetectionExpiryTime) {
        self.skippedFingerDetection = YES;
        self.event = MeasurementControllerEventFingerDetectionTimeExpired;
        [self notifyDelegateDidReceiveFingerDetectionTimeout];
    }
}

- (void) checkPulseDetectionTimer {
    if (self.pulseDetectionExpiryTime > 0 && ([[NSDate date] timeIntervalSince1970] - self.pulseDetectionStartTime) > self.pulseDetectionExpiryTime) {
        self.skippedPulseDetection = YES;
        self.event = MeasurementControllerEventPulseDetectionTimeExpired;
        [self notifyDelegateDidReceivePulseDetectionTimeout];
    }
}

- (void) checkMeasurementCompletion {
    int elapsedTime = ([[NSDate date] timeIntervalSince1970] - self.recordingStartTime);
    long timeRemaining = self.sampleTime - elapsedTime;

    if (timeRemaining != self.previousTime) {
        self.previousTime = timeRemaining;
        [self notifyDelegateProgressUpdated:timeRemaining];
    }

    if (elapsedTime > self.sampleTime) {
        self.event = MeasurementControllerEventTimerAboveSampleTime;
    }
}


#pragma mark - Delegate Management

- (void)notifyDelegateHeartRateUpdated:(NSUInteger)heartRate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:heartRateUpdated:)]) {
            [self.delegate measurementController:self heartRateUpdated:heartRate];
        }
    });
}

- (void)notifyDelegateProgressUpdated:(NSUInteger)elapsedTime {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:progressUpdated:)]) {
            [self.delegate measurementController:self progressUpdated:elapsedTime];
        }
    });
}

- (void)notifyDelegateDidReceiveBrokenAccSensorData {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:didReceiveMeasurementError:)]) {
            [self.delegate measurementController:self didReceiveMeasurementError:@"BROKEN_ACC_SENSOR"];
        }
    });
}

- (void)notifyDelegateDidChangeState:(MeasurementControllerState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController: didChangeState:)]) {
            [self.delegate measurementController:self didChangeState:state];
        }
    });
}

- (void)notifyDelegateDidReceiveFingerDetected {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveFingerDetected)]) {
            [self.delegate measurementControllerDidReceiveFingerDetected];
        }
    });
}

- (void)notifyDelegateDidReceiveFingerRemoved:(DataPoint*)dp {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:didReceiveFingerRemoved:)]) {
            [self.delegate measurementController:self didReceiveFingerRemoved:dp];
        }
    });
}

- (void)notifyDelegateCalibrationReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveCalibrationReady)]) {
            [self.delegate measurementControllerDidReceiveCalibrationReady];
        }
    });
}

- (void)notifyDelegateDidStartRecording {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidStartRecording)]) {
            [self.delegate measurementControllerDidStartRecording];
        }
    });
}

- (void)notifyDelegateDidReceiveMovement {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveMovement)]) {
            [self.delegate measurementControllerDidReceiveMovement];
        }
    });
}

- (void)notifyDelegateDidReceivePulseDetected {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceivePulseDetected)]) {
            [self.delegate measurementControllerDidReceivePulseDetected];
        }
    });
}

- (void)notifyDelegateDidReceiveFingerDetectionTimeout {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveFingerDetectionTimeout)]) {
            [self.delegate measurementControllerDidReceiveFingerDetectionTimeout];
        }
    });
}

- (void)notifyDelegateDidReceivePulseDetectionTimeout {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceivePulseDetectionTimeout)]) {
            [self.delegate measurementControllerDidReceivePulseDetectionTimeout];
        }
    });
}

- (void)notifyDelegateDidReceiveSample:(DataPoint*)dp {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:didReceiveSample:)]) {
            [self.delegate measurementController:self didReceiveSample:dp];
        }
    });
}

@end
