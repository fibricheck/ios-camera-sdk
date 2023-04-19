#import <Foundation/Foundation.h>

@interface ImageProcessorConfig : NSObject

@property (assign) NSUInteger rowSize;
@property (assign) NSUInteger colSize;
@property (assign) NSUInteger maxYValue;
@property (assign) NSUInteger minYValue;
@property (assign) NSUInteger maxStdDevYValue;
@property (assign) NSUInteger minVValue;

- (instancetype)initWithRowSize:(NSUInteger)rowSize colSize: (NSUInteger) colSize
                           maxY: (NSUInteger) maxY minY: (NSUInteger) minY
                     maxStdDevY: (NSUInteger) maxStdDevY minV: (NSUInteger) minV;

@end
