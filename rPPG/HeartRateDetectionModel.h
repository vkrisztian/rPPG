//
//  HeartRateDetection.h
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 04. 29..
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol HeartRateDetectionModelDelegate

- (void)heartRateUpdate:(int)bpm atTime:(int)seconds;
- (void)stopDetection;

@end

@interface HeartRateDetectionModel : NSObject

@property (nonatomic, weak) id<HeartRateDetectionModelDelegate> delegate;

- (void)initialize:(AVCaptureSession *)session;
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end
