#import <Foundation/Foundation.h>

@interface ImageProcesserConfig : NSObject

@property (assign) NSUInteger rowSize;
@property (assign) NSUInteger colSize;
@property (assign) NSUInteger yMax 125;
@property (assign) NSUInteger yMin 30;
@property (assign) NSUInteger stdYMax 35;
@property (assign) NSUInteger vMin 150;

- (instancetype)initWithRowSize:(NSUInteger)rowSize colSize: (NSUInteger) colSize;

@end
