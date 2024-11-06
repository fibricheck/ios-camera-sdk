
#import "FCFilter.h"

@implementation FCFilter

- (id)initHighPass {
    self = [super init];
    if (self) {
        a = (float*)malloc(4*sizeof(float));
        a[0] = 1.0000f;
        a[1] = -0.900404044297840f;
        a[2] = 0.0000f;
        a[3] = 0.0000f;

        b = (float*)malloc(4*sizeof(float));
        b[0] = 0.950202022148920f;
        b[1] = -0.950202022148920f;
        b[2] = 0.0000f;
        b[3] = 0.0000f;

        x = (float*)malloc(4*sizeof(float));
        y = (float*)malloc(4*sizeof(float));

        output = 0;
        count = 0;
    }
    return self;
}

- (id)initLowPass {
    self = [super init];
    if (self) {
        a = (float*)malloc(4*sizeof(float));
        b = (float*)malloc(4*sizeof(float));

        // Moving Addition
        a[0] = 1.0000f;
        a[1] = 0.0000f;
        a[2] = 0.0000f;
        a[3] = 0.0000f;

        b[0] = 1.0f;
        b[1] = 1.0f;
        b[2] = 1.0f;
        b[3] = 1.0f;

        x = (float*)malloc(4*sizeof(float));
        y = (float*)malloc(4*sizeof(float));

        output = 0;
        count = 0;

    }
    return self;
}

- (float)pushValue:(float) input {
    for (int i = 3; i > 0; i--) {
        x[i] = x[i-1];
    }
    x[0] = input;
    for (int i = 3; i > 0; i--) {
        y[i] = y[i-1];
    }
    output = ( b[0] * x[0] + b[1] * x[1] + b[2] * x[2] + b[3] * x[3] - a[1] * y[1] - a[2] * y[2] - a[3] * y[3] ) / a[0];
    y[0] = output;
    return output;
}

@end
