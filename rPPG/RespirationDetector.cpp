//
//  RespirationDetector.cpp
//  rPPG
//
//  Created by Krisztián Vörös on 2021. 05. 04..
//

#include "RespirationDetector.hpp"

using namespace cv;
using namespace std;

const int FRAMES_PER_SECOND = 60;

void RespirationDetector::StartDetection(Mat image) {
    if (this->callCount++ % FRAMES_PER_SECOND != 0)
        return;
    
    vector<float> avaragedRowIntensities;
    
    for(uint32_t i = 0; i < image.rows; i++) {
        uint32_t summedRowIntensity = 0;
        for (uint32_t j = 0; j < image.cols; j++) {
            int summedIntensity = 0;
            Vec3b currentPixelRGB = image.at<Vec3b>(i,j);
            summedIntensity += currentPixelRGB[0];
            summedIntensity += currentPixelRGB[1];
            summedIntensity += currentPixelRGB[2];
            
            summedRowIntensity += summedIntensity;
        }
        
        avaragedRowIntensities.push_back(summedRowIntensity/image.cols);
        
        vector<float> filteredIntensities = butterworthBandpassFilter(avaragedRowIntensities);
        Scalar mean, stddev;
        meanStdDev(filteredIntensities, mean, stddev);
        vector<float> respirationSignal;
        for(uint32_t i = 0; i < filteredIntensities.size(); i++) {
            double intensityMinusMean = filteredIntensities[i] - mean[0];
            respirationSignal.push_back(intensityMinusMean / stddev[0]);
        }
    }
}

vector<float> RespirationDetector::butterworthBandpassFilter(vector<float> avaragedRowIntensities)
{
    vector<float> result;
    const int NZEROS = 8;
    const int NPOLES = 8;
    static float xv[NZEROS+1], yv[NPOLES+1];
    
    double dGain = 1.232232910e+02;
    
    for (auto intensity : avaragedRowIntensities)
    {
        double input = intensity;
        
        xv[0] = xv[1]; xv[1] = xv[2]; xv[2] = xv[3]; xv[3] = xv[4]; xv[4] = xv[5]; xv[5] = xv[6]; xv[6] = xv[7]; xv[7] = xv[8];
        xv[8] = input / dGain;
        yv[0] = yv[1]; yv[1] = yv[2]; yv[2] = yv[3]; yv[3] = yv[4]; yv[4] = yv[5]; yv[5] = yv[6]; yv[6] = yv[7]; yv[7] = yv[8];
        yv[8] =   (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
        + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
        + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
        + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
        + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
        
        result.push_back(yv[8]);
    }
    
    return result;
}
