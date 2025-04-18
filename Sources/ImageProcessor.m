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

- (NSMutableData *)extractFrame:(CMSampleBufferRef)sampleBuffer imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    // The pixel buffer can have padding on either sides
    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferSize = bufferWidth * bufferHeight;
    
    // Our output buffer won't have padding
    size_t imageSize = imageWidth * imageHeight;

    size_t lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

    unsigned char *lumaBuffer = (unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    unsigned char *chromaBuffer = (unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    NSMutableData *outputData = [NSMutableData dataWithLength: imageSize + imageSize / 2];
    unsigned char *outputBuffer = (unsigned char *) outputData.mutableBytes;
    
    // The y values are next to eachother so we can use memcpy to speed things up
    // If there is no padding we can copy the whole chunk in one go
    if (bufferWidth == imageWidth) {
        memcpy(outputBuffer, lumaBuffer, imageSize);
    }
    else {
        // Else we have to do it row by row
        for (int yLuma = 0; yLuma < imageHeight; yLuma++) {
            // Different start calculations due to output being w/o padding, and input being with padding
            unsigned char *outputRowStart = outputBuffer + (yLuma * imageWidth);
            unsigned char *inputRowStart = lumaBuffer + (yLuma * lumaBytesPerRow);
            
            memcpy(outputRowStart, inputRowStart, bufferWidth);
        }
    }
    
    // The UV values are interleaved like so:
    // u_1, v_1, u_2, v_2, ..., u_width, v_width  with potential padding afterwards
    // So we can't use memcpy and have to do it one by one.
    // outputU starts after the Y values, which have size of imageWidth * imageHeight
    unsigned char *outputU = outputBuffer + imageSize;
    // outputV starts after the U values, which have a size of (imageWidth / 2) * (imageHeight / 2) or imageWidth * imageHeight / 4
    unsigned char *outputV = outputBuffer + imageSize + imageSize / 4;
    
    // The chroma planes are only 1/2 the size of the luma plane
    // So there are only imageHeight / 2 rows
    for (int yChroma = 0; yChroma < imageHeight / 2; yChroma++) {
        // However, because U and V are interleaved the width is a full imageWidth size
        for (int xChroma = 0; xChroma < imageWidth; xChroma += 2) {
            
            size_t chromaOutRowStart = (yChroma * (imageWidth / 2));
            size_t chromaInRowStart = (yChroma * chromaBytesPerRow);
            
            outputU[chromaOutRowStart + xChroma / 2] = chromaBuffer[chromaInRowStart + xChroma];
            outputV[chromaOutRowStart + xChroma / 2] = chromaBuffer[chromaInRowStart + xChroma + 1];
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return outputData;
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
