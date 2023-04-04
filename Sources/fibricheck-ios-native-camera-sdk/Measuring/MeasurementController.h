#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//@class MeasurementDeprecated;
@class ImageProcessor;
@class BeatListener;
@class DataPoint;
@class Measurement;

@protocol MeasurementControllerDelegate;

typedef NS_ENUM(NSInteger, MeasurementControllerState) {
    MeasurementControllerStateDetectingFinger,
    MeasurementControllerStateDetectingPulse,
    MeasurementControllerStateCalibrating,
    MeasurementControllerStateRecording,
    MeasurementControllerStateFinished
};

typedef NS_ENUM(NSInteger, MeasurementControllerEvent) {
    MeasurementControllerEventInit,
    MeasurementControllerEventFingerDetected,
    MeasurementControllerEventFingerRemoved,
    MeasurementControllerEventPulseDetected,
    MeasurementControllerEventTimerAboveSampleTime,
    MeasurementControllerEventPulseDetectionTimeExpired,
    MeasurementControllerEventFingerDetectionTimeExpired,
    MeasurementControllerEventStartRecording
};

@interface MeasurementController : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) id <MeasurementControllerDelegate> delegate;

@property (assign) float movementVectorUpperLimit;
@property (assign) float movementVectorLowerLimit;
@property (assign) BOOL waitForStartRecordingSignal;
@property (assign) BOOL flashEnabled;
@property (assign) BOOL movementDetectionEnabled;
@property (assign) BOOL skippedMovementDetection;
@property (assign) BOOL skippedPulseDetection;
@property (assign) BOOL skippedFingerDetection;
@property (assign) BOOL gyroEnabled;
@property (assign) BOOL accEnabled;
@property (assign) BOOL gravEnabled;
@property (assign) BOOL rotationEnabled;
@property (assign) NSUInteger sampleTime;
@property (assign) NSUInteger attempts;
@property (assign) NSUInteger pulseDetectionExpiryTime;
@property (assign) NSUInteger fingerDetectionExpiryTime;
@property (assign) NSUInteger quadrantRows;
@property (assign) NSUInteger quadrantCols;
@property (assign) NSUInteger maxYValue;
@property (assign) NSUInteger minYValue;
@property (assign) NSUInteger maxStdDevYValue;
@property (assign) NSUInteger minVValue;

@property Measurement * measurement;
@property BeatListener * beatListener;
@property ImageProcessor * imageProcessor;

- (void)startMeasurement;
- (void)startRecording;
- (void)unloadAll;

@end

@protocol MeasurementControllerDelegate <NSObject>

@optional
- (void)measurementController:(MeasurementController *)measurementController didReceiveSample:(DataPoint *)datapoint;
- (void)measurementController:(MeasurementController *)measurementController didChangeState:(MeasurementControllerState)state;
- (void)measurementController:(MeasurementController *)measurementController progressUpdated:(NSUInteger)elapsedTime;
- (void)measurementController:(MeasurementController *)measurementController heartRateUpdated:(NSUInteger)heartRate;
- (void)measurementController:(MeasurementController *)measurementController didReceiveMeasurementError:(NSString*)message;
- (void)measurementController:(MeasurementController *)measurementController didReceiveFingerRemoved:(DataPoint *)datapoint;

- (void)measurementControllerDidStartRecording;
- (void)measurementControllerDidReceiveError;
- (void)measurementControllerDidReceiveMovement;
- (void)measurementControllerDidReceiveFingerDetected;
- (void)measurementControllerDidReceivePulseDetected;
- (void)measurementControllerDidReceivePulseDetectionTimeout;
- (void)measurementControllerDidReceiveFingerDetectionTimeout;
- (void)measurementControllerDidReceiveCalibrationReady;

@end
