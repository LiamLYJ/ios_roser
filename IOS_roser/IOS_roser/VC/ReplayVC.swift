//
//  ReplayVC.swift
//  ios_roser
//
//  Created by lyj on 2022/05/02.
//

import UIKit
import Foundation
import MapKit
import SwiftUI

final class ReplayVC: UIViewController {

    public var filename: String = ""
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playBar: UISlider!
    @IBOutlet weak var playBtn: UIButton!
    
    private lazy var publisher: Publisher = Publisher()
    private var sessionQueue = DispatchQueue(label: "session_queue", qos: .userInteractive)
    
    private var imgRate: Double = 0.0
    private var imgTopic: NSString? = ""
    private var imuTopic: NSString? = ""
    private var gpsTopic: NSString? = ""
    private var imgCount: UInt32 = 0
    private var curFrameId: UInt32 = 0
    private var lastSliderFrame: UInt32 = 0
    
    private var gpsData: [(Double, CLLocation)] = []
    private var routeLine: MKPolyline? = nil
    private var me: MKCircle? = nil
    
    private var isPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playBar.isUserInteractionEnabled = true
        
        mapView.delegate = self
        let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let directoryContent = try! FileManager.default.contentsOfDirectory(atPath: dirPaths[0])
        for i in 0 ..< directoryContent.count {
            if (filename == directoryContent[i]) {
                let fullAddr = dirPaths[0].stringByAppendingPathComponent(path: directoryContent[i])
                publisher.open(fullAddr, isWrite: false)
                publisher.getFrameInfo(&imgRate, imgCount: &imgCount, imuTopic: &imuTopic, imgTopic: &imgTopic, gpsTopic: &gpsTopic)
                var timestamp: Double = 0.0
                imageView.image = publisher.getFrame(curFrameId, topic: imgTopic! as String, timestamp: &timestamp)
                playBar.maximumValue = max(0, Float(imgCount - 1))
                
                var gpsDataList = NSMutableArray()
                var gpsTimestampList = NSMutableArray()
                publisher.getGps(&gpsDataList, timestamps: &gpsTimestampList, topic: gpsTopic! as String)
                var _gpsData: [Double: CLLocation] = [:]
                for i in 0..<gpsDataList.count {
                    _gpsData[gpsTimestampList[i] as! Double] = gpsDataList[i] as? CLLocation
                }
                gpsData = _gpsData.sorted( by: { $0.0 < $1.0 })
                if (gpsData.count >= 2) {
                    routeLine = MKPolyline(coordinates: gpsData.map{$1.coordinate}, count: gpsData.count)
                    mapView.setVisibleMapRect(routeLine!.boundingMapRect, animated: true)
                    mapView.addOverlay(routeLine!)
                    updateGps(timestamp: timestamp)
                }
                break
            }
        }
    }
   
    private func updateGps(timestamp: Double) {
        var interpolateGps: CLLocationCoordinate2D = CLLocationCoordinate2D()
        let high = gpsData.firstIndex(where: {$0.0 > timestamp})
        if let high = high {
            if (high == 0) {
                interpolateGps = gpsData[0].1.coordinate
            } else {
                let low = high - 1
                let ratio = (timestamp - gpsData[low].0) / (gpsData[high].0 - gpsData[low].0)
                interpolateGps.longitude = gpsData[low].1.coordinate.longitude * (1 - ratio) + gpsData[high].1.coordinate.longitude * ratio
                interpolateGps.latitude = gpsData[low].1.coordinate.latitude * (1 - ratio) + gpsData[high].1.coordinate.latitude * ratio
            }
        } else {
            interpolateGps = gpsData.last!.1.coordinate
        }
        if me != nil {
            mapView.removeOverlay(me!)
        }
        me = MKCircle(center: interpolateGps, radius: 2)
        mapView.addOverlay(me!)
    }

    @IBAction func touchReturn(_ sender: Any) {
        publisher.close()
        dismiss(animated: false)
    }
    
    @IBAction func touchPlay(_ sender: Any) {
        if (isPlaying == false) {
            playBtn.setTitle("Stop", for: .normal)
            playBar.isUserInteractionEnabled = false
            isPlaying = true
            
            sessionQueue.async {
                while (self.curFrameId < self.imgCount) {
                    self.curFrameId += 1
                    var timestamp: Double = 0.0
                    let t1 = Date()
                    let uiImg: UIImage = self.publisher.getFrame(self.curFrameId, topic: self.imgTopic! as String, timestamp: &timestamp)
                    let t2 = Date()
                    let t12 = t2.timeIntervalSince(t1)
                    DispatchQueue.main.async {
                        self.imageView.image = uiImg
                        self.playBar.value = Float(self.curFrameId)
                        self.updateGps(timestamp: timestamp)
                    }
                    if self.imgRate - t12 > 0 {
                        Thread.sleep(forTimeInterval: self.imgRate - t12)
                    }
                    if self.isPlaying == false {
                        break
                    }
                }
                DispatchQueue.main.async {
                    self.playBtn.setTitle("Play", for: .normal)
                    self.playBar.isUserInteractionEnabled = true
                    self.isPlaying = false
                    self.curFrameId = 0
                    self.lastSliderFrame = 0
                    self.playBar.value = 0
                    var timestamp: Double = 0
                    self.imageView.image = self.publisher.getFrame(self.curFrameId, topic: self.imgTopic! as String, timestamp: &timestamp)
                    self.updateGps(timestamp: timestamp)
                }
            }
        } else {
            playBtn.setTitle("Play", for: .normal)
            playBar.isUserInteractionEnabled = true
            isPlaying = false
        }
        
    }
    
    @IBAction func changeSlider(_ sender: Any) {
        curFrameId = UInt32(playBar.value)
        if lastSliderFrame == curFrameId {
            return
        }
        lastSliderFrame = curFrameId
        var timestamp: Double = 0
        imageView.image = publisher.getFrame(curFrameId, topic: imgTopic! as String, timestamp: &timestamp)
        updateGps(timestamp: timestamp)
    }
}

extension ReplayVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay === me {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = .green.withAlphaComponent(0.7)
            renderer.fillColor = .blue.withAlphaComponent(0.3)
            renderer.lineWidth = 3
            return renderer
        }
        if overlay === routeLine {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .green.withAlphaComponent(0.7)
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }
}
