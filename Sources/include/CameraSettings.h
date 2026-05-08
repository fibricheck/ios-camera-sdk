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

typedef NS_ENUM(NSUInteger, HdrMode) {
    HdrOn,
    HdrOff,
    HdrAuto
};

typedef NS_ENUM(NSUInteger, CameraSettingState) {
    CameraSettingStateCalibrating,
    CameraSettingStateRecording
};

@interface CameraSettingsInput : NSObject

@property (nonatomic, assign) CameraSettingMode internal_exposureMode;
@property (nonatomic, assign) NSUInteger internal_manualIso;
@property (nonatomic, assign) NSUInteger internal_manualExposureTime;

@property (nonatomic, assign) WhiteBalanceMode internal_whiteBalanceMode;
@property (nonatomic, assign) RgbColor internal_manualWhiteBalanceRgb;
@property (nonatomic, assign) NSUInteger internal_manualWhiteBalanceKelvin;

@property (nonatomic, assign) CameraSettingMode internal_focusMode;
@property (nonatomic, assign) CGFloat internal_manualFocus;

@property (nonatomic, assign) HdrMode internal_hdrMode;

@property (nonatomic, assign) BOOL internal_logExposure;
@property (nonatomic, assign) BOOL internal_logWhiteBalance;
@property (nonatomic, assign) BOOL internal_logFocus;
@property (nonatomic, assign) BOOL internal_logHdr;

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
    internal_logHdr:(BOOL)internal_logHdr
NS_SWIFT_NAME(init(values:internal_manualIso:internal_manualExposureTime:internal_whiteBalanceMode:internal_manualWhiteBalanceRgb:internal_manualWhiteBalanceKelvin:internal_focusMode:internal_manualFocus:internal_hdrMode:internal_logExposure:internal_logWhiteBalance:internal_logFocus:internal_logHdr:));

@end

@interface CameraSettings : CameraSettingsInput

@property (nonatomic, assign) CameraSettingState cameraSettingState;
@property (nonatomic, assign) NSUInteger autoIso;
@property (nonatomic, assign) NSUInteger autoExposureTime;
@property (nonatomic, assign) RgbColor autoWhiteBalance;
@property (nonatomic, assign) CGFloat autoFocus;
@property (nonatomic, assign) NSString* hdrStatus;
@property (nonatomic, strong, nullable) NSString* hdrProfile;

@property (nonatomic, strong) NSMutableArray<NSArray*>* isoLog;
@property (nonatomic, strong) NSMutableArray<NSArray*>* exposureTimeLog;
@property (nonatomic, strong) NSMutableArray<NSArray*>* whiteBalanceLog;
@property (nonatomic, strong) NSMutableArray<NSArray*>* focusLog;
@property (nonatomic, strong) NSMutableArray<NSArray*>* hdrLog;

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
