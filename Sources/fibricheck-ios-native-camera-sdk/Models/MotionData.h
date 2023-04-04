#import <Foundation/Foundation.h>

@interface MotionData : NSObject

@property (strong) NSMutableArray * x;
@property (strong) NSMutableArray * y;
@property (strong) NSMutableArray * z;

-(void)addValueX:(double)x Y:(double)y Z:(double)z;

@end
