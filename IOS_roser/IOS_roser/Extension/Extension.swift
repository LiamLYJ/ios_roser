//
//  AVCaptureVideoOrientation.swift
//  ios_roser
//
//  Created by lyj on 2022/04/30.
//

import AVFoundation
import UIKit

extension AVCaptureVideoOrientation {
    var uiO: UIInterfaceOrientation {
        get {
            switch self {
            case .landscapeLeft:        return .landscapeLeft
            case .landscapeRight:       return .landscapeRight
            case .portrait:             return .portrait
            case .portraitUpsideDown:   return .portraitUpsideDown
            default:                    return .portrait
            }
        }
    }
}

extension UIInterfaceOrientation {
    var avO: AVCaptureVideoOrientation{
        get {
            switch self {
            case .landscapeLeft:        return .landscapeLeft
            case .landscapeRight:       return .landscapeRight
            case .portrait:             return .portrait
            case .portraitUpsideDown:   return .portraitUpsideDown
            default:                    return .portrait
            }
        }
    }
}

