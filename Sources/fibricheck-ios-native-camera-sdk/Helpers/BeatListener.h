#import <Foundation/Foundation.h>

@interface BeatListener : NSObject

@property (readonly) NSTimeInterval timeSinceLastPulse;

/*!
 *  Implemented by subclasses to initialize a new object (the receiver) immediately after memory for it has been allocated.
 *
 *  @return Returns	An initialized object, or nil if an object could not be created for some reason that would not result in an exception.
 */
-(id)init;

/*!
 *  Add value to be correlated and checked for a peak
 *
 *  @param value float value from filter
 */
-(void)correlateWithValue:(float)value;

/*!
 *  Add value to be correlated and checked for a peak
 *
 *  @param value float value from filter
 *  @param timestamp TimeInterval value from timestamp
 */
-(void)correlateWithValue:(float)value timestamp:(NSTimeInterval)timestamp;


/*!
 *  Get valid pulse state
 *
 *  @return YES if valid pulse, otherwise NO
 */
-(bool)isValidPulse;

/*!
 *  Get pulse detection state
 *
 *  @return YES if pulse detected, otherwise NO
 */
-(bool)isPulseDetected;

/*!
 *  Get peak detection status
 *
 *  @return YES if peak detected, otherwise NO
 */
-(bool)isPeakDetected;

/*!
 *  Get time since last detected valid pulse
 *
 *  @return NSTimeinterval since last pulse
 */
-(NSTimeInterval)timeSinceLastPulse;


/*!
 *  Get current calculated average heartrate
 *
 *  @return Integer of heartrate
 */
-(NSUInteger)heartRate;

/*!
 *  Clears the context
 *
 */
-(void)clear;

@end
