#import "LabelInfo.h"

// UDI constants
static NSString * const UDI_PREFIX = @"(01)05419980589323(8012)";
static NSString * const UDI_PRODUCT = @"CAMIOS";

// Regulatory constants
static NSString * const CE_LABEL = @"CE 1639";
static NSString * const MANUFACTURER = @"Qompium NV - Kempische Steenweg 303/27 - 3500 Hasselt - Belgium";
static NSString * const IFU_URL = @"https://pages.fibricheck.com/document-versions/";

// Cached SDK release info
static NSDictionary *sdkRelease = nil;

@implementation LabelInfo

+ (NSDictionary<NSString *, NSString *> *)getLabel {
    // Load sdk-release.json once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSURL *url = [bundle URLForResource:@"sdk-release" withExtension:@"json"];

        // For SPM, resources are in a sub-bundle
        if (!url) {
            NSString *bundlePath = [[bundle resourcePath] stringByAppendingPathComponent:@"FibriCheckCameraSDK_FibriCheckCameraSDK.bundle"];
            NSBundle *resourceBundle = [NSBundle bundleWithPath:bundlePath];
            url = [resourceBundle URLForResource:@"sdk-release" withExtension:@"json"];
        }

        NSData *data = [NSData dataWithContentsOfURL:url];
        sdkRelease = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    });

    NSString *version = sdkRelease[@"version"];
    NSString *releaseDate = sdkRelease[@"releaseDate"];

    return @{
        @"componentName": [NSString stringWithFormat:@"FibriCheck Camera SDK iOS %@", version],
        @"udi": [self buildUDI:version],
        @"ceLabel": CE_LABEL,
        @"manufacturer": MANUFACTURER,
        @"releaseDate": [releaseDate substringToIndex:7],
        @"ifu": IFU_URL
    };
}

+ (NSString *)buildUDI:(NSString *)version {
    NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
    NSMutableString *versionCode = [NSMutableString string];

    for (NSString *part in parts) {
        [versionCode appendFormat:@"%02d", [part intValue]];
    }

    return [NSString stringWithFormat:@"%@%@%@", UDI_PREFIX, UDI_PRODUCT, versionCode];
}

@end
