#import <Foundation/Foundation.h>

@class MotionData;
@class ImageProcessorConfig;
@class DataPoint;

@interface Measurement : NSObject

@property NSMutableArray * quadrants;
@property MotionData * acc;
@property MotionData * gyro;
@property MotionData * grav;
@property MotionData * rotation;
@property NSMutableArray * time;
@property NSString * version;
@property NSUInteger heartRate;
@property NSUInteger attempts;
@property NSMutableArray * ppg;
@property NSTimeInterval startTime;
@property BOOL skippedMovementDetection;
@property BOOL skippedPulseDetection;
@property BOOL skippedFingerDetection;
@property NSMutableDictionary * technical_details;

- (instancetype)initWithConfig:(ImageProcessorConfig*)config;

- (void)addDataPoint:(DataPoint*)dp;
- (void)processData;
- (NSDictionary*)mapToDictionary;
- (NSString *)mapToJson;

@end
