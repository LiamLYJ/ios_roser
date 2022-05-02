//
//  AVPreview.swift
//  ios_roser
//
//  Created by lyj on 2022/04/30.
//

import SwiftUI
import AVFoundation

class AVPreview: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
