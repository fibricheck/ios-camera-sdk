#import "ImageProcessorConfig.h"

@implementation ImageProcessorConfig

- (instancetype)initWithRowSize:(NSUInteger)rowSize colSize: (NSUInteger) colSize
                           maxY: (NSUInteger) maxY minY: (NSUInteger) minY
                     maxStdDevY: (NSUInteger) maxStdDevY minV: (NSUInteger) minV {
    self = [self init];
    if (self) {
        _rowSize = rowSize;
        _colSize = colSize;
        _maxYValue = maxY;
        _minYValue = minY;
        _maxStdDevYValue = maxStdDevY;
        _minVValue = minV;
    }
    return self;
}

@end
