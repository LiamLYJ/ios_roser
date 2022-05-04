//
//  Publisher.h
//  ios_roser
//
//  Created by lyj on 2022/05/03.
//

#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface Publisher : NSObject

typedef struct {
    double acc_x;
    double acc_y;
    double acc_z;
    double gyro_x;
    double gyro_y;
    double gyro_z;
    uint32_t header_seq;
    double timestamp;
} Imu_T;

- (void) publishGps:(CLLocation* _Nonnull) data topic:(NSString* _Nonnull) topic timestamp:(double) timestamp gpsCount:(uint32_t) gpsCount;
- (void) publishImu:(Imu_T) data topic:(NSString* _Nonnull) topic;
- (void) publishImg:(UIImage* _Nonnull) img timestamp:(double) timestamp topic:(NSString* _Nonnull) topic imgCount:(uint32_t) imgCount;
- (NSString* _Nonnull) getInfo:(NSString* _Nonnull) filename;
- (void) open: (NSString* _Nonnull) filename;
- (void) close;

@end
