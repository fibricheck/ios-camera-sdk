#import <Foundation/Foundation.h>
#import "YUV.h"
#import "DataPoint.h"

@implementation YUV

- (id)init {
    self = [super init];

    _y = [NSMutableArray array];
    _u = [NSMutableArray array];
    _v = [NSMutableArray array];

    return self;
}

- (void)addValueY:(double)y U:(double)u V:(double)v {
    [_y addObject:@(y)];
    [_u addObject:@(u)];
    [_v addObject:@(v)];
}

- (NSDictionary *) mapToDictionary {
    NSMutableDictionary * yuvModel = [[NSMutableDictionary alloc] initWithCapacity:3];

    yuvModel[@"y"] = _y;
    yuvModel[@"u"] = _u;
    yuvModel[@"v"] = _v;

    return yuvModel;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"YUV(y: %d, u: %d, x: %d)", (int)self.y.count, (int)self.u.count, (int)self.v.count];
}

@end
