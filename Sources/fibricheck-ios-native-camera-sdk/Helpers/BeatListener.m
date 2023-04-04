#import "BeatListener.h"

@interface BeatListener()

@property NSArray * patternValues;
@property NSMutableArray * signalValues;
@property float denominator;
@property float lastCorrelation;
@property NSTimeInterval lastTime;
@property NSMutableArray * timeValues;
@property NSMutableArray * heartRateValues;
@property NSMutableArray * correlationValues;
@property NSTimeInterval timeSinceLastPulseInt;
@property BOOL pulseDetected;
@property NSUInteger pulseCount;

@end

@implementation BeatListener

- (id)init {
    self = [super init];
    [self clear];
    return self;
}

- (void)clear {
    self.patternValues = [[NSArray alloc] initWithObjects:
                          @-0.260377750000000,
                          @-0.264072118421053,
                          @-0.690280657894737,
                          @0.320902447368421,
                          @0.636459210526316,
                          @0.775235157894737,
                          @0.616998750000000,
                          @0.258818513157895,
                          @-0.0155936315789474,
                          @-0.107737578947368,
                          @-0.0730700131578947,
                          @-0.00178090789473684,
                          @0.0353458026315790,
                          @0.0177359342105263,
                          @-0.0479446842105263,
                          @-0.145095802631579,
                          @-0.218533671052632,
                          @-0.243734131578947,
                          @-0.243979118421053,
                          @-0.229033460526316,
                          @-0.206577592105263, nil];

    self.signalValues = [[NSMutableArray alloc] initWithObjects:@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0, nil];

    self.denominator = 0;
    for (int i = 0; i < self.patternValues.count; i++) {
        self.denominator += powf([self.patternValues[i] floatValue],2);
    }

    self.lastCorrelation = 0;
    self.lastTime = 0;
    self.pulseCount = 0;
    self.pulseDetected = false;
    self.timeValues = [[NSMutableArray alloc] initWithObjects:@0, @0, @0, nil];
    self.heartRateValues = [NSMutableArray new];
    self.correlationValues = [[NSMutableArray alloc] initWithObjects:@0, @0, @0, nil];
}

- (void)correlateWithValue:(float)value timestamp:(NSTimeInterval)timestamp {
    //Update Signal
    for (int i = 0 ; i < self.signalValues.count-1 ; i++) {
        self.signalValues[i] = self.signalValues[i+1];
    }
    self.signalValues[20] = [NSNumber numberWithFloat:value];

    float nominator = 0;
    for (int i = 0; i < self.patternValues.count; i++) {
        nominator += [self.patternValues[i] floatValue] * [self.signalValues[i] floatValue];
    }

    float denominator2 = 0;
    for (int i = 0; i < self.signalValues.count; i++) {
        denominator2 += powf([self.signalValues[i] floatValue],2);
    }

    self.lastCorrelation = nominator/sqrt(self.denominator * denominator2);
    [self.correlationValues addObject:[NSNumber numberWithFloat:self.lastCorrelation]];
    [self.correlationValues removeObjectAtIndex:0];

    if ([self isPeakDetected]) {
        if (timestamp > 0) {
            self.lastTime = timestamp;
        } else {
            self.lastTime = [[NSDate date] timeIntervalSince1970]*1000;
        }

        [self.timeValues addObject:[NSNumber numberWithDouble:self.timeSinceLastPulse]];
        [self.timeValues removeObjectAtIndex:0];

        if ([self isValidPulse]) {
            [self countPulse];
            [self.heartRateValues addObject:[NSNumber numberWithInt:60000/ [[self.timeValues valueForKeyPath:@"@avg.doubleValue"] doubleValue]]];
        }
    }

    if (timestamp > 0) {
        self.timeSinceLastPulseInt = timestamp - self.lastTime;
    } else {
        self.timeSinceLastPulseInt = [[NSDate date] timeIntervalSince1970]*1000 - self.lastTime;
    }
}

- (void)correlateWithValue:(float)value {
    [self correlateWithValue:value timestamp:0];
}

- (bool)isPeakDetected {
    float cor1 = [self.correlationValues[0] floatValue];
    float cor2 = [self.correlationValues[1] floatValue];
    float cor3 = [self.correlationValues[2] floatValue];

    if(cor1 < cor2 && cor2 > cor3 && cor2 > 0.6) {
        return YES;
    }
    return NO;
}

- (bool)isPulseDetected {
    return _pulseDetected;
}

- (void)countPulse {
    if (!_pulseDetected) {
        _pulseCount++;
    }
    if (_pulseCount >= 3) {
        _pulseCount = 0;
        _pulseDetected = true;
    }
}

- (bool)isValidPulse {
    double timeMax = [[self.timeValues valueForKeyPath:@"@max.doubleValue"] doubleValue];
    double timeMin = [[self.timeValues valueForKeyPath:@"@min.doubleValue"] doubleValue];
    double timeAvg = [[self.timeValues valueForKeyPath:@"@avg.doubleValue"] doubleValue];

    if (timeMax < 2000 &&
        timeMin > 400 &&
        timeMax < timeAvg * 1.20 &&
        timeMin > timeAvg * 0.80) {
        return YES;
    }
    return NO;
}

- (NSTimeInterval)timeSinceLastPulse {
    return _timeSinceLastPulseInt;
}

- (NSUInteger)heartRate {
    return [[self.heartRateValues valueForKeyPath:@"@avg.intValue"] intValue];
}

@end
