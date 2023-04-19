#import <Foundation/Foundation.h>

@class Measurement;

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

#pragma mark - Callbacks

@property (copy) void (^onFingerDetected)(void);
@property (copy) void (^onFingerRemoved)(double, double, double);
@property (copy) void (^onHeartBeat)(NSUInteger);
@property (copy) void (^onPulseDetected)(void);
@property (copy) void (^onCalibrationReady)(void);
@property (copy) void (^onPulseDetectionTimeExpired)(void);
@property (copy) void (^onFingerDetectionTimeExpired)(void);
@property (copy) void (^onMovementDetected)(void);
@property (copy) void (^onMeasurementStart)(void);
@property (copy) void (^onMeasurementFinished)(void);
@property (copy) void (^onMeasurementError)(NSString*);
@property (copy) void (^onMeasurementProcessed)(Measurement*);
@property (copy) void (^onSampleReady)(double, double);
@property (copy) void (^onTimeRemaining)(NSUInteger);

#pragma mark - Methods

-(void)startMeasurement;
-(void)startRecording;
-(void)stop;
-(void)updateConfiguration;

@end
