#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LabelInfo : NSObject

/**
 * Returns the SDK label information for regulatory compliance.
 * @return Dictionary containing componentName, udi, ceLabel, manufacturer, releaseDate, and ifu.
 */
+ (NSDictionary<NSString *, NSString *> *)getLabel;

@end

NS_ASSUME_NONNULL_END
