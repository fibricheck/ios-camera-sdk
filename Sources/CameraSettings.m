//
//  CameraSettings.m
//  FibriCheckCameraSDK
//
//  Created by Brent Berghmans on 11/12/2025.
//

#import "CameraSettings.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

#define LOG_CAMERA_SETTINGS false

static NSString* _Nullable whiteBalanceModeToString(WhiteBalanceMode mode) {
    if (mode == WhiteBalanceModeAuto) return @"auto";
    if (mode == WhiteBalanceModeLocked) return @"locked";
    if (mode == WhiteBalanceModeManualRgb) return @"manual";
    if (mode == WhiteBalanceModeManualKelvin) return @"manual";
    return nil;
};

static NSString* _Nullable cameraSettingModeToString(CameraSettingMode mode) {
    if (mode == CameraModeAuto) return @"auto";
    if (mode == CameraModeLocked) return @"locked";
    if (mode == CameraModeManual) return @"manual";
    return nil;
};

static NSString* _Nullable hdrModeToString(HdrMode mode) {
    if (mode == HdrAuto) return @"auto";
    if (mode == HdrOn) return @"on";
    if (mode == HdrOff) return @"off";
    return nil;
}

void splitRgbArray(NSMutableArray<NSValue *> *colors,
                   NSMutableArray<NSNumber *> **rValues,
                   NSMutableArray<NSNumber *> **gValues,
                   NSMutableArray<NSNumber *> **bValues) {

    // Create the arrays if they don't exist
    if (!*rValues) *rValues = [NSMutableArray array];
    if (!*gValues) *gValues = [NSMutableArray array];
    if (!*bValues) *bValues = [NSMutableArray array];

    // Clear existing contents
    [*rValues removeAllObjects];
    [*gValues removeAllObjects];
    [*bValues removeAllObjects];

    for (NSValue *value in colors) {
        RgbColor color;
        [value getValue:&color];

        [*rValues addObject:@(color.r)];
        [*gValues addObject:@(color.g)];
        [*bValues addObject:@(color.b)];
    }
}

@implementation CameraSettingsInput

// Implementation
- (instancetype)initWithValues:(CameraSettingMode)exposureMode
    manualIso:(NSUInteger)manualIso
    manualExposureTime:(NSUInteger)manualExposureTime
    whiteBalanceMode:(WhiteBalanceMode)whiteBalanceMode
    manualWhiteBalanceRgb:(RgbColor)manualWhiteBalanceRgb
    manualWhiteBalanceKelvin:(NSUInteger)manualWhiteBalanceKelvin
    focusMode:(CameraSettingMode)focusMode
    manualFocus:(CGFloat)manualFocus
    hdrMode:(HdrMode)hdrMode
    logExposure:(BOOL)logExposure
    logWhiteBalance:(BOOL)logWhiteBalance
    logFocus:(BOOL)logFocus
    logHdr: (BOOL)logHdr {
    
    self = [super init];
    if (self) {
        _exposureMode = exposureMode;
        _manualIso = manualIso;
        _manualExposureTime = manualExposureTime;
        _whiteBalanceMode = whiteBalanceMode;
        _manualWhiteBalanceRgb = manualWhiteBalanceRgb;
        _manualWhiteBalanceKelvin = manualWhiteBalanceKelvin;
        _focusMode = focusMode;
        _manualFocus = manualFocus;
        _hdrMode = hdrMode;
        _logExposure = logExposure;
        _logWhiteBalance = logWhiteBalance;
        _logFocus = logFocus;
        _logHdr = logHdr;
    }
    return self;
}

@end

@implementation CameraSettings

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // CameraSettingsInput properties
        // Before these settings were added, exposure acted in what is now 'Locked' mode
        self.exposureMode = CameraModeLocked;
        self.manualIso = 0;
        self.manualExposureTime = 0;
        
        // Before these settings were added, white balance acted in what is now 'Auto' mode
        self.whiteBalanceMode = WhiteBalanceModeAuto;
        self.manualWhiteBalanceRgb = (RgbColor) { .r = 0.0f, .g = 0.0f, .b = 0.0f };
        self.manualWhiteBalanceKelvin = 5000;
        
        // Before these settings were added, focus acted in what is now called 'Auto' mode
        self.focusMode = CameraModeAuto;
        self.manualFocus = 0.0f;
        
        self.hdrMode = HdrAuto;
        
        self.logExposure = false;
        self.logWhiteBalance = false;
        self.logFocus = false;
        self.logHdr = false;
        
        // Extended properties
        _cameraSettingState = CameraSettingStateCalibrating;
        
        _autoIso = 0;
        _autoExposureTime = 0;
        _autoWhiteBalance = (RgbColor) { .r = 0.0f, .g = 0.0f, .b = 0.0f };
        _autoFocus = 0.0f;
        
        _isoLog = [NSMutableArray array];
        _exposureTimeLog = [NSMutableArray array];
        _whiteBalanceLog = [NSMutableArray array];
        _focusLog = [NSMutableArray array];
        _hdrLog = [NSMutableArray array];
    }
    
    return self;
}

- (void)clear {
    if (LOG_CAMERA_SETTINGS) {
        NSLog(@"Cleared all logs");
    }
    
    [self.isoLog removeAllObjects];
    [self.focusLog removeAllObjects];
    [self.whiteBalanceLog removeAllObjects];
    [self.hdrLog removeAllObjects];
}

- (NSMutableDictionary *)getCameraSettingsOutput {
    NSMutableDictionary* output = [[NSMutableDictionary alloc] init];
    
    NSString* exposureModeString = cameraSettingModeToString(self.exposureMode);
    NSString* whiteBalanceModeString = whiteBalanceModeToString(self.whiteBalanceMode);
    NSString* focusModeString = cameraSettingModeToString(self.focusMode);
    NSString* hdrModeString = hdrModeToString(self.hdrMode);
    
    if (self.exposureMode != CameraModeLocked && exposureModeString != nil) {
        output[@"exposure_mode"] = exposureModeString;
    }
    if (self.focusMode != CameraModeLocked && exposureModeString != nil) {
        output[@"focus_mode"] = focusModeString;
    }
    if (self.whiteBalanceMode != WhiteBalanceModeLocked && whiteBalanceModeString != nil) {
        output[@"white_balance_mode"] = whiteBalanceModeString;
    }
    if (self.hdrMode != HdrAuto && hdrModeString != nil) {
        output[@"hdr_mode"] = hdrModeString;
    }
    
    if (self.exposureMode == CameraModeAuto && self.isoLog.count > 0) {
        output[@"iso"] = self.isoLog;
        output[@"exposure_time"] = self.exposureTimeLog;
    }
    if (self.focusMode == CameraModeAuto && self.focusLog.count > 0) {
        output[@"focus"] = self.focusLog;
    }
    if (self.whiteBalanceMode == WhiteBalanceModeAuto && self.whiteBalanceLog.count > 0) {
        NSMutableArray<NSNumber *> *r, *g, *b;
        splitRgbArray(self.whiteBalanceLog, &r, &g, &b);
        
        output[@"white_balance"] = @{
            @"r": r,
            @"g": g,
            @"b": b
        };
    }
    if (self.hdrMode == HdrAuto && _hdrLog.count > 0) {
        output[@"hdr"] = _hdrLog;
    }

    
    return output;
}

- (NSMutableDictionary*)getTechnicalDetailsOutput {
    NSMutableDictionary* technicalDetails = [[NSMutableDictionary alloc] init];
    
    if (self.exposureMode != CameraModeAuto) {
        technicalDetails[@"camera_iso"] = [NSNumber numberWithFloat: self.iso];
        technicalDetails[@"camera_exposure_time"] = [NSNumber numberWithFloat: self.exposureTime];
    }
    
    if (self.focusMode != CameraModeAuto) {
        technicalDetails[@"camera_focus_distance"] = [NSNumber numberWithFloat: self.focus];
    }
    
    if (self.whiteBalanceMode != WhiteBalanceModeAuto) {
        technicalDetails[@"camera_white_balance"] = @{
            @"r": [NSNumber numberWithFloat: self.whiteBalance.r],
            @"g": [NSNumber numberWithFloat: self.whiteBalance.g],
            @"b": [NSNumber numberWithFloat: self.whiteBalance.b]
        };
    }
    
    if (self.hdrMode != HdrAuto) {
        BOOL isOn = self.hdrMode == HdrOn;
        technicalDetails[@"camera_hdr"] = [NSNumber numberWithBool: isOn];
    }
    
    return technicalDetails;
}

- (void)set:(CameraSettingsInput *)input {
    self.exposureMode = input.exposureMode;
    self.manualIso = input.manualIso;
    self.manualExposureTime = input.manualExposureTime;
    self.whiteBalanceMode = input.whiteBalanceMode;
    self.manualWhiteBalanceRgb = input.manualWhiteBalanceRgb;
    self.manualWhiteBalanceKelvin = input.manualWhiteBalanceKelvin;
    self.focusMode = input.focusMode;
    self.manualFocus = input.manualFocus;
    self.hdrMode = input.hdrMode;
    self.logExposure = input.logExposure;
    self.logWhiteBalance = input.logWhiteBalance;
    self.logFocus = input.logFocus;
    self.logHdr = input.logHdr;
}

- (void)updateAutoSettings:(nonnull AVCaptureDevice *)camera {
    // We can update the auto values if the setting is not 'locked', or if we are locked we may update it during the 'calibrating phase'
    // This will also update the auto value if we're in manual mode but that is ok
    
    if (self.focusMode != CameraModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
        self.autoFocus = camera.lensPosition;
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Updated auto lens position to %f", camera.lensPosition);
        }
    }
    else if (LOG_CAMERA_SETTINGS) {
        NSLog(@"Focus locked, value should be: %f, actual value: %f", self.autoFocus, camera.lensPosition);
    }
    
    if (self.whiteBalanceMode != WhiteBalanceModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
        AVCaptureWhiteBalanceGains gains = camera.deviceWhiteBalanceGains;
        self.autoWhiteBalance = (RgbColor) { .r = gains.redGain, .g = gains.greenGain, .b = gains.blueGain };
        
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Updated auto white balance to %f, %f, %f", self.autoWhiteBalance.r, self.autoWhiteBalance.g, self.autoWhiteBalance.b);
        }
    }
    else if (LOG_CAMERA_SETTINGS) {
        NSLog(@"White balance locked, value should be: %f, %f, %f, actual value: %f, %f, %f", self.autoWhiteBalance.r, self.autoWhiteBalance.g, self.autoWhiteBalance.b, camera.deviceWhiteBalanceGains.redGain, camera.deviceWhiteBalanceGains.greenGain, camera.deviceWhiteBalanceGains.blueGain);
    }
    
    if (self.exposureMode != CameraModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
        self.autoIso = camera.ISO;
        self.autoExposureTime = CMTimeGetSeconds(camera.exposureDuration) * 1000000000; // Convert exposure time to nanoseconds
        
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Updated auto ISO %lu, exposure time %lu", self.autoIso, self.autoExposureTime);
        }
    }
    else if (LOG_CAMERA_SETTINGS) {
        NSUInteger exposure = CMTimeGetSeconds(camera.exposureDuration) * 1000000000;
        NSLog(@"Exposure locked, value should be: ISO %lu, Exposure %lu, actual ISO %f, Epoxusre %lu", self.autoIso, self.autoExposureTime, camera.ISO, exposure);
    }
    
    // Early return if we are calibrating
    // We don't want to log values whilst still calibrating
    if (self.cameraSettingState == CameraSettingStateCalibrating) {
        return;
    }
    
    if (self.logExposure && self.exposureMode == CameraModeAuto) {
        [self.isoLog addObject: [NSNumber numberWithUnsignedInteger:_autoIso]];
        [self.exposureTimeLog addObject: [NSNumber numberWithUnsignedInteger:_autoExposureTime]];
        
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Added entry to exposure log");
        }
    }
    
    if (self.logWhiteBalance && self.whiteBalanceMode == WhiteBalanceModeAuto) {
        [self.whiteBalanceLog addObject: [NSValue valueWithBytes:&_autoWhiteBalance objCType:@encode(RgbColor)]];
        
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Added entry to white balance log");
        }
    }
    
    if (self.logFocus && self.focusMode == CameraModeAuto) {
        [self.focusLog addObject: [NSNumber numberWithFloat:_autoFocus]];
        
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Added entry to focus log");
        }
    }
    
    if (self.logHdr && self.hdrMode == HdrAuto) {
        [self.hdrLog addObject: [NSNumber numberWithBool:camera.isVideoHDREnabled]];
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Added entry to hdr log");
        }
    }
}

- (void)apply:(AVCaptureDevice *)camera {
    [camera lockForConfiguration:nil];
    
    [self applyExposure:camera];
    [self applyWhiteBalance:camera];
    [self applyFocus:camera];
    [self applyHdr:camera];
    
    [camera unlockForConfiguration];
}

- (void)applyExposure:(AVCaptureDevice*)camera {
    if (self.isAutoExposure) {
        [camera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        return;
    }
    
    [camera setExposureMode:AVCaptureExposureModeCustom];
    
    float maxIso = camera.activeFormat.maxISO;
    float minIso = camera.activeFormat.minISO;
    
    float iso = self.iso > maxIso ? maxIso : self.iso;
    iso = iso < minIso ? minIso : iso;
    
    Float64 exposureTimeSeconds = self.exposureTime / 1e9;
    CMTime exposureTime = CMTimeMakeWithSeconds(exposureTimeSeconds, 1000000000);

    if ([camera isExposureModeSupported:AVCaptureExposureModeCustom]) {
        [camera setExposureModeCustomWithDuration:exposureTime ISO:iso completionHandler:nil];
    }
    else {
        NSLog(@"Warning: Tried to configure manual exposure but it is not supported on this system");
    }
}

- (void) applyWhiteBalance:(AVCaptureDevice*)camera {
    if (self.isAutoWhiteBalance) {
        if ([camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        else if([camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        
        return;
    }
    
    AVCaptureWhiteBalanceGains gains;
    gains.redGain = self.whiteBalance.r;
    gains.greenGain = self.whiteBalance.g;
    gains.blueGain = self.whiteBalance.b;
    
    if ([camera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked]) {
        [camera setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:nil];
    }
    else {
        NSLog(@"Warning: Tried to configure manual white balance but it is not supported on this system");
    }
}

- (void) applyFocus:(AVCaptureDevice*)camera {
    if (self.isAutoFocus) {
        if ([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [camera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        else if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [camera setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        
        return;
    }
    
    if ([camera isFocusModeSupported:AVCaptureFocusModeLocked]) {
        [camera setFocusModeLockedWithLensPosition:self.focus completionHandler:nil];
    }
    else {
        NSLog(@"Warning: Tried to configure manual focus but it is not supported on this system");
    }
}

- (void) applyHdr:(AVCaptureDevice*)camera {
    [camera setAutomaticallyAdjustsVideoHDREnabled:self.hdrMode == HdrAuto];
    if (self.hdrMode != HdrAuto) {
        [camera setVideoHDREnabled:self.hdrMode == HdrOn];
    }
}

// Getters for primitive types
- (NSUInteger)iso {
    if (self.exposureMode == CameraModeManual)
        return self.manualIso;
    
    return self.autoIso;
}

- (NSUInteger)exposureTime {
    if (self.exposureMode == CameraModeManual)
        return self.manualExposureTime;
    
    return self.autoExposureTime;
}

- (CGFloat)focus {
    if (self.focusMode == CameraModeManual)
        return self.manualFocus;
    
    return self.autoFocus;
}

// Getter for struct type
- (RgbColor)whiteBalance {
    if (self.whiteBalanceMode == WhiteBalanceModeManualRgb)
        return self.manualWhiteBalanceRgb;
    
    return self.autoWhiteBalance;
}

- (BOOL)isAutoExposure {
    return self.exposureMode == CameraModeAuto || (self.exposureMode == CameraModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

- (BOOL)isAutoWhiteBalance {
    return self.whiteBalanceMode == WhiteBalanceModeAuto || (self.whiteBalanceMode == WhiteBalanceModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

- (BOOL)isAutoFocus {
    return self.focusMode == CameraModeAuto || (self.focusMode == CameraModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

@end

NS_ASSUME_NONNULL_END
