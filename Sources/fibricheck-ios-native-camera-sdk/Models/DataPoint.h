#import <Foundation/Foundation.h>

@class ImageProcessorConfig;

@interface DataPoint: NSObject

@property (assign) float * quadrants;

/*!
 *  Time of sample
 */
@property int tms;

/*!
 *  Y, U, V and standard deviation of Y
 */
@property float y;
@property float u;
@property float v;
@property float stdDevY;
/*!
 *  Filtervalues
 */
@property float filterValue;

/*!
 *  Accelerometer and Gyroscope functions
 */
@property float accx;
@property float accy;
@property float accz;
@property float gyrx;
@property float gyry;
@property float gyrz;
@property float gravx;
@property float gravy;
@property float gravz;
@property float orix;
@property float oriy;
@property float oriz;

@property BOOL hasAcc;
@property BOOL hasGyr;
@property BOOL hasGrav;
@property BOOL hasOri;

- (id)initWithConfig:(ImageProcessorConfig*)config;

@end
