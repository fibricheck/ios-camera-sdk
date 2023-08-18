#import "Measurement.h"
#import "MotionData.h"
#import "DataPoint.h"
#import "ImageProcessorConfig.h"
#import "YUV.h"

@interface Measurement()

@property (strong) NSMutableArray<DataPoint *> * dataPoints;
@property (strong) ImageProcessorConfig * imageProcessorConfig;
//@property float yuvData[3];

@end

@implementation Measurement

- (instancetype)initWithConfig:(ImageProcessorConfig*)config {
    self = [super init];
    if (self) {
        self.imageProcessorConfig = config;
        self.version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        self.dataPoints = [NSMutableArray<DataPoint *> new];
        self.time = [NSMutableArray new];
        self.ppg = [NSMutableArray new];
        self.technical_details = [[NSMutableDictionary alloc] init];

        self.quadrants = [[NSMutableArray alloc] initWithCapacity:_imageProcessorConfig.rowSize];
        for(int row = 0; row < _imageProcessorConfig.rowSize; row++) {
            NSMutableArray *quadrantCols = [[NSMutableArray alloc] initWithCapacity:_imageProcessorConfig.colSize];
            for (int col = 0; col < _imageProcessorConfig.colSize; col++) {
                [quadrantCols addObject:[YUV new]];
            }
            [self.quadrants addObject:quadrantCols];
        }
    }
    return self;
}

- (void)addDataPoint:(DataPoint*)dataPoint {
    [self.dataPoints addObject:dataPoint];
}

- (void)processData {
    float yuvData[3] = {0.0, 0.0, 0.0};
    for (DataPoint * dataPoint in self.dataPoints) {
        [self.time addObject:@(dataPoint.tms)];
        [self.ppg addObject:@(dataPoint.filterValue)];
        for (int row = 0; row < self.imageProcessorConfig.rowSize; row++) {
            for(int col = 0; col < self.imageProcessorConfig.colSize; col++) {
                int rowCol = ((row * 3) + col) * 3;
                for (int yuvIndex = 0; yuvIndex < 3; yuvIndex++) {
                    yuvData[yuvIndex] = dataPoint.quadrants[rowCol + yuvIndex];
                }
                [self.quadrants[row][col] addValueY:yuvData[0] U:yuvData[1] V:yuvData[2]];
            }
        }

        if (dataPoint.hasAcc) {
            if (self.acc == nil) {
                self.acc = [MotionData new];
            }
            [self.acc addValueX:dataPoint.accx Y:dataPoint.accy Z:dataPoint.accz];
        }
        if (dataPoint.hasGrav) {
            if (self.grav == nil) {
                self.grav = [MotionData new];
            }
            [self.grav addValueX:dataPoint.gravx Y:dataPoint.gravy Z:dataPoint.gravz];
        }
        if (dataPoint.hasGyr) {
            if (self.gyro == nil) {
                self.gyro = [MotionData new];
            }
            [self.gyro addValueX:dataPoint.gyrx Y:dataPoint.gyry Z:dataPoint.gyrz];
        }
        if (dataPoint.hasOri) {
            if (self.rotation == nil) {
                self.rotation = [MotionData new];
            }
            [self.rotation addValueX:dataPoint.orix Y:dataPoint.oriy Z:dataPoint.oriz];
        }
    }
}

- (NSString *) mapToJson {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject: [self mapToDictionary]
                                                       options: 0//NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (!jsonData) {
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}

- (NSDictionary *) mapToDictionary {
    NSNumber * frequency = [[NSNumber alloc] initWithInt:30];
    NSMutableDictionary * meaModel = [[NSMutableDictionary alloc] init];

    if (_acc != nil) {
        meaModel[@"acc"] = @{@"frequency":frequency,
                             @"x":_acc.x,
                             @"y":_acc.y,
                             @"z":_acc.z};
    }

    if (_grav != nil) {
        meaModel[@"grav"] = @{@"frequency":frequency,
                              @"x":_grav.x,
                              @"y":_grav.y,
                              @"z":_grav.z};
    }

    if (_gyro != nil) {
        meaModel[@"gyro"] = @{@"frequency":frequency,
                              @"x":_gyro.x,
                              @"y":_gyro.y,
                              @"z":_gyro.z};
    }

    if (_rotation != nil) {
        meaModel[@"rotation"] = @{@"frequency":frequency,
                                  @"x":_rotation.x,
                                  @"y":_rotation.y,
                                  @"z":_rotation.z};
    }

    NSMutableArray * quadrants = [[NSMutableArray alloc] initWithCapacity:_imageProcessorConfig.rowSize];
    for (int row = 0; row < _imageProcessorConfig.rowSize; row++) {
        NSMutableArray *quadrantCols = [[NSMutableArray alloc] initWithCapacity:_imageProcessorConfig.colSize];
        for (int col = 0; col < _imageProcessorConfig.colSize; col++) {
            [quadrantCols addObject: [_quadrants[row][col] mapToDictionary]];
        }
        [quadrants addObject:quadrantCols];
    }

    meaModel[@"quadrants"] = quadrants;

    meaModel[@"ppg"] = @{@"frequency":frequency, @"signal":_ppg};

    meaModel[@"time"] = _time;

    meaModel[@"heartRate"] = @(_heartRate);

    meaModel[@"attempts"] = @(_attempts);

    meaModel[@"skippedMovementDetection"] = @(_skippedMovementDetection);

    meaModel[@"skippedPulseDetection"] = @(_skippedPulseDetection);

    meaModel[@"skippedFingerDetection"] = @(_skippedFingerDetection);

    meaModel[@"technical_details"] = _technical_details;

    return [meaModel copy];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Measurement\n -version: %@\n -heartrate: %d\n -time: %@\n -ppg: %@\n -acc: %@\n -grav: %@\n -gyro: %@\n -gyro: %@\n -quadrants: %@",
            self.version, (int)self.heartRate, self.time, self.ppg, self.acc, self.grav, self.gyro, self.rotation, self.quadrants];
}

@end
