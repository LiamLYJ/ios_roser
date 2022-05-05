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
#import  <opencv2/imgcodecs/ios.h>

#import "Publisher.h"

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
    
    cv::Mat img_cv;
    UIImageToMat(img, img_cv);
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
    std::map<std::string, int> re_dict;
    double start_time = 0;
    double end_time = 0;
    
    rosbag::Bag bag;
    try{
        bag.open(std::string([filename UTF8String]).c_str(), rosbag::bagmode::Read);
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
            
    std::stringstream ss;
    for(std::map<std::string, int>::iterator it=re_dict.begin(); it!=re_dict.end(); it++){
        ss<<it->first<<": "<<it->second<<std::endl;
    }
    ss<<"duration: "<<end_time-start_time<<"s";
    NSString *string1 = [NSString stringWithCString:ss.str().c_str() encoding:[NSString defaultCStringEncoding]];
    return string1;
}

- (void) getFrameInfo: (double* _Nonnull) imgRate imgCount:(uint32_t* _Nonnull) imgCount imuTopic:(NSString** _Nonnull) imuTopic imgTopic:(NSString** _Nonnull) imgTopic gpsTopic:(NSString** _Nonnull) gpsTopic {
    
    assert(bag_ptr->isOpen());
    rosbag::View view(*bag_ptr);
    rosbag::View::iterator it= view.begin();
    for(;it!=view.end();it++){
        if([*imgTopic isEqual:@""]){
            rosbag::MessageInstance m =*it;
            if(m.getDataType()=="sensor_msgs/CompressedImage"){
                std::string str = m.getTopic();
                *imgTopic = [NSString stringWithCString:str.c_str() encoding:[NSString defaultCStringEncoding]];
            }
        }
        if([*imuTopic isEqual:@""]){
            rosbag::MessageInstance m =*it;
            if(m.getDataType()=="sensor_msgs/Imu"){
                std::string str = m.getTopic();
                *imuTopic = [NSString stringWithCString:str.c_str() encoding:[NSString defaultCStringEncoding]];
            }
        }
        if([*gpsTopic isEqual:@""]){
            rosbag::MessageInstance m =*it;
            if(m.getDataType()=="sensor_msgs/NavSatFix"){
                std::string str = m.getTopic();
                *gpsTopic = [NSString stringWithCString:str.c_str() encoding:[NSString defaultCStringEncoding]];
            }
            sensor_msgs::NavSatFixPtr s = m.instantiate<sensor_msgs::NavSatFix>();
        }
        if([*gpsTopic isEqual:@""] && [*imuTopic isEqual:@""] && [*imgTopic isEqual:@""]){
            return;
        }
    }

    std::vector<std::string> topics;
    std::string str = std::string([*imgTopic UTF8String]);
    topics.push_back(str);
    rosbag::View view_img(*bag_ptr, rosbag::TopicQuery(topics));
    uint32_t count=0;
    rosbag::View::iterator it_img= view_img.begin();
    for(;it_img!=view_img.end();it_img++){
        count++;
    }
    *imgRate = (view_img.getEndTime().toSec()-view_img.getBeginTime().toSec())/(count-1);
    *imgCount = count;
}
    
-(UIImage*) getFrame:(uint32_t) frame_id topic:(NSString* _Nonnull) topic timestamp:(double* ) timestamp {
    UIImage *ui_image;
    std::vector<std::string> topics;
    std::string str = std::string([topic UTF8String]);
    topics.push_back(str);
    rosbag::View view(*bag_ptr, rosbag::TopicQuery(topics));
    int img_count=0;
    rosbag::View::iterator it= view.begin();
    for(;it!=view.end();it++){
        if(img_count==frame_id){
            rosbag::MessageInstance m = *it;
            sensor_msgs::CompressedImagePtr simg = m.instantiate<sensor_msgs::CompressedImage>();
            cv::Mat_<uchar> in(1, simg->data.size(), const_cast<uchar*>(&simg->data[0]));
            cv::Mat mat = cv::imdecode(in, cv::IMREAD_GRAYSCALE);
            ui_image = MatToUIImage(mat);
            *timestamp=simg->header.stamp.toSec();
            break;
        }
        img_count++;
    }
    return ui_image;
}

-(void) getGps:(NSMutableArray*_Nonnull*) gpsData timestamps:(NSMutableArray*_Nonnull*) timestamps topic:(NSString* _Nonnull) topic {
    std::vector<std::string> topics;
    std::string str = std::string([topic UTF8String]);
    topics.push_back(str);
    rosbag::View view(*bag_ptr, rosbag::TopicQuery(topics));
    rosbag::View::iterator it= view.begin();
    for(;it!=view.end();it++){
        rosbag::MessageInstance m = *it;
        sensor_msgs::NavSatFixPtr sgps = m.instantiate<sensor_msgs::NavSatFix>();
        double cur=sgps->header.stamp.toSec();
        CLLocation *locat= [[CLLocation alloc] initWithLatitude:sgps->latitude longitude:sgps->longitude];
        [*timestamps addObject:@(cur)];
        [*gpsData addObject:locat];
    }
}

- (void) open: (NSString* _Nonnull) filename isWrite:(bool) isWrite {
    bag_ptr.reset(new rosbag::Bag());
    const char *cString = [filename UTF8String];
    if (isWrite) {
        bag_ptr->open(cString, rosbag::bagmode::Write);
    } else {
        try {
            bag_ptr->open(cString, rosbag::bagmode::Read);
        }
        catch (...){
            printf("some thing with read rosbag file!\n");
            exit(0);
        }
    }
}

- (void) close {
    bag_ptr->close();
}

@end
