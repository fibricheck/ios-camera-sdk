//
//  CameraSettings.h
//  FibriCheckCameraSDK
//
//  Created by Brent Berghmans on 11/12/2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVCaptureDevice;

typedef struct {
    CGFloat r;
    CGFloat g;
    CGFloat b;
} RgbColor;

typedef NS_ENUM(NSUInteger, CameraSettingMode) {
    CameraModeAuto,
    CameraModeLocked,
    CameraModeManual
};

typedef NS_ENUM(NSUInteger, WhiteBalanceMode) {
    WhiteBalanceModeAuto,
    WhiteBalanceModeLocked,
    WhiteBalanceModeManualRgb,
    WhiteBalanceModeManualKelvin
};

typedef NS_ENUM(NSUInteger, CameraSettingState) {
    CameraSettingStateCalibrating,
    CameraSettingStateRecording
};

@interface CameraSettingsInput : NSObject

@property (nonatomic, assign) CameraSettingMode exposureMode;
@property (nonatomic, assign) NSUInteger manualIso;
@property (nonatomic, assign) NSUInteger manualExposureTime;

@property (nonatomic, assign) WhiteBalanceMode whiteBalanceMode;
@property (nonatomic, assign) RgbColor manualWhiteBalanceRgb;
@property (nonatomic, assign) NSUInteger manualWhiteBalanceKelvin;

@property (nonatomic, assign) CameraSettingMode focusMode;
@property (nonatomic, assign) CGFloat manualFocus;

@property (nonatomic, assign) BOOL logExposure;
@property (nonatomic, assign) BOOL logWhiteBalance;
@property (nonatomic, assign) BOOL logFocus;

- (instancetype)initWithValues:(CameraSettingMode)exposureMode
    manualIso:(NSUInteger)manualIso
    manualExposureTime:(NSUInteger)manualExposureTime

    whiteBalanceMode:(WhiteBalanceMode)whiteBalanceMode
    manualWhiteBalanceRgb:(RgbColor)manualWhiteBalanceRgb
    manualWhiteBalanceKelvin:(NSUInteger)manualWhiteBalanceKelvin

    focusMode:(CameraSettingMode)focusMode
    manualFocus:(CGFloat)manualFocus

    logExposure:(BOOL)logExposure
    logWhiteBalance:(BOOL)logWhiteBalance
    logFocus:(BOOL)logFocus;

@end

@interface CameraSettings : CameraSettingsInput

@property (nonatomic, assign) CameraSettingState cameraSettingState;
@property (nonatomic, assign) NSUInteger autoIso;
@property (nonatomic, assign) NSUInteger autoExposureTime;
@property (nonatomic, assign) RgbColor autoWhiteBalance;
@property (nonatomic, assign) CGFloat autoFocus;

@property (nonatomic, strong) NSMutableArray<NSNumber*>* isoLog;
@property (nonatomic, strong) NSMutableArray<NSNumber*>* exposureTimeLog;
@property (nonatomic, strong) NSMutableArray<NSValue*>* whiteBalanceLog;
@property (nonatomic, strong) NSMutableArray<NSNumber*>* focusLog;

@property (nonatomic, readonly) NSUInteger iso;
@property (nonatomic, readonly) NSUInteger exposureTime;
@property (nonatomic, readonly) RgbColor whiteBalance;
@property (nonatomic, readonly) CGFloat focus;

@property (nonatomic, readonly) BOOL isAutoExposure;
@property (nonatomic, readonly) BOOL isAutoWhiteBalance;
@property (nonatomic, readonly) BOOL isAutoFocus;

- (instancetype) init;

- (void) set:(CameraSettingsInput*)input;
- (void) apply:(AVCaptureDevice*)device;
- (void) clear;
- (void) updateAutoSettings:(AVCaptureDevice*) camera;

- (NSMutableDictionary*) getCameraSettingsOutput;
- (NSMutableDictionary*) getTechnicalDetailsOutput;

@end

NS_ASSUME_NONNULL_END
