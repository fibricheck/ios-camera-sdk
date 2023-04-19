#import "MotionData.h"

@implementation MotionData

- (instancetype)init {
    self = [super init];
    if (self) {
        self.x = [NSMutableArray new];
        self.y = [NSMutableArray new];
        self.z = [NSMutableArray new];
    }
    return self;
}

-(void)addValueX:(double)x Y:(double)y Z:(double)z {
    [self.x addObject:@(x)];
    [self.y addObject:@(y)];
    [self.z addObject:@(z)];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"MotionData\n -x: %@\n -y: %@\n -z: %@", self.x, self.y, self.z];
}

@end
