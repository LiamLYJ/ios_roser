//
//  Struct.swift
//  ios_roser
//
//  Created by lyj on 2022/05/02.
//

import Foundation
import CoreMotion

struct Imu_T{
    var x: Double
    var y: Double
    var z: Double
    var timestamp: Double
    
    init (acc: CMAcceleration, timestamp: TimeInterval) {
        x = acc.x * 9.8
        y = acc.y * 9.8
        z = acc.z * 9.8
        self.timestamp = timestamp
    }
    
    init (gyro: CMRotationRate, timestamp: TimeInterval) {
        x = gyro.x
        y = gyro.y
        z = gyro.z
        self.timestamp = timestamp
    }
}
