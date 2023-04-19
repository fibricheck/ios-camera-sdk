#import <Foundation/Foundation.h>

@interface Filter : NSObject{
    float output;
    double count;
    float * a;
    float * b;
    float * x;
    float * y;
}

- (float)pushValue:(float)input;

/*!
 *  Implemented by subclasses to initialize a new object (the receiver) immediately after memory for it has been allocated.
 *
 *  Init with highpass arguments
 *
 *  @return Returns	An initialized object, or nil if an object could not be created for some reason that would not result in an exception.
 */
- (id)initHighPass;

/*!
 *  Implemented by subclasses to initialize a new object (the receiver) immediately after memory for it has been allocated.
 *
 *  Init with lowpass arguments
 *
 *  @return Returns	An initialized object, or nil if an object could not be created for some reason that would not result in an exception.
 */
- (id)initLowPass;

@end
