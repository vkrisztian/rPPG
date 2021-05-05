//
//  RespirationDetector.hpp
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 05. 04..
//

#ifndef RespirationDetector_hpp
#define RespirationDetector_hpp

#include <stdio.h>
#include <opencv2/opencv.hpp>

class RespirationDetector {
public:
    void StartDetection(cv::Mat image);
private:
    int callCount = 0;
    std::vector<float> butterworthBandpassFilter(std::vector<float> avaragedRowIntensities);
};

#endif /* RespirationDetector_hpp */
