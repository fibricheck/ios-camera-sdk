#import "DataPoint.h"
#import "ImageProcessorConfig.h"

@interface DataPoint()

@property ImageProcessorConfig * quadrantConfig;

@end

@implementation DataPoint

- (id)initWithConfig:(ImageProcessorConfig*)config {
    self = [super init];
    if (self) {
        _tms = 0;
        _y = 0;
        _u = 0;
        _v = 0;
        _filterValue = 0;
        _accx = _accy = _accz = _gyrx = _gyry = _gyrz = _gravx = _gravy = _gravz = _orix = _oriy = _oriz = 0;

        _quadrantConfig = config;

        int quadrantArraySize = (int)config.rowSize * (int)config.colSize * 3;
        _quadrants = (float *)malloc(sizeof(float) * quadrantArraySize);
        for (int i = 0; i < quadrantArraySize; i++) {
            _quadrants[i] = 0.0;
        }
    }
    return self;
}

- (void)dealloc {

    free(_quadrants);
}

@end
