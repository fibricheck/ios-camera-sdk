//
//  CameraInfo.m
//  FibriCheckCameraSDK
//
//  Created by Brent Berghmans on 11/12/2025.
//

#import "CameraInfo.h"
#import <AVFoundation/AVCaptureDevice.h>

@implementation CameraInfo

- (instancetype)init:(NSInteger)isoMin
    isoMax:(NSInteger)isoMax
    exposureTimeMin:(int64_t)exposureTimeMin
    exposureTimeMax:(int64_t)exposureTimeMax {
    if (self = [super init]) {
        _isoMin = isoMin;
        _isoMax = isoMax;
        _exposureTimeMin = exposureTimeMin;
        _exposureTimeMax = exposureTimeMax;
    }
    return self;
}

+ (instancetype)fromDevice:(AVCaptureDevice *)device {
    NSInteger isoMin = (NSInteger)device.activeFormat.minISO;
    NSInteger isoMax = (NSInteger)device.activeFormat.maxISO;
    
    CMTime minExposure = device.activeFormat.minExposureDuration;
    CMTime maxExposure = device.activeFormat.maxExposureDuration;
    int64_t exposureTimeMin = minExposure.value * 1000000000LL / minExposure.timescale;
    int64_t exposureTimeMax = maxExposure.value * 1000000000LL / maxExposure.timescale;
    
    return [[CameraInfo alloc] init:isoMin
        isoMax:isoMax
        exposureTimeMin:exposureTimeMin
        exposureTimeMax:exposureTimeMax
    ];
}

@end
