#import <Foundation/Foundation.h>

@interface ImageProcesserConfig : NSObject

@property (assign) NSUInteger rowSize;
@property (assign) NSUInteger colSize;
//@property (assign) NSUInteger yMax 125;
//@property (assign) NSUInteger yMin 30;
//@property (assign) NSUInteger stdYMax 35;
//@property (assign) NSUInteger vMin 150;
@property (assign) NSUInteger yMax;
@property (assign) NSUInteger yMin;
@property (assign) NSUInteger stdYMax;
@property (assign) NSUInteger vMin;

- (instancetype)initWithRowSize:(NSUInteger)rowSize colSize: (NSUInteger) colSize;

@end
