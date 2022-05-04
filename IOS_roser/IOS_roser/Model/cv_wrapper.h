//
//  cv_wrapper.h
//  ios_roser
//
//  Created by lyj on 2022/05/03.
//

#ifndef cv_wrapper_h
#define cv_wrapper_h

#include <opencv2/opencv.hpp>
#import<Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface cv_wrapper : NSObject
+(cv::Mat)cvMatFromUIImage:(UIImage *)image;
+(UIImage *) convertImag: (UIImage *)image;
+(cv::Mat)cvMatGrayFromUIImage:(UIImage *)image;
+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat;
@end


#endif /* cv_wrapper_h */
