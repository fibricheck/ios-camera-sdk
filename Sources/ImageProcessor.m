#import "ImageProcessor.h"
#import "FCSGFilter.h"
#import "FCFilter.h"
#import "DataPoint.h"
#import "ImageProcessorConfig.h"
#import "YUV.h"

/*
#define Y_MAX 125
#define Y_MIN 30
#define STD_Y_MAX 35
#define V_MIN 150
*/

@interface ImageProcessor()

@property float previousValue;
@property FCFilter * filter;
@property FCSGFilter * fcsgFilter;

@property NSUInteger maxYValue;
@property NSUInteger minYValue;
@property NSUInteger maxStdDevYValue;
@property NSUInteger minVValue;

@property short rowSize;
@property short colSize;
@property short quadrantSize;

@property (strong) ImageProcessorConfig * imageProcessorConfig;

@end

@implementation ImageProcessor

- (instancetype)initWithConfig:(ImageProcessorConfig*)config {
    self = [super init];
    if (self) {
        self.imageProcessorConfig = config;
        self.previousValue = 0;
        self.filter = [[FCFilter alloc] initLowPass];
        self.fcsgFilter = [FCSGFilter new];
        self.rowSize = self.imageProcessorConfig.rowSize;
        self.colSize = self.imageProcessorConfig.colSize;
        self.quadrantSize = self.imageProcessorConfig.rowSize * self.imageProcessorConfig.colSize;
        self.maxYValue = self.imageProcessorConfig.maxYValue;
        self.minYValue = self.imageProcessorConfig.minYValue;
        self.maxStdDevYValue = self.imageProcessorConfig.maxStdDevYValue;
        self.minVValue = self.imageProcessorConfig.minVValue;
    }
    return self;
}

- (DataPoint*)processImageBuffer:(CMSampleBufferRef)sampleBuffer {
    float y_sum = 0;
    float v_sum = 0;
    float y_std_dev = 0;
    short colSize = self.colSize;
    short quadrantSize = self.quadrantSize;

    int histY[256];

    for (int i = 0; i < 256; i++) {
        histY[i] = 0;
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferSize = bufferWidth * bufferHeight;

    size_t lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

    unsigned char * lumaBuffer = (unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    unsigned char * chromaBuffer = (unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

    size_t quadrantWidth = bufferWidth / colSize;
    size_t quadrantHeight = bufferHeight / self.rowSize;

    DataPoint * dp = [[DataPoint alloc] initWithConfig:self.imageProcessorConfig];

    for (int y = 0; y < bufferHeight; y += 1) {
        short row = y / quadrantHeight;
        for (int x = 0; x < bufferWidth; x += 1) {
            size_t lumaIndex = y * lumaBytesPerRow + x;
            size_t chromaIndex = (y / 2) * chromaBytesPerRow+(x / 2) * 2;

            float yValue = lumaBuffer[lumaIndex];
            float uValue = chromaBuffer[chromaIndex];
            float vValue = chromaBuffer[chromaIndex+1];

            y_sum += yValue;
            v_sum += vValue;

            // make one long float array. 3 consecutively values represent the Y/U/V sum per quadrant.
            // example: 4x4 quadrant --> 16 quadrants with Y/U/V values --> 16 * 3 = 48
            // so then the array will by 48 values long
            int quadrantIndex = (row * colSize * 3) + ((x / quadrantWidth) * 3);
            dp.quadrants[quadrantIndex] += yValue;
            dp.quadrants[quadrantIndex + 1] += uValue;
            dp.quadrants[quadrantIndex + 2] += vValue;

            histY[lumaBuffer[lumaIndex]]++;
        }
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    // average the quadrants
    long quadrantBufferSize = bufferSize / quadrantSize;
    for (int i = 0; i < quadrantSize * 3; i++) {
        dp.quadrants[i] /= quadrantBufferSize;
    }

    float y_avg = (float)y_sum/bufferSize;
    float v_avg = (float)v_sum/bufferSize;

    unsigned long sigmaY = 0;
    for (int i = 0; i < 256; i++) {
        sigmaY += histY[i] * pow(i - y_avg, 2);
    }
    y_std_dev = sqrt(sigmaY/bufferSize);

    float ppg;
    if (self.previousValue == 0) {
        self.previousValue = y_avg;
        ppg = 0;
    } else {
        // Calculate derivative
        ppg = self.previousValue - y_avg;
        self.previousValue = y_avg;
    }

    // Filter derivative
    ppg = [self.fcsgFilter calculateValue:[self.filter pushValue:ppg]];

    dp.y = y_avg;
    dp.v = v_avg;
    dp.stdDevY = y_std_dev;
    dp.filterValue = ppg;

    return dp;
}

- (bool)fingerOnCamera:(DataPoint*)dp {
    if (_minYValue == 0) {
        return YES;
    }
    if (dp.y > _minYValue && dp.y < _maxYValue &&
        dp.stdDevY < _maxStdDevYValue && dp.v > _minVValue ) {
        return YES;
    }
    return NO;
}

@end
