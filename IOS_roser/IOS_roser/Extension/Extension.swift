//
//  AVCaptureVideoOrientation.swift
//  ios_roser
//
//  Created by lyj on 2022/04/30.
//

import AVFoundation
import Network
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

extension CMSampleBuffer {
    var uiImg: UIImage {
        get {
            // Get a CMSampleBuffer's Core Video image buffer for the media data
            let  imageBuffer = CMSampleBufferGetImageBuffer(self)
            // Lock the base address of the pixel buffer
            CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
            
            
            // Get the number of bytes per row for the pixel buffer
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
            
            // Get the number of bytes per row for the pixel buffer
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
            // Get the pixel buffer width and height
            let width = CVPixelBufferGetWidth(imageBuffer!)
            let height = CVPixelBufferGetHeight(imageBuffer!)
            
            // Create a device-dependent RGB color space
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // Create a bitmap graphics context with the sample buffer data
            var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
            bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
            //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
            let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
            // Create a Quartz image from the pixel data in the bitmap graphics context
            let quartzImage = context?.makeImage()
            // Unlock the pixel buffer
            CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
            
            // Create an image object from the Quartz image
            let image = UIImage.init(cgImage: quartzImage!)
            
            return (image)
        }
    }
}

extension String {
    func stringByAppendingPathComponent(path: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(path)
    }
    
    var validateIpAddress: Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()

        if self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return true
        }
        else if self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return true
        }

        return false;
    }
}

extension UIViewController {
    func setupEasyOneWithDelay(title: String, msg: String, delayToVanish: Int) {
        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
        let when = DispatchTime.now() + DispatchTimeInterval.seconds(delayToVanish)
        DispatchQueue.main.asyncAfter(deadline: when){
            alert.dismiss(animated: true, completion: nil)
        }
    }
}
