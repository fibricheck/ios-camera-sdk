#import "MeasurementController.h"
#import <Foundation/NSObjCRuntime.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>

#import "DataPoint.h"
#import "Measurement.h"
#import "BeatListener.h"
#import "ImageProcessor.h"
#import "ImageProcessorConfig.h"
#import "CameraInfo.h"
#import "CameraSettings.h"

#define FINGER_GOOD_COUNT 25
#define FINGER_BAD_COUNT 7
#define CALIBRATION_DELAY 1

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))

@interface MeasurementController()

@property BOOL fingerDetected;
@property BOOL isFingerDetectionGracePeriodActive;
@property BOOL initialFingerDetectionState;
@property BOOL calibrationReadyDispatched;
@property BOOL isCameraInit;

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
@property float accelerationFactor;

@property MeasurementControllerState state;
@property MeasurementControllerState previousState;
@property MeasurementControllerEvent event;
@property (assign) BOOL previewEnabled;

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
        _cameraSettings =[[CameraSettings alloc] init];
        _imageWidth = 0;
        _imageHeight = 0;
        _isCameraInit = NO;
        _session = [AVCaptureSession new];
        _dispatchQueue = dispatch_queue_create("MeasureControllerDispatchQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (AVCaptureSession *)captureSession {
    return self.session;
}

- (void)startPreview {
    NSLog(@"[MeasurementController][startPreview]");
    self.previewEnabled = YES;
    self.state = MeasurementControllerStatePreview;
    self.previousState = MeasurementControllerStatePreview;

    [self startCamera];
    [self notifyDelegateDidChangeState:MeasurementControllerStatePreview];
}

- (void)stopPreview {
    NSLog(@"[MeasurementController][stopPreview]");
    self.previewEnabled = NO;
    if (self.state == MeasurementControllerStatePreview) {
        [self stopCamera];
    }
}

- (void)startMeasurement {
    NSLog(@"[MeasurementController][startMeasurement]");
    // Reset Values
    [self resetState];

    // Init Helpers
    ImageProcessorConfig * config = [self configImageProcessor];
    self.measurement = [[Measurement alloc] initWithConfig:config];
    self.imageProcessor = [[ImageProcessor alloc] initWithConfig:config];
    self.beatListener = [BeatListener new];
    self.beatListener.delegate = self;
    
    //Motion
    [self startMovementDetection];
    [self registerForNotifications];

    self.previewEnabled = NO;
    [self startCamera];
}

- (void)startRecording {
    self.state = MeasurementControllerStateRecording;
}

- (void)unloadAll {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.previewEnabled = NO;
    self.motionManager = nil;
    self.measurement = nil;
    self.imageProcessor = nil;
    self.beatListener = nil;

    [self stopCamera];
    self.session = nil;
    self.camera = nil;
    self.isCameraInit = NO;
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
    [self.cameraSettings clear];
    [self unlockCameraSettings];
    [self.measurement.camera_settings removeAllObjects];
    self.fingerBadCount = self.fingerGoodCount = 0;
    self.calibrationReadyDispatched = self.fingerDetected = NO;
    self.initialFingerDetectionState = YES;
    self.state = MeasurementControllerStateDetectingFinger;
    self.previousState = MeasurementControllerStateDetectingFinger;
    self.event = MeasurementControllerEventInit;
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

- (void) initCamera {
    if (self.isCameraInit) {
        return;
    }
    
    self.camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError * error = nil;
    AVCaptureInput * cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:_camera error:&error];
    if (cameraInput) {
        [self.session addInput:cameraInput];
        [self.session setSessionPreset:AVCaptureSessionPresetLow];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementControllerDidReceiveError)]) {
            [self.delegate measurementControllerDidReceiveError];
        }
        return;
    }
    self.isCameraInit = true;
    
    AVCaptureInput *input = [self.session.inputs objectAtIndex:0];
    AVCaptureInputPort *port = [input.ports objectAtIndex:0];
    
    // Register as an observer for the AVCaptureInputPortFormatDescriptionDidChangeNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputPortFormatDescriptionDidChange:)
                                                 name:AVCaptureInputPortFormatDescriptionDidChangeNotification
                                               object:port];
    
    AVCaptureVideoDataOutput * videoOutput = [AVCaptureVideoDataOutput new];
    [videoOutput setSampleBufferDelegate:self queue:self.dispatchQueue];
    videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:
                                      @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    videoOutput.alwaysDiscardsLateVideoFrames=NO;

    [self.session addOutput:videoOutput];
}

- (void)startCamera {
    [self initCamera];
    dispatch_async(self.dispatchQueue, ^{
        [self.session startRunning];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self configureCamera];
        });
    });
}

- (void)stopCamera {
    NSLog(@"[MeasurementController][stopCamera]");
    [self disableTorch];

    if (self.session) {
        dispatch_async(self.dispatchQueue, ^{
            [self.session stopRunning];
        });
    }
}

- (void)configureTorch {
    NSLog(@"[MeasurementController][configureTorch]");
    if (self.flashEnabled && _state != MeasurementControllerStatePreview) {
        [self enableTorch];
    }
    else {
        [self disableTorch];
    }
}

- (void)enableTorch {
    NSLog(@"[MeasurementController][enableTorch]");
    if ([self.camera isTorchModeSupported:AVCaptureTorchModeOn]) {
        [self.camera lockForConfiguration: nil];
        [self.camera setTorchMode: AVCaptureTorchModeOn];
        [self.camera unlockForConfiguration];
    }
}

- (void)disableTorch {
    NSLog(@"[MeasurementController][disableTorch]");
    if ([self.camera isTorchModeSupported:AVCaptureTorchModeOff]) {
        [self.camera lockForConfiguration: nil];
        self.camera.torchMode = AVCaptureTorchModeOff;
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
        self.imageWidth = dimensions.width;
        self.imageHeight = dimensions.height;
    } else {
        NSLog(@"Camera Port Format Inputs not accessible");
    }
}

- (void)unlockCameraSettings {
    self.cameraSettings.cameraSettingState = CameraSettingStateCalibrating;
    [self.cameraSettings apply:self.camera];
}

- (void)lockCameraSettings {
    self.cameraSettings.cameraSettingState = CameraSettingStateRecording;
    [self.cameraSettings apply:self.camera];
}

- (void)configureFrameDuration {
    [self.camera lockForConfiguration: nil];
    [self.camera setActiveVideoMinFrameDuration:CMTimeMake(10,300)];
    [self.camera setActiveVideoMaxFrameDuration:CMTimeMake(10,300)];
    [self.camera unlockForConfiguration];
}

- (void)configureCamera {
    [self.cameraSettings apply:self.camera];
    [self configureTorch];
    [self configureFrameDuration];
}

- (NSString*)getFocusMode {
    switch(self.camera.focusMode) {
        case AVCaptureFocusModeLocked:
            return @"locked";
        case AVCaptureFocusModeAutoFocus:
            return @"auto-focus";
        case AVCaptureFocusModeContinuousAutoFocus:
            return @"continuous-auto-focus";
    }
    
    return @"unknown";
}

- (NSString*)getExposureMode {
    switch(self.camera.exposureMode) {
        case AVCaptureExposureModeCustom:
            return @"custom";
        case AVCaptureExposureModeLocked:
            return @"locked";
        case AVCaptureExposureModeAutoExpose:
            return @"auto-exposure";
        case AVCaptureExposureModeContinuousAutoExposure:
            return @"continuous-auto-exposure";
    }
    
    return @"unknown";
}

- (NSString*)getWhiteBalanceMode {
    switch(self.camera.whiteBalanceMode) {
        case AVCaptureWhiteBalanceModeLocked:
            return @"locked";
        case AVCaptureWhiteBalanceModeAutoWhiteBalance:
            return @"auto-white-balance";
        case AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance:
            return @"continuous-auto-white-balance";
    }
    
    return @"unknown";
}

- (NSString*)getActiveColorSpace {
    switch(self.camera.activeColorSpace) {
        case AVCaptureColorSpace_sRGB:
            return @"sRGB";
        case AVCaptureColorSpace_P3_D65:
            return @"P3-D65";
        case AVCaptureColorSpace_AppleLog:
            return @"AppleLog";
        case AVCaptureColorSpace_AppleLog2:
            return @"AppleLog2";
        case AVCaptureColorSpace_HLG_BT2020:
            return @"HLG-BT2020";
    }
    
    return @"unknown";
}

- (NSString*)getMinimumFocusDistance {
    if (@available(iOS 15.0, *)) {
        return [[NSNumber numberWithLong:self.camera.minimumFocusDistance] stringValue];
    } else {
        return @"unsupported";
    }
}

- (NSString*)getIsGlobalTonemappingEnabled {
    if (@available(iOS 13.0, *)) {
        return self.camera.isGlobalToneMappingEnabled ? @"true" : @"false";
    } else {
        return @"unsupported";
    }
}

- (NSString*)getIsGeometricDistortionCorrectionSupported {
    if (@available(iOS 13.0, *)) {
        return self.camera.isGeometricDistortionCorrectionSupported ? @"true" : @"false";
    } else {
        return @"unsupported";
    }
}

- (NSString*)getIsGeometricDistortionCorrectionEnabled {
    if (@available(iOS 13.0, *)) {
        return self.camera.isGeometricDistortionCorrectionEnabled ? @"true" : @"false";
    } else {
        return @"unsupported";
    }
}

- (NSDictionary*)getCameraSettings:(NSInteger)imageWidth imageHeight:(NSInteger)imageHeight {
    if (self.dimensions == nil || self.camera == nil) {
        NSDictionary *empty = @{};
        return empty;
    }

    AVCaptureWhiteBalanceGains gains = self.camera.deviceWhiteBalanceGains;
    AVCaptureWhiteBalanceGains grayGains = self.camera.grayWorldDeviceWhiteBalanceGains;
    NSDictionary *metaData = @{
        // General Info
        @"modelId": self.camera.modelID,
        @"imageWidth": [[NSNumber numberWithLong:imageWidth] stringValue],
        @"imageHeight": [[NSNumber numberWithLong:imageHeight] stringValue],
        @"imageDimensions": self.dimensions,
        
        // Focus
        @"isAdjustingFocus": self.camera.isAdjustingFocus ? @"true" : @"false",
        @"focusMode": [self getFocusMode],
        @"minimumFocusDistance": [self getMinimumFocusDistance],
        @"lensPosition": [[NSNumber numberWithFloat:self.camera.lensPosition] stringValue],
        
        // Exposure
        @"isAdjustingExposure": self.camera.isAdjustingExposure ? @"true" : @"false",
        @"exposureMode": [self getExposureMode],
        @"iso": [[NSNumber numberWithFloat:self.camera.ISO] stringValue],
        @"exposureTime": [[NSNumber numberWithLong:self.camera.exposureDuration.value] stringValue],
        @"maxExposureTime": [[NSNumber numberWithLong:self.camera.activeMaxExposureDuration.value] stringValue],
        @"exposureTargetOffset": [[NSNumber numberWithFloat:self.camera.exposureTargetOffset] stringValue],
        @"exposureTargetBias": [[NSNumber numberWithFloat:self.camera.exposureTargetBias] stringValue],
        @"minExposureTargetBias": [[NSNumber numberWithFloat:self.camera.minExposureTargetBias] stringValue],
        @"maxExposureTargetBias": [[NSNumber numberWithFloat:self.camera.maxExposureTargetBias] stringValue],
        @"lensAperture": [[NSNumber numberWithFloat:self.camera.lensAperture] stringValue],
        
        // White Balance
        @"isAdjustingWhiteBalance": self.camera.isAdjustingWhiteBalance ? @"true" : @"false",
        @"whiteBalanceMode": [self getWhiteBalanceMode],
        @"whiteBalanceGains": [NSString stringWithFormat:@"{ 'r': %f, 'g': %f, 'b': %f }",  gains.redGain, gains.greenGain, gains.blueGain],
        @"grayWorldWhiteBalanceGains": [NSString stringWithFormat:@"{ 'r': %f, 'g': %f, 'b': %f }",  grayGains.redGain, grayGains.greenGain, grayGains.blueGain],
        @"maxWhiteBalanceGains": [[NSNumber numberWithFloat:self.camera.maxWhiteBalanceGain] stringValue],
        
        // HDR
        @"isHdrEnabled": self.camera.isVideoHDREnabled ? @"true" : @"false",
        @"automaticallyAdjustVideoHDREnabled": self.camera.automaticallyAdjustsVideoHDREnabled ? @"true" : @"false",
        @"isGlobalToneMappingEnabled": [self getIsGlobalTonemappingEnabled],
        @"activeColorSpace": [self getActiveColorSpace],
        
        // Zoom
        @"zoomFactor": [[NSNumber numberWithFloat:self.camera.videoZoomFactor] stringValue],
        @"minZoomFactor": [[NSNumber numberWithFloat:self.camera.minAvailableVideoZoomFactor] stringValue],
        @"maxZoomFactor": [[NSNumber numberWithFloat:self.camera.maxAvailableVideoZoomFactor] stringValue],
        @"isRampingVideoZoom": self.camera.isRampingVideoZoom ? @"true" : @"false",
        @"isGeometricDistortionCorrectionSupported": [self getIsGeometricDistortionCorrectionSupported],
        @"isGeometricDistortionCorrectionEnabled": [self getIsGeometricDistortionCorrectionEnabled],
    };
    
    return metaData;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // NSLog(@"CaptureOutput state %ld", self.state);
    if (_state == MeasurementControllerStatePreview) {
        return;
    }

    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    DataPoint *dp = [self.imageProcessor processImageBuffer:sampleBuffer];
    [self.cameraSettings updateAutoSettings:self.camera];
    
    if (self.cameraSettings.rawDataEnabled) {
        NSMutableData *rawData = [self.imageProcessor extractFrame:sampleBuffer imageWidth:_imageWidth imageHeight:_imageHeight];
        NSDictionary* metaData = [self getCameraSettings: _imageWidth imageHeight:_imageHeight];
        [self notifyDelegateOnRawData:rawData metaData:metaData];
    }

    if (self.measurement == nil || self.session == nil || self.camera == nil) {
        return;
    }
       
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
                [self lockCameraSettings];
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
                [self.measurement.technical_details addEntriesFromDictionary:[self.cameraSettings getTechnicalDetailsOutput]];
                self.measurement.camera_settings = [self.cameraSettings getCameraSettingsOutput];
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

- (CameraInfo*) cameraInfo {
    return [CameraInfo fromDevice:self.camera];
}

#pragma mark - BeatListenerDelegate

- (void)beatListenerDidDetectHeartRate:(NSUInteger)heartRate {
    [self notifyDelegateHeartRateUpdated:heartRate];
}

- (void)notifyDelegateOnRawData:(NSMutableData*) rawData metaData:(NSDictionary<NSString*, NSString*>*) metaData {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(measurementController:onRawData:metaData:)]) {
            [self.delegate measurementController:self onRawData:rawData metaData:metaData];
        }
    });
}

@end

