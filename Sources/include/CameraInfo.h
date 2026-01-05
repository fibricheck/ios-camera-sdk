//
//  CameraInfo.h
//  FibriCheckCameraSDK
//
//  Created by Brent Berghmans on 11/12/2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVCaptureDevice;

@interface CameraInfo : NSObject

@property (nonatomic, readonly) NSInteger isoMin;
@property (nonatomic, readonly) NSInteger isoMax;
@property (nonatomic, readonly) int64_t exposureTimeMin;
@property (nonatomic, readonly) int64_t exposureTimeMax;
@property (nonatomic, readonly) BOOL isManualFocusSupported;

- (instancetype)init:(NSInteger)isoMin
    isoMax:(NSInteger)isoMax
    exposureTimeMin:(int64_t)exposureTimeMin
    exposureTimeMax:(int64_t)exposureTimeMax
    isManualFocusSupported:(BOOL)isManualFocusSupported;

+ (instancetype)fromDevice:(AVCaptureDevice *)device;

@end

NS_ASSUME_NONNULL_END
