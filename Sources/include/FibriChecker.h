#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class Measurement;
@class CameraInfo;
@class CameraSettingsInput;

@interface FibriChecker : NSObject

#pragma mark - Configuration

@property (assign) BOOL flashEnabled;
@property (assign) BOOL gyroEnabled;
@property (assign) BOOL accEnabled;
@property (assign) BOOL gravEnabled;
@property (assign) BOOL rotationEnabled;
@property (assign) BOOL movementDetectionEnabled;
@property (assign) BOOL skippedMovementDetection;
@property (assign) BOOL skippedPulseDetection;
@property (assign) BOOL skippedFingerDetection;
@property (assign) BOOL waitForStartRecordingSignal;
@property (assign) NSUInteger quadrantRows;
@property (assign) NSUInteger quadrantCols;
@property (assign) NSUInteger sampleTime;
@property (assign) NSUInteger attempts;
@property (assign) NSUInteger pulseDetectionExpiryTime;
@property (assign) NSUInteger fingerDetectionExpiryTime;
@property (assign) NSUInteger upperMovementLimit;
@property (assign) NSUInteger lowerMovementLimit;
@property (assign) NSUInteger maxYValue;
@property (assign) NSUInteger minYValue;
@property (assign) NSUInteger maxStdDevYValue;
@property (assign) NSUInteger minVValue;

#pragma mark - Properties

@property (readonly) NSUInteger heartRate;
@property (readonly) CameraInfo* cameraInfo;
@property (nonatomic, readonly) AVCaptureSession* captureSession;

#pragma mark - Callbacks

@property (copy) void (^ _Nullable onFingerDetected)(void);
@property (copy) void (^ _Nullable onFingerRemoved)(double, double, double);
@property (copy) void (^ _Nullable onHeartBeat)(NSUInteger);
@property (copy) void (^ _Nullable onPulseDetected)(void);
@property (copy) void (^ _Nullable onCalibrationReady)(void);
@property (copy) void (^ _Nullable onPulseDetectionTimeExpired)(void);
@property (copy) void (^ _Nullable onFingerDetectionTimeExpired)(void);
@property (copy) void (^ _Nullable onMovementDetected)(void);
@property (copy) void (^ _Nullable onMeasurementStart)(void);
@property (copy) void (^ _Nullable onMeasurementFinished)(void);
@property (copy) void (^ _Nullable onMeasurementError)(NSString* _Nonnull);
@property (copy) void (^ _Nullable onMeasurementProcessed)(Measurement* _Nonnull);
@property (copy) void (^ _Nullable onSampleReady)(double, double);
@property (copy) void (^ _Nullable onTimeRemaining)(NSUInteger);
@property (copy) void (^ _Nullable onPreviewStarted)(void);

#pragma mark - Class Methods

/**
 * Returns the SDK label information for regulatory compliance.
 * @return Dictionary containing componentName, udi, ceLabel, manufacturer, releaseDate, and ifu.
 */
+ (NSDictionary<NSString *, NSString *> *)getLabel;

#pragma mark - Methods

-(void)startMeasurement;
-(void)startRecording;
-(void)startPreview;
-(void)stopPreview;
-(void)stop;
-(void)updateConfiguration;
-(void)setCameraSettings:(CameraSettingsInput*) input;

@end
