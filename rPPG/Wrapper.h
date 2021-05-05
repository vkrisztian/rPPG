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

@interface RespirationDetectorWrapper : NSObject

    - (void) detectRespiration: (UIImage *) image;

@end
#endif /* Header_h */
