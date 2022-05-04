//
//  SensorSettingDelegate.swift
//  ios_roser
//
//  Created by lyj on 2022/04/30.
//

import Foundation
import AVFoundation

protocol SensorSettingDelegate: NSObjectProtocol {
    func configPreview(captureSession: AVCaptureSession)
    func updateInfo(info: String)
    func updateGps(info: String)
}

