//
//  Wrapper.m
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 04. 29..
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <Foundation/Foundation.h>
#import "Wrapper.h"
#include "HeartRateDetectionModel.h"
#include "RespirationDetector.hpp"

@implementation RespirationDetectorWrapper

- (void) detectRespiration: (UIImage *) image {
    cv::Mat opencvImage;
    UIImageToMat(image, opencvImage, true);
    
    cv::Mat convertedColorSpaceImage;
    cv::cvtColor(opencvImage, convertedColorSpaceImage, CV_RGBA2RGB);
    
    RespirationDetector respirationDetector;
    respirationDetector.StartDetection(convertedColorSpaceImage);
}

@end
