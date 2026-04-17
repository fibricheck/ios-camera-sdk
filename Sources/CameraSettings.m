//
//  CameraSettings.m
//  FibriCheckCameraSDK
//
//  Created by Estelle Berghmans on 11/12/2025.
//

#import "CameraSettings.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVCaptureDevice.h>

NS_ASSUME_NONNULL_BEGIN

#define LOG_CAMERA_SETTINGS false
#define LOG_ACCURACY 0.001

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

static NSString* _Nullable colorSpaceToHdrProfile(AVCaptureColorSpace colorSpace) {
    switch (colorSpace) {
        case AVCaptureColorSpace_sRGB:
            return @"sRGB";
        case AVCaptureColorSpace_P3_D65:
            return @"P3-D65";
        case AVCaptureColorSpace_AppleLog:
            return @"AppleLog";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        case AVCaptureColorSpace_AppleLog2:
            return @"AppleLog2";
#endif
        case AVCaptureColorSpace_HLG_BT2020:
            return @"HLG-BT2020";
        default: return @"unknown";
    }
}

@implementation CameraSettingsInput

// Implementation
- (instancetype)initWithValues:(CameraSettingMode)internal_exposureMode
    internal_manualIso:(NSUInteger)internal_manualIso
    internal_manualExposureTime:(NSUInteger)internal_manualExposureTime
    internal_whiteBalanceMode:(WhiteBalanceMode)internal_whiteBalanceMode
    internal_manualWhiteBalanceRgb:(RgbColor)internal_manualWhiteBalanceRgb
    internal_manualWhiteBalanceKelvin:(NSUInteger)internal_manualWhiteBalanceKelvin
    internal_focusMode:(CameraSettingMode)internal_focusMode
    internal_manualFocus:(CGFloat)internal_manualFocus
    internal_hdrMode:(HdrMode)internal_hdrMode
    internal_logExposure:(BOOL)internal_logExposure
    internal_logWhiteBalance:(BOOL)internal_logWhiteBalance
    internal_logFocus:(BOOL)internal_logFocus
    internal_logHdr: (BOOL)internal_logHdr {

    self = [super init];
    if (self) {
        _internal_exposureMode = internal_exposureMode;
        _internal_manualIso = internal_manualIso;
        _internal_manualExposureTime = internal_manualExposureTime;
        _internal_whiteBalanceMode = internal_whiteBalanceMode;
        _internal_manualWhiteBalanceRgb = internal_manualWhiteBalanceRgb;
        _internal_manualWhiteBalanceKelvin = internal_manualWhiteBalanceKelvin;
        _internal_focusMode = internal_focusMode;
        _internal_manualFocus = internal_manualFocus;
        _internal_hdrMode = internal_hdrMode;
        _internal_logExposure = internal_logExposure;
        _internal_logWhiteBalance = internal_logWhiteBalance;
        _internal_logFocus = internal_logFocus;
        _internal_logHdr = internal_logHdr;
    }
    return self;
}

@end

@implementation CameraSettings {
    NSUInteger _frameIndex;
    NSUInteger _lastLoggedIso;
    NSUInteger _lastLoggedExposureTime;
    RgbColor _lastLoggedWhiteBalance;
    CGFloat _lastLoggedFocus;
    NSInteger _lastLoggedHdr;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        // CameraSettingsInput properties
        // Before these settings were added, exposure acted in what is now 'Locked' mode
        self.internal_exposureMode = CameraModeLocked;
        self.internal_manualIso = 0;
        self.internal_manualExposureTime = 0;

        // Before these settings were added, white balance acted in what is now 'Auto' mode
        self.internal_whiteBalanceMode = WhiteBalanceModeAuto;
        self.internal_manualWhiteBalanceRgb = (RgbColor) { .r = 0.0f, .g = 0.0f, .b = 0.0f };
        self.internal_manualWhiteBalanceKelvin = 5000;

        // Before these settings were added, focus acted in what is now called 'Auto' mode
        self.internal_focusMode = CameraModeAuto;
        self.internal_manualFocus = 0.0f;

        self.internal_hdrMode = HdrOff;

        self.internal_logExposure = false;
        self.internal_logWhiteBalance = true;
        self.internal_logFocus = true;
        self.internal_logHdr = false;

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

        _frameIndex = 0;
        _lastLoggedIso = -1;
        _lastLoggedExposureTime = -1;
        _lastLoggedWhiteBalance = (RgbColor){ .r = -1.0f, .g = -1.0f, .b = -1.0f };
        _lastLoggedFocus = -1.0f;
        _lastLoggedHdr = -1;
    }

    return self;
}

- (void)clear {
    if (LOG_CAMERA_SETTINGS) {
        NSLog(@"Cleared all logs");
    }

    [self.isoLog removeAllObjects];
    [self.exposureTimeLog removeAllObjects];
    [self.focusLog removeAllObjects];
    [self.whiteBalanceLog removeAllObjects];
    [self.hdrLog removeAllObjects];

    _frameIndex = 0;
    _lastLoggedIso = -1;
    _lastLoggedExposureTime = -1;
    _lastLoggedWhiteBalance = (RgbColor){ .r = -1.0f, .g = -1.0f, .b = -1.0f };
    _lastLoggedFocus = -1.0f;
    _lastLoggedHdr = -1;
    _hdrProfile = nil;
}

- (NSMutableDictionary *)getCameraSettingsOutput {
    NSMutableDictionary* output = [[NSMutableDictionary alloc] init];

    NSString* exposureModeString = cameraSettingModeToString(self.internal_exposureMode);
    NSString* whiteBalanceModeString = whiteBalanceModeToString(self.internal_whiteBalanceMode);
    NSString* focusModeString = cameraSettingModeToString(self.internal_focusMode);
    NSString* hdrModeString = hdrModeToString(self.internal_hdrMode);

    if (self.internal_exposureMode != CameraModeLocked && exposureModeString != nil) {
        output[@"exposure_mode"] = exposureModeString;
    }
    if (focusModeString != nil) {
        output[@"focus_mode"] = focusModeString;
    }
    if (self.internal_whiteBalanceMode != WhiteBalanceModeLocked && whiteBalanceModeString != nil) {
        output[@"white_balance_mode"] = whiteBalanceModeString;
    }
    if (hdrModeString != nil) {
        output[@"hdr_mode"] = hdrModeString;
    }

    if (self.internal_exposureMode == CameraModeAuto && self.isoLog.count > 0) {
        output[@"iso"] = self.isoLog;
        output[@"exposure_time"] = self.exposureTimeLog;
    }
    if (self.internal_focusMode == CameraModeAuto && self.focusLog.count > 0) {
        output[@"focus"] = self.focusLog;
    }
    if (self.internal_whiteBalanceMode == WhiteBalanceModeAuto && self.whiteBalanceLog.count > 0) {
        output[@"white_balance"] = self.whiteBalanceLog;
    }
    if (self.internal_hdrMode == HdrAuto && _hdrLog.count > 0) {
        output[@"hdr"] = _hdrLog;
    }
    output[@"hdr_profile"] = self.hdrProfile;


    return output;
}

- (NSMutableDictionary*)getTechnicalDetailsOutput {
    NSMutableDictionary* technicalDetails = [[NSMutableDictionary alloc] init];

    if (self.internal_exposureMode != CameraModeAuto) {
        technicalDetails[@"camera_iso"] = [NSNumber numberWithFloat: self.iso];
        technicalDetails[@"camera_exposure_time"] = [NSNumber numberWithFloat: self.exposureTime];
    }

    if (self.internal_focusMode != CameraModeAuto) {
        technicalDetails[@"camera_focus_distance"] = [NSNumber numberWithFloat: self.focus];
    }

    if (self.internal_whiteBalanceMode != WhiteBalanceModeAuto) {
        technicalDetails[@"camera_white_balance"] = @{
            @"r": [NSNumber numberWithFloat: self.whiteBalance.r],
            @"g": [NSNumber numberWithFloat: self.whiteBalance.g],
            @"b": [NSNumber numberWithFloat: self.whiteBalance.b]
        };
    }

    if (self.hdrStatus != nil) {
        technicalDetails[@"camera_hdr"] = [NSString stringWithString:self.hdrStatus];
    }

    return technicalDetails;
}

- (void)set:(CameraSettingsInput *)input {
    self.internal_exposureMode = input.internal_exposureMode;
    self.internal_manualIso = input.internal_manualIso;
    self.internal_manualExposureTime = input.internal_manualExposureTime;
    self.internal_whiteBalanceMode = input.internal_whiteBalanceMode;
    self.internal_manualWhiteBalanceRgb = input.internal_manualWhiteBalanceRgb;
    self.internal_manualWhiteBalanceKelvin = input.internal_manualWhiteBalanceKelvin;
    self.internal_focusMode = input.internal_focusMode;
    self.internal_manualFocus = input.internal_manualFocus;
    self.internal_hdrMode = input.internal_hdrMode;
    self.internal_logExposure = input.internal_logExposure;
    self.internal_logWhiteBalance = input.internal_logWhiteBalance;
    self.internal_logFocus = input.internal_logFocus;
    self.internal_logHdr = input.internal_logHdr;
}

- (void)updateAutoSettings:(nonnull AVCaptureDevice *)camera {
    // We can update the auto values if the setting is not 'locked', or if we are locked we may update it during the 'calibrating phase'
    // This will also update the auto value if we're in manual mode but that is ok

    if (self.internal_focusMode != CameraModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
        self.autoFocus = camera.lensPosition;
        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Updated auto lens position to %f", camera.lensPosition);
        }
    }
    else if (LOG_CAMERA_SETTINGS) {
        NSLog(@"Focus locked, value should be: %f, actual value: %f", self.autoFocus, camera.lensPosition);
    }

    if (self.internal_whiteBalanceMode != WhiteBalanceModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
        AVCaptureWhiteBalanceGains gains = camera.deviceWhiteBalanceGains;
        self.autoWhiteBalance = (RgbColor) { .r = gains.redGain, .g = gains.greenGain, .b = gains.blueGain };

        if (LOG_CAMERA_SETTINGS) {
            NSLog(@"Updated auto white balance to %f, %f, %f", self.autoWhiteBalance.r, self.autoWhiteBalance.g, self.autoWhiteBalance.b);
        }
    }
    else if (LOG_CAMERA_SETTINGS) {
        NSLog(@"White balance locked, value should be: %f, %f, %f, actual value: %f, %f, %f", self.autoWhiteBalance.r, self.autoWhiteBalance.g, self.autoWhiteBalance.b, camera.deviceWhiteBalanceGains.redGain, camera.deviceWhiteBalanceGains.greenGain, camera.deviceWhiteBalanceGains.blueGain);
    }

    if (self.internal_exposureMode != CameraModeLocked || self.cameraSettingState == CameraSettingStateCalibrating) {
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

    NSUInteger currentFrame = _frameIndex++;

    if (self.internal_logExposure && self.internal_exposureMode == CameraModeAuto) {
        if (_autoIso != _lastLoggedIso || _autoExposureTime != _lastLoggedExposureTime) {
            [self.isoLog addObject: @[@(_autoIso), @(currentFrame)]];
            [self.exposureTimeLog addObject: @[@(_autoExposureTime), @(currentFrame)]];
            _lastLoggedIso = _autoIso;
            _lastLoggedExposureTime = _autoExposureTime;

            if (LOG_CAMERA_SETTINGS) {
                NSLog(@"Added entry to exposure log at frame %lu", currentFrame);
            }
        }
    }

    if (self.internal_logWhiteBalance && self.internal_whiteBalanceMode == WhiteBalanceModeAuto) {
        RgbColor wb = _autoWhiteBalance;
        if (fabs(wb.r - _lastLoggedWhiteBalance.r) > LOG_ACCURACY || fabs(wb.g - _lastLoggedWhiteBalance.g) > LOG_ACCURACY || fabs(wb.b - _lastLoggedWhiteBalance.b) > LOG_ACCURACY) {
            [self.whiteBalanceLog addObject: @[@(wb.r), @(wb.g), @(wb.b), @(currentFrame)]];
            _lastLoggedWhiteBalance = wb;

            if (LOG_CAMERA_SETTINGS) {
                NSLog(@"Added entry to white balance log at frame %lu", currentFrame);
            }
        }
    }

    if (self.internal_logFocus && self.internal_focusMode == CameraModeAuto) {
        if (fabs(_autoFocus - _lastLoggedFocus) > LOG_ACCURACY) {
            [self.focusLog addObject: @[@(_autoFocus), @(currentFrame)]];
            _lastLoggedFocus = _autoFocus;

            if (LOG_CAMERA_SETTINGS) {
                NSLog(@"Added entry to focus log at frame %lu", currentFrame);
            }
        }
    }

    if (self.internal_logHdr && self.internal_hdrMode == HdrAuto) {
        NSInteger hdrValue = camera.isVideoHDREnabled ? 1 : 0;
        if (hdrValue != _lastLoggedHdr) {
            [self.hdrLog addObject: @[@(hdrValue), @(currentFrame)]];
            _lastLoggedHdr = hdrValue;

            if (LOG_CAMERA_SETTINGS) {
                NSLog(@"Added entry to hdr log at frame %lu", currentFrame);
            }
        }
    }

    self.hdrProfile = colorSpaceToHdrProfile(camera.activeColorSpace);

    if (!camera.activeFormat.isVideoHDRSupported) {
        self.hdrStatus = @"hdr-unsupported";
    }
    else if (camera.automaticallyAdjustsVideoHDREnabled && camera.videoHDREnabled) {
        self.hdrStatus = @"hdr-auto-on";
    }
    else if (camera.automaticallyAdjustsVideoHDREnabled && !camera.videoHDREnabled) {
        self.hdrStatus = @"hdr-auto-off";
    }
    else if (!camera.automaticallyAdjustsVideoHDREnabled && camera.videoHDREnabled) {
        self.hdrStatus = @"hdr-manual-on";
    }
    else if (!camera.automaticallyAdjustsVideoHDREnabled && !camera.videoHDREnabled) {
        self.hdrStatus = @"hdr-manual-off";
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
    if (!camera.activeFormat.isVideoHDRSupported) {
        return;
    }

    [camera setAutomaticallyAdjustsVideoHDREnabled:self.internal_hdrMode == HdrAuto];
    if (self.internal_hdrMode != HdrAuto) {
        [camera setVideoHDREnabled:self.internal_hdrMode == HdrOn];
    }
}

// Getters for primitive types
- (NSUInteger)iso {
    if (self.internal_exposureMode == CameraModeManual)
        return self.internal_manualIso;

    return self.autoIso;
}

- (NSUInteger)exposureTime {
    if (self.internal_exposureMode == CameraModeManual)
        return self.internal_manualExposureTime;

    return self.autoExposureTime;
}

- (CGFloat)focus {
    if (self.internal_focusMode == CameraModeManual)
        return self.internal_manualFocus;

    return self.autoFocus;
}

// Getter for struct type
- (RgbColor)whiteBalance {
    if (self.internal_whiteBalanceMode == WhiteBalanceModeManualRgb)
        return self.internal_manualWhiteBalanceRgb;

    return self.autoWhiteBalance;
}

- (BOOL)isAutoExposure {
    return self.internal_exposureMode == CameraModeAuto || (self.internal_exposureMode == CameraModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

- (BOOL)isAutoWhiteBalance {
    return self.internal_whiteBalanceMode == WhiteBalanceModeAuto || (self.internal_whiteBalanceMode == WhiteBalanceModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

- (BOOL)isAutoFocus {
    return self.internal_focusMode == CameraModeAuto || (self.internal_focusMode == CameraModeLocked && self.cameraSettingState == CameraSettingStateCalibrating);
}

@end

NS_ASSUME_NONNULL_END
