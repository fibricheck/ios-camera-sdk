#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class ImageProcessorConfig;
@class DataPoint;

@interface ImageProcessor : NSObject

/*!
 *  Extracts the raw data from a video frame into one big array
 *
 *  @param sampleBuffer sampleBuffer from camera delegate function
 *
 *  @return A byte array containing the y, u, v frames concatenated.
 */
- (NSMutableData* _Nonnull)extractFrame:(CMSampleBufferRef)sampleBuffer imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight;

/*!
 *  Processes the CMSampleBufferRef from the Camera didoutputsample
 *
 *  @param sampleBuffer sampleBuffer from camera delegate function
 *
 *  @return Datapoint with extracted values
 */
- (DataPoint*)processImageBuffer:(CMSampleBufferRef)sampleBuffer;

/*!
 *  Calculate if the finger is on the camera with current datapoint
 *
 *  @param dp current datapoint
 *
 *  @return YES if finger on camera, otherwise NO
 */
- (bool)fingerOnCamera:(DataPoint*)dp;

/*!
 *  Initiliase wirh Config
 *
 *  @param config QuadrantConfig
 */
- (instancetype)initWithConfig:(ImageProcessorConfig*)config;

@end
