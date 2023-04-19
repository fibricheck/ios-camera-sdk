#import "FibriChecker.h"
#import "BeatListener.h"
#import "MeasurementController.h"
#import "Measurement.h"
#import "DataPoint.h"

@interface FibriChecker()<MeasurementControllerDelegate>

@property (nonatomic, strong) MeasurementController * measurementController;

@end

@implementation FibriChecker

#pragma mark - Public

- (instancetype)init {
    NSLog(@"FibriChecker init");
    self = [super init];
    if (self) {
        self.measurementController = [MeasurementController new];
        self.measurementController.delegate = self;

        // Set Defaults
        self.flashEnabled = true;
        self.gyroEnabled = false;
        self.accEnabled = false;
        self.gravEnabled = false;
        self.rotationEnabled = false;
        self.waitForStartRecordingSignal = false;
        self.quadrantRows = 4;
        self.quadrantCols = 4;
        self.sampleTime = 60;
        self.pulseDetectionExpiryTime = 10;
        self.fingerDetectionExpiryTime = -1;
        self.upperMovementLimit = 14;
        self.lowerMovementLimit = 6;
        self.movementDetectionEnabled = true;
        self.maxYValue = 160;
        self.minYValue = 30;
        self.maxStdDevYValue = 35;
        self.minVValue = 150;
    }
    return self;
}
- (void)startMeasurement {
    [self updateConfiguration];
    [self.measurementController startMeasurement];
}

- (void)startRecording {
    [self.measurementController startRecording];
}

- (void)stop {
    [self.measurementController unloadAll];
}

- (NSUInteger)heartRate {
    if (self.measurementController.beatListener != nil) {
        return self.measurementController.beatListener.heartRate;
    }
    return 0;
}

#pragma mark - Internal

- (void)updateConfiguration {
    self.measurementController.flashEnabled = self.flashEnabled;
    self.measurementController.movementDetectionEnabled = self.movementDetectionEnabled;
    self.measurementController.waitForStartRecordingSignal = self.waitForStartRecordingSignal;
    self.measurementController.movementVectorUpperLimit = self.upperMovementLimit;
    self.measurementController.movementVectorLowerLimit = self.lowerMovementLimit;
    self.measurementController.quadrantCols = self.quadrantCols;
    self.measurementController.quadrantRows = self.quadrantRows;
    self.measurementController.sampleTime = self.sampleTime;
    self.measurementController.pulseDetectionExpiryTime = self.pulseDetectionExpiryTime;
    self.measurementController.fingerDetectionExpiryTime = self.fingerDetectionExpiryTime;
    self.measurementController.gyroEnabled = self.gyroEnabled;
    self.measurementController.accEnabled = self.accEnabled;
    self.measurementController.rotationEnabled = self.rotationEnabled;
    self.measurementController.gravEnabled = self.gravEnabled;
    self.measurementController.maxYValue = self.maxYValue;
    self.measurementController.minYValue = self.minYValue;
    self.measurementController.maxStdDevYValue = self.maxStdDevYValue;
    self.measurementController.minVValue = self.minVValue;
    self.measurementController.skippedMovementDetection = !self.movementDetectionEnabled;
}

#pragma mark - MeasureControllerDelegate

- (void)measurementController:(MeasurementController *)measurementController didChangeState:(MeasurementControllerState)state {
    if (state == MeasurementControllerStateFinished) {
        if (self.onMeasurementFinished != nil) {
            self.onMeasurementFinished();
        }

        Measurement *measurement = self.measurementController.measurement;
        [measurement processData];
        if (self.onMeasurementProcessed != nil) {
            self.onMeasurementProcessed(measurement);
            [self.measurementController unloadAll];
        }
    }
}

- (void)measurementController:(MeasurementController *)measurementController didReceiveSample:(DataPoint *)datapoint {
    if (self.onSampleReady != nil) {
        self.onSampleReady(datapoint.filterValue, datapoint.y);
    }
}

- (void)measurementController:(MeasurementController *)measurementController progressUpdated:(NSUInteger)elapsedTime {
    if (self.onTimeRemaining != nil) {
        self.onTimeRemaining(elapsedTime);
    }
}

- (void)measurementController:(MeasurementController *)measurementController didReceiveMeasurementError:(NSString*)message {
    if (self.onMeasurementError != nil) {
        self.onMeasurementError(message);
    }
}

- (void)measurementController:(MeasurementController *)measurementController heartRateUpdated:(NSUInteger)heartRate {
    if (self.onHeartBeat != nil) {
        self.onHeartBeat(heartRate);
    }
}

- (void)measurementControllerDidStartRecording {
    if (self.onMeasurementStart != nil) {
        self.onMeasurementStart();
    }
}

- (void)measurementControllerDidReceiveMovement {
    if (self.onMovementDetected != nil) {
        self.onMovementDetected();
    }
}

- (void)measurementController:(MeasurementController *)measurementController didReceiveFingerRemoved:(DataPoint *)datapoint {
    if (self.onFingerRemoved != nil) {
        self.onFingerRemoved(datapoint.y, datapoint.v, datapoint.stdDevY);
    }
}

- (void)measurementControllerDidReceiveFingerDetected {
    if (self.onFingerDetected != nil) {
        self.onFingerDetected();
    }
}

- (void)measurementControllerDidReceivePulseDetected {
    if (self.onPulseDetected != nil) {
        self.onPulseDetected();
    }
}

- (void)measurementControllerDidReceiveCalibrationReady {
    if (self.onCalibrationReady != nil) {
        self.onCalibrationReady();
    }
}

- (void)measurementControllerDidReceivePulseDetectionTimeout {
    if (self.onPulseDetectionTimeExpired != nil) {
        self.onPulseDetectionTimeExpired();
    }
}

- (void)measurementControllerDidReceiveFingerDetectionTimeout {
    if (self.onFingerDetectionTimeExpired != nil) {
        self.onFingerDetectionTimeExpired();
    }
}

@end
