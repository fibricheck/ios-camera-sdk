#import "FCSGFilter.h"

@implementation FCSGFilter

- (instancetype)init {
    self = [super init];
    if (self) {
        self.shiftRegister = [NSMutableArray arrayWithArray:@[@0,@0,@0,@0,@0,@0,@0]];
    }
    return self;
}

- (float)calculateValue:(float)input {
    [self.shiftRegister removeLastObject];

    NSMutableArray * tMutableArray = [[[[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:input], nil] arrayByAddingObjectsFromArray:self.shiftRegister] mutableCopy];

    self.shiftRegister = tMutableArray;

    float tempResult = (((-2) * [self.shiftRegister[0] floatValue])
                        + (3 * [self.shiftRegister[1] floatValue])
                        + (6 * [self.shiftRegister[2] floatValue])
                        + (7 * [self.shiftRegister[3] floatValue])
                        + (6 * [self.shiftRegister[4] floatValue])
                        + (3 * [self.shiftRegister[5] floatValue])
                        - (2 * [self.shiftRegister[6] floatValue]));
    return tempResult;
}

@end
