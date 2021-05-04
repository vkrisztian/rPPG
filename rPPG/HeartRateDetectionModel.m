//
//  HeartRateDetection.m
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 04. 29..
//

#import "HeartRateDetectionModel.h"
#import <AVFoundation/AVFoundation.h>

const int FRAMES_PER_SECOND = 30;
const int SECONDS = 90;

@interface HeartRateDetectionModel() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) NSMutableArray *dataPointsHue;

@end

@implementation HeartRateDetectionModel

- (void)initialize:(AVCaptureSession *)session {
    self.session = session;
    self.dataPointsHue = [[NSMutableArray alloc] init];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    static int count=0;
    count++;
    // only run if we're not already processing an image
    // this is the image buffer
    CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock the image buffer
    CVPixelBufferLockBaseAddress(cvimgRef,0);
    
    // access the data
    NSInteger width = CVPixelBufferGetWidth(cvimgRef);
    NSInteger height = CVPixelBufferGetHeight(cvimgRef);
    
    // get the raw image bytes
    uint8_t *buf=(uint8_t *) CVPixelBufferGetBaseAddress(cvimgRef);
    size_t bprow=CVPixelBufferGetBytesPerRow(cvimgRef);
    float r=0,g=0,b=0;
    
    // Get the average rgb values for the entire image.
    for(int y=0; y < height; y++) {
        for(int x=0; x < width*4; x+=4) {
            b+=buf[x];
            g+=buf[x+1];
            r+=buf[x+2];
            // a+=buf[x+3];
        }
        buf+=bprow;
    }
    r/=255*(float) (width*height);
    g/=255*(float) (width*height);
    b/=255*(float) (width*height);
    
    // The hue value is the most expressive when looking for heart beats.
    // Here we convert our rgb values in hsb and continue with the h value.
    UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    CGFloat hue, sat, bright;
    [color getHue:&hue saturation:&sat brightness:&bright alpha:nil];
    
    [self.dataPointsHue addObject:@(hue)];
    
    // Only send UI updates once a second
    if (self.dataPointsHue.count % FRAMES_PER_SECOND == 0)
    {
        if (self.delegate)
        {
            float displaySeconds = self.dataPointsHue.count / FRAMES_PER_SECOND;
            
            NSArray *bandpassFilteredItems = [self butterworthBandpassFilter:self.dataPointsHue];
            NSArray *smoothedBandpassItems = [self medianSmoothing:bandpassFilteredItems];
            int peakCount = [self peakCount:smoothedBandpassItems];
            
            float secondsPassed = smoothedBandpassItems.count / FRAMES_PER_SECOND;
            float percentage = secondsPassed / 60;
            float heartRate = peakCount / percentage;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate heartRateUpdate:heartRate atTime:displaySeconds];
            });
        }
    }
    
    // stop after the defined seconds
    if (self.dataPointsHue.count == (SECONDS * FRAMES_PER_SECOND))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate stopDetection];
        });
    }
    
    // Unlock the image buffer
    CVPixelBufferUnlockBaseAddress(cvimgRef,0);
}

#pragma mark - Data processing

- (NSArray *)butterworthBandpassFilter:(NSArray *)inputData
{
    const int NZEROS = 8;
    const int NPOLES = 8;
    static float xv[NZEROS+1], yv[NPOLES+1];
    
    // http://www-users.cs.york.ac.uk/~fisher/cgi-bin/mkfscript
    // Butterworth Bandpass filter
    // 4th order
    // sample rate - varies between possible camera frequencies. Either 30, 60, 120, or 240 FPS
    // corner1 freq. = 0.667 Hz (assuming a minimum heart rate of 40 bpm, 40 beats/60 seconds = 0.667 Hz)
    // corner2 freq. = 4.167 Hz (assuming a maximum heart rate of 250 bpm, 250 beats/60 secods = 4.167 Hz)
    // Bandpass filter was chosen because it removes frequency noise outside of our target range (both higher and lower)
    double dGain = 1.232232910e+02;
    
    NSMutableArray *outputData = [[NSMutableArray alloc] init];
    for (NSNumber *number in inputData)
    {
        double input = number.doubleValue;
        
        xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
        xv[8] = input / dGain;
        yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
        yv[8] =   (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
        + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
        + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
        + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
        + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
        
        [outputData addObject:@(yv[8])];
    }
    
    return outputData;
}


// Find the peaks in our data - these are the heart beats.
// At a 30 Hz detection rate, assuming 250 max beats per minute, a peak can't be closer than 7 data points apart.
- (int)peakCount:(NSArray *)inputData
{
    if (inputData.count == 0)
    {
        return 0;
    }
    
    int count = 0;
    
    for (int i = 3; i < inputData.count - 3;)
    {
        if (inputData[i] > 0 &&
            [inputData[i] doubleValue] > [inputData[i-1] doubleValue] &&
            [inputData[i] doubleValue] > [inputData[i-2] doubleValue] &&
            [inputData[i] doubleValue] > [inputData[i-3] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+1] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+2] doubleValue] &&
            [inputData[i] doubleValue] >= [inputData[i+3] doubleValue]
            )
        {
            count = count + 1;
            i = i + 4;
        }
        else
        {
            i = i + 1;
        }
    }
    
    return count;
}

// Smoothed data helps remove outliers that may be caused by interference, finger movement or pressure changes.
// This will only help with small interference changes.
// This also helps keep the data more consistent.
- (NSArray *)medianSmoothing:(NSArray *)inputData
{
    NSMutableArray *newData = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < inputData.count; i++)
    {
        if (i == 0 ||
            i == 1 ||
            i == 2 ||
            i == inputData.count - 1 ||
            i == inputData.count - 2 ||
            i == inputData.count - 3)        {
            [newData addObject:inputData[i]];
        }
        else
        {
            NSArray *items = [@[
                                inputData[i-2],
                                inputData[i-1],
                                inputData[i],
                                inputData[i+1],
                                inputData[i+2],
                                ] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
            
            [newData addObject:items[2]];
        }
    }
    
    return newData;
}

@end










