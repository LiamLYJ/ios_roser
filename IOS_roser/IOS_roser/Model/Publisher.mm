//
//  Publisher.m
//  ios_roser
//
//  Created by lyj on 2022/05/03.
//


#include "ros/ros.h"
#include "rosbag/bag.h"
#include "std_msgs/String.h"
#include <sensor_msgs/Imu.h>
#include <sensor_msgs/Image.h>
#include <sensor_msgs/CompressedImage.h>
#include <sensor_msgs/image_encodings.h>
#include <sensor_msgs/NavSatFix.h>
#include "rosbag/view.h"
#include <opencv2/opencv.hpp>

#import "Publisher.h"
#import "cv_wrapper.h"

#import <Foundation/Foundation.h>


@implementation Publisher

std::shared_ptr<rosbag::Bag> bag_ptr;

// GPS process
double pi = 3.1415926535897932384626;
double a = 6378245.0;
double ee = 0.00669342162296594323;

bool outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
}

double transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
    + 0.2 * sqrt(fabs(x));
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
}
double transformLon(double x, double y) {
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1* sqrt(fabs(x));
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return ret;
}

void gps84_To_Gcj02(double& lat, double& lon) {
    if (outOfChina(lat, lon)) {
        return;
    }
    double dLat = transformLat(lon - 105.0, lat - 35.0);
    double dLon = transformLon(lon - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * pi;
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
    lat = lat + dLat;
    lon = lon + dLon;
}

- (void) publishGps:(CLLocation* _Nonnull) data topic:(NSString* _Nonnull) topic timestamp:(double) timestamp gpsCount:(uint32_t) gpsCount{
    sensor_msgs::NavSatFix msg;
    msg.latitude = data.coordinate.latitude;
    msg.longitude = data.coordinate.longitude;
    gps84_To_Gcj02(msg.latitude, msg.longitude);
    msg.altitude = data.altitude;
    msg.position_covariance[0] = data.horizontalAccuracy;
    msg.position_covariance[3] = data.horizontalAccuracy;
    msg.position_covariance[6] = data.verticalAccuracy;
    msg.header.seq = gpsCount;
    msg.header.stamp = ros::Time(timestamp);
    msg.header.frame_id="map";
    
    if(bag_ptr->isOpen()){
        NSDate * t1 = [NSDate date];
        NSTimeInterval now = [t1 timeIntervalSince1970];
        bag_ptr->write((char *)[topic UTF8String], ros::Time(now), msg);
    }
}

- (void) publishImu:(Imu_T) data topic:(NSString* _Nonnull) topic {
    sensor_msgs::Imu msg;
    msg.linear_acceleration.x = data.acc_x;
    msg.linear_acceleration.y = data.acc_y;
    msg.linear_acceleration.z = data.acc_z;
    msg.angular_velocity.x = data.gyro_x;
    msg.angular_velocity.y = data.gyro_y;
    msg.angular_velocity.z = data.gyro_z;
    msg.header.seq = data.header_seq;
    msg.header.frame_id = "map";
    msg.header.stamp = ros::Time(data.timestamp);
    if (bag_ptr->isOpen()) {
        NSDate * t1 = [NSDate date];
        NSTimeInterval now = [t1 timeIntervalSince1970];
        bag_ptr->write((char *)[topic UTF8String], ros::Time(now), msg);
    }
}
 
- (void) publishImg:(UIImage* _Nonnull) img timestamp:(double) timestamp topic:(NSString* _Nonnull) topic imgCount:(uint32_t) imgCount {
    
    cv::Mat img_cv = [cv_wrapper cvMatFromUIImage:img];
    sensor_msgs::CompressedImage img_ros_img;
    //cv::Mat img_gray;
    //cv::cvtColor(img_cv, img_gray, CV_BGRA2GRAY);
    std::vector<unsigned char> binaryBuffer_;
    cv::imencode(".jpg", img_cv, binaryBuffer_);
    img_ros_img.data = binaryBuffer_;
    img_ros_img.header.seq = imgCount;
    img_ros_img.header.stamp = ros::Time(timestamp);
    img_ros_img.format="jpeg";
    if(bag_ptr->isOpen()) {
        NSDate * t1 = [NSDate date];
        NSTimeInterval now = [t1 timeIntervalSince1970];
        const char *cString = [topic UTF8String];
        bag_ptr->write(cString, ros::Time(now), img_ros_img);
    }
}

- (NSString* _Nonnull) getInfo:(NSString* _Nonnull) filename {
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dirPaths objectAtIndex:0] error:NULL];
    
    std::map<std::string, int> re_dict;
    double start_time = 0;
    double end_time = 0;
    for (int count = 0; count < (int)[directoryContent count]; count++)
    {
        NSString *full_addr = [[dirPaths objectAtIndex:0] stringByAppendingPathComponent:[directoryContent objectAtIndex:count]];
        if([filename isEqualToString:[directoryContent objectAtIndex:count]]==YES){
            rosbag::Bag bag;
            try{
                bag.open(std::string([full_addr UTF8String]).c_str(), rosbag::bagmode::Read);
            }
            catch (...){
                return @"bad bag, unknown!";
            }
            if(!bag.isOpen()){
                return @"bad bag not open!";
            }
            rosbag::View view(bag);
            start_time = view.getBeginTime().toSec();
            end_time = view.getEndTime().toSec();
            rosbag::View::iterator it= view.begin();
            for(;it!=view.end();it++){
                rosbag::MessageInstance m =*it;
                if (re_dict.count(m.getTopic())==0){
                    re_dict[m.getTopic()]=1;
                }else{
                    re_dict[m.getTopic()]=re_dict[m.getTopic()]+1;
                }
            }
            bag.close();
            break;
        }
    }
    std::stringstream ss;
    for(std::map<std::string, int>::iterator it=re_dict.begin(); it!=re_dict.end(); it++){
        ss<<it->first<<": "<<it->second<<std::endl;
    }
    ss<<"duration: "<<end_time-start_time<<"s";
    NSString *string1 = [NSString stringWithCString:ss.str().c_str() encoding:[NSString defaultCStringEncoding]];
    return string1;

}
    
- (void) open: (NSString* _Nonnull) filename {
    bag_ptr.reset(new rosbag::Bag());
    const char *cString = [filename UTF8String];
    bag_ptr->open(cString, rosbag::bagmode::Write);
}

- (void) close {
    bag_ptr->close();
}

@end
