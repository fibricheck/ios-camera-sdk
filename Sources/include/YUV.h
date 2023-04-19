#import <Foundation/Foundation.h>
#import "DataPoint.h"

@interface YUV : NSObject

@property NSMutableArray * y;
@property NSMutableArray * u;
@property NSMutableArray * v;

-(void)addValueY:(double)y U:(double)u V:(double)v;
-(NSDictionary *)mapToDictionary;

@end
