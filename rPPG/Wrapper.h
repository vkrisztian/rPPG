//
//  Header.h
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 04. 29..
//

#ifndef Header_h
#define Header_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HeartRateDetectionModel.h"

@interface HeartRateDetector : NSObject

@property (nonatomic) HeartRateDetectionModel * heartRateDetectionModel;

// - (UIImage *) detectFaces: (UIImage *) image;

@end
#endif /* Header_h */
