//
//  SensorSettingVC.swift
//  ios_roser
//
//  Created by lyj on 2022/04/29.
//

import UIKit
import AVFoundation
import Foundation
import CoreMotion
import CoreLocation
import Network
import SwiftUI

private var lenPosCxt = 0
private var shutterCxt = 0
private var isoCxt = 0
private let expPower: Double = 10.0  // for mapping shuttertime from linear to exponential
private let imuMaxHz = 300
private let camMaxHz = 50

final class SensorSettingVC: UIViewController {
    @IBOutlet var settingView: UIView!
    @IBOutlet weak var modeSelect: UISegmentedControl!
    @IBOutlet weak var camSizeBtn: UIButton!
    @IBOutlet weak var focusModeControl: UISegmentedControl!
    @IBOutlet weak var lenPosSli: UISlider!
    @IBOutlet weak var expModeControl: UISegmentedControl!
    @IBOutlet weak var shutterSli: UISlider!
    @IBOutlet weak var isoSli: UISlider!
    @IBOutlet weak var imgHzText: UITextField!
    @IBOutlet weak var imuHzText: UITextField!
    @IBOutlet weak var rosSettingStackView: UIStackView!
    @IBOutlet weak var cameraStackView: UIStackView!
    @IBOutlet weak var controlStackView: UIStackView!
    @IBOutlet weak var imuSwitch: UISwitch!
    @IBOutlet weak var gpsSwitch: UISwitch!
    @IBOutlet weak var imgSwitch: UISwitch!
    @IBOutlet weak var fileList: UIPickerView!
    @IBOutlet weak var imuTopic: UITextField!
    @IBOutlet weak var gpsTopic: UITextField!
    @IBOutlet weak var camTopic: UITextField!
    @IBOutlet weak var masterIP: UITextField!
    
    private var fileListData: [String] = []
    private var selectedFile: String = ""
    
    let camSizes: [AVCaptureSession.Preset] = [AVCaptureSession.Preset.vga640x480, AVCaptureSession.Preset.hd1280x720, AVCaptureSession.Preset.hd1920x1080]
    let camSizesName: [String] = ["640x480", "1280x720", "1920x1080"]
    
    let focusMode: [AVCaptureDevice.FocusMode] = [AVCaptureDevice.FocusMode.continuousAutoFocus, AVCaptureDevice.FocusMode.locked] // only use two mode to meet with UI
    
    let expMode: [AVCaptureDevice.ExposureMode] = [AVCaptureDevice.ExposureMode.continuousAutoExposure, AVCaptureDevice.ExposureMode.custom] // only use two mode to meet with UI
    
    private var sessionQueue = DispatchQueue(label: "session_queue", qos: .userInteractive)
    private var retrieveQueue = OperationQueue()
    private var captureSession: AVCaptureSession = AVCaptureSession()
    weak var sensorSettingDelegate: SensorSettingDelegate?
    
    @objc dynamic private lazy var videoDevice: AVCaptureDevice = {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)!
    } ()

    private var imuHz: Int = 0
    private var imgHz: Int = 0
    
    private lazy var motionManager: CMMotionManager = {
        return CMMotionManager()
    } ()
    private var acces: [CMAccelerometerData] = []
    private var gyros: [CMGyroData] = []
    
    private lazy var locationManager: CLLocationManager = {
        return CLLocationManager()
    }()
    
    private let publisher: Publisher = Publisher()
    private var imgCount: UInt32 = 0
    private var imuCount: UInt32 = 0
    private var gpsCount: UInt32 = 0
    
    private var isRecordingBag: Bool = false
    private var isPublishing: Bool = false
    private var syncSensorTime: Double = 0.0
    private var syncSysTime: Date = Date();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingView.isHidden = true
        rosSettingStackView.isHidden = true
        cameraStackView.isHidden = true
        controlStackView.isHidden = true
        modeSelect.isHidden = false
        
        loadBefore()
        
        sessionQueue.async {
            self.configureSession()
        }
        retrieveQueue.maxConcurrentOperationCount = 1
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = 10
        locationManager.distanceFilter = 1
        locationManager.requestWhenInUseAuthorization()
        
        fileList.delegate = self
        fileList.dataSource = self
        
        imgHz = Int(imgHzText.text!)!
        imuHz = Int(imuHzText.text!)!
    }
    
    @IBAction func touchDelAll(_ sender: Any) {
        deleteBagList(filename: nil)
        updateBagList()
    }
    
    @IBAction func touchDelOne(_ sender: Any) {
        deleteBagList(filename: selectedFile)
        updateBagList()
    }
    
    @IBAction func touchReplay(_ sender: Any) {
        if selectedFile == "" {
            setupEasyOneWithDelay(title: "no file recorded", msg: "error!", delayToVanish: 2)
        } else {
            let story = UIStoryboard(name: "Main", bundle: nil)
            let add: ReplayVC = story.instantiateViewController(withIdentifier: "ReplayVC") as! ReplayVC
            add.filename = selectedFile
            present(add, animated: false)
        }
    }
    
    private func loadBefore() {
        if UserDefaults.standard.string(forKey: "cam_size") != nil {
            camSizeBtn.setTitle(UserDefaults.standard.string(forKey: "cam_size"), for: .normal)
        }
        if UserDefaults.standard.string(forKey: "cam_hz") != nil {
            imgHzText.text = UserDefaults.standard.string(forKey: "cam_hz")
        }
        if UserDefaults.standard.string(forKey: "imu_hz") != nil {
            imuHzText.text = UserDefaults.standard.string(forKey: "imu_hz")
        }
        if UserDefaults.standard.string(forKey: "cam_topic") != nil {
            camTopic.text = UserDefaults.standard.string(forKey: "cam_topic")
        }
        if UserDefaults.standard.string(forKey: "imu_topic") != nil {
            imuTopic.text = UserDefaults.standard.string(forKey: "imu_topic")
        }
        if UserDefaults.standard.string(forKey: "gps_topic") != nil {
            gpsTopic.text = UserDefaults.standard.string(forKey: "gps_topic")
        }
        if UserDefaults.standard.string(forKey: "master_ip") != nil {
            masterIP.text = UserDefaults.standard.string(forKey: "master_ip")
        }
        updateBagList()
    }
    
    @IBAction func changeHUD(_ sender: Any) {
        rosSettingStackView.isHidden = true
        cameraStackView.isHidden = true
        controlStackView.isHidden = true
        if modeSelect.selectedSegmentIndex == ModeSel.ROS.rawValue {
            rosSettingStackView.isHidden = false
        } else if modeSelect.selectedSegmentIndex == ModeSel.CAMERA.rawValue {
            cameraStackView.isHidden = false
        } else if modeSelect.selectedSegmentIndex == ModeSel.CONTROL.rawValue {
            controlStackView.isHidden = false
        }
    }
    
    private func changeCamSize(cam_size_id: Int) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = camSizes[cam_size_id]
        captureSession.commitConfiguration()
        camSizeBtn.setTitle(camSizesName[cam_size_id], for: .normal)
        UserDefaults.standard.set(camSizesName[cam_size_id], forKey: "cam_size")
    }
 
    @IBAction func chooseImgSize(_ sender: Any) {
        let imgSizeOptionsControlller: UIAlertController = UIAlertController(title: "choose a size", message: nil, preferredStyle: .actionSheet)
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: .cancel)
        imgSizeOptionsControlller.addAction(cancelAction)
       
        for i in 0 ..< camSizes.count {
            let newDeviceOption: UIAlertAction = UIAlertAction(title: camSizesName[i], style: .default, handler: {_ in self.changeCamSize(cam_size_id: i)} )
            imgSizeOptionsControlller.addAction(newDeviceOption)
        }
        present(imgSizeOptionsControlller, animated: true, completion: nil)
    }
    
    @IBAction func changeImgHz(_ sender: Any) {
        let val = Int(imgHzText.text ?? "")
        guard let val = val else {
            setupEasyOneWithDelay(title: "hz range need to be a number", msg: "error!", delayToVanish: 2)
            return
        }
        if val <= camMaxHz && val >= 1 {
            guard let _ = try? videoDevice.lockForConfiguration() else {
                print(" can not lock configure to change framerate!\n")
                return
            }
            
            imgHz = val
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(imgHz))
            videoDevice.unlockForConfiguration()
 
        } else {
            setupEasyOneWithDelay(title: "hz range in 1-\(camMaxHz)", msg: "error!", delayToVanish: 2)
            imgHz = camMaxHz
            imgHzText.text = String(camMaxHz)
        }
        UserDefaults.standard.set(val, forKey: "cam_hz")
    }
    
    @IBAction func changeImuHz(_ sender: Any) {
        let val = Int(imuHzText.text ?? "")
        guard let val = val else {
            setupEasyOneWithDelay(title: "hz range need to be a number", msg: "error!", delayToVanish: 2)
            return
        }
        if val <= imuMaxHz && val >= 1 {
            guard let _ = try? videoDevice.lockForConfiguration() else {
                print(" can not lock configure to change framerate!\n")
                return
            }
            
            imuHz = val
        } else {
            setupEasyOneWithDelay(title: "hz range in 1-\(imuMaxHz)", msg: "error!", delayToVanish: 2)
            imuHz = imuMaxHz
            imuHzText.text = String(imuMaxHz)
        }
        UserDefaults.standard.set(val, forKey: "imu_hz")
    }
 
    
    @IBAction func done(_ sender: UITextField) {
        sender.resignFirstResponder()
        UserDefaults.standard.set(imgHzText.text, forKey: "cam_hz")
        UserDefaults.standard.set(masterIP.text, forKey: "master_ip")
        UserDefaults.standard.set(imuTopic.text, forKey: "imu_topic")
        UserDefaults.standard.set(gpsTopic.text, forKey: "gps_topic")
        UserDefaults.standard.set(camTopic.text, forKey: "cam_topic")
    }
    
    @IBAction func changeFocusMode(_ sender: Any) {
         if let _ = try? videoDevice.lockForConfiguration() {
             if focusModeControl.selectedSegmentIndex == 0 {
                 lenPosSli.isUserInteractionEnabled = false
                 videoDevice.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
             } else {
                 videoDevice.focusMode = AVCaptureDevice.FocusMode.locked
                 lenPosSli.isUserInteractionEnabled = true
             }

            videoDevice.unlockForConfiguration()
        } else {
            print("can not change focus mode\n")
        }
    }
    
    @IBAction func changeLenPosition(_ sender: Any) {
        if let _ = try? videoDevice.lockForConfiguration() {

            videoDevice.setFocusModeLocked(lensPosition: lenPosSli.value)
            videoDevice.unlockForConfiguration()
        } else {
            print("can not change len pos\n")
        }
    }
    
    @IBAction func changeExpMode(_ sender: Any) {
         if let _ = try? videoDevice.lockForConfiguration() {
             if expModeControl.selectedSegmentIndex == 0 {
                 videoDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                 shutterSli.isUserInteractionEnabled = false
                 isoSli.isUserInteractionEnabled = false
             } else {
                 videoDevice.exposureMode = AVCaptureDevice.ExposureMode.custom
                 shutterSli.isUserInteractionEnabled = true
                 isoSli.isUserInteractionEnabled = true
             }
            videoDevice.unlockForConfiguration()
        } else {
            print("can not change exp mode\n")
        }
    }
    
    @IBAction func changeShutter(_ sender: Any) {
        if let _ = try? videoDevice.lockForConfiguration() {
            let p = pow(Double(shutterSli.value), expPower)
            let minShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration)
            let maxShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration)
            let newShutterSecs = p * (maxShutterSecs - minShutterSecs) + minShutterSecs
            
            videoDevice.setExposureModeCustom(duration: CMTimeMakeWithSeconds(newShutterSecs, preferredTimescale: 1000*1000*1000), iso: AVCaptureDevice.currentISO)
            videoDevice.unlockForConfiguration()
        } else {
            print("can not change ISO\n")
        }
    }
    
    @IBAction func changeISO(_ sender: Any) {
        if let _ = try? videoDevice.lockForConfiguration() {
            videoDevice.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: isoSli.value)
            videoDevice.unlockForConfiguration()
        } else {
            print("can not change ISO\n")
        }
    }
    
    private func configureHUD() {
        focusModeControl.selectedSegmentIndex = focusMode.firstIndex(of: videoDevice.focusMode) ?? 0
        lenPosSli.minimumValue = 0.0
        lenPosSli.maximumValue = 1.0
        lenPosSli.value = videoDevice.lensPosition

        expModeControl.selectedSegmentIndex = expMode.firstIndex(of: videoDevice.exposureMode) ?? 0
        shutterSli.minimumValue = 0.0
        shutterSli.maximumValue = 1.0
        let shutterTime = CMTimeGetSeconds(videoDevice.exposureDuration)
        let minShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration)
        let maxShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration)
        let p = (shutterTime - minShutterSecs) / (maxShutterSecs - minShutterSecs)
        shutterSli.value = Float(pow(p, 1.0 / expPower))
        isoSli.minimumValue = videoDevice.activeFormat.minISO
        isoSli.maximumValue = videoDevice.activeFormat.maxISO
        isoSli.value = videoDevice.iso
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        DispatchQueue.main.sync {
            let btn_string = camSizeBtn.title(for: .normal)
            var find_size = false
            for i in 0 ..< camSizesName.count {
                if camSizesName[i] == btn_string {
                    captureSession.sessionPreset = camSizes[i]
                    find_size = true
                }
            }
            if !find_size {
                captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480
                camSizeBtn.setTitle("640x480", for: .normal)
            }
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
            captureSession.canAddInput(videoDeviceInput) else {
            print("Creat vide devcie failed")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(videoDeviceInput)

        sensorSettingDelegate?.configPreview(captureSession: captureSession)
        
        if let _ = try? videoDevice.lockForConfiguration() {
            videoDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            videoDevice.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus

            DispatchQueue.main.sync {
                lenPosSli.isUserInteractionEnabled = false
                shutterSli.isUserInteractionEnabled = false
                isoSli.isUserInteractionEnabled = false
            }
            
            videoDevice.unlockForConfiguration()
        }
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
        dataOutput.alwaysDiscardsLateVideoFrames = true

        
        if captureSession.canAddOutput(dataOutput) == true {
            captureSession.addOutput(dataOutput)
        } else {
            print("some thing wrong for add output img sream handle")
            exit(0)
        }
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)

        captureSession.commitConfiguration()
        
        DispatchQueue.main.sync {
            self.configureHUD()
        }
    }
    
    private func addObservers() {
        addObserver(self, forKeyPath: "videoDevice.lensPosition", options: .new, context: &lenPosCxt)
        addObserver(self, forKeyPath: "videoDevice.exposureDuration", options: .new, context: &shutterCxt)
        addObserver(self, forKeyPath: "videoDevice.ISO", options: .new, context: &isoCxt)
    }
    
    private func removeObservers() {
        removeObserver(self, forKeyPath: "videoDevice.lensPosition", context: &lenPosCxt)
        removeObserver(self, forKeyPath: "videoDevice.exposureDuration", context: &shutterCxt)
        removeObserver(self, forKeyPath: "videoDevice.ISO", context: &isoCxt)
    }
 
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &lenPosCxt{
            lenPosSli.value = change?[NSKeyValueChangeKey.newKey] as! Float
        } else if context == &shutterCxt {
            let val = change?[NSKeyValueChangeKey.newKey]! as! CMTime
            let shutterTime = CMTimeGetSeconds(val)
            let minShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration)
            let maxShutterSecs = CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration)
            let p = (shutterTime - minShutterSecs) / (maxShutterSecs - minShutterSecs)
            shutterSli.value = Float(pow(p, 1 / expPower))
        } else if context == &isoCxt {
            isoSli.value = change?[NSKeyValueChangeKey.newKey] as! Float
        }
    }
            
    public func startSenor() {
        captureSession.startRunning()
        startImuUpdate()
        locationManager.startUpdatingLocation()
        
        addObservers()
        
        imgHzText.isUserInteractionEnabled = false
        imuHzText.isUserInteractionEnabled = false
        camSizeBtn.isUserInteractionEnabled = false
    }
 
    public func stopSenor() {
        captureSession.stopRunning()
        stopImuUpdate()
        locationManager.stopUpdatingLocation()
        
        removeObservers()
        
        imgHzText.isUserInteractionEnabled = true
        imuHzText.isUserInteractionEnabled = true
        camSizeBtn.isUserInteractionEnabled = true
    }
    
    @IBAction func changeMasterIp(_ sender: Any) {
        let ipString = masterIP.text!
        if !ipString.validateIpAddress {
            setupEasyOneWithDelay(title: "ip is not valid, plz input again", msg: "error!", delayToVanish: 2)
            masterIP.text = "192.168.0.1"
        }
    }
    
    public func connectToMaster() -> Bool {
        var suc = false
        if let selfIp = getWifiIPAddress() {
            suc = publisher.connectMaster(masterIP.text!, selfIp: selfIp, camTopic: camTopic.text!, imuTopic: imuTopic.text!, gpsTopic: gpsTopic.text!)
        }
        if suc {
            masterIP.isUserInteractionEnabled = false
        } else {
            setupEasyOneWithDelay(title: "connect master failed!", msg: "error!", delayToVanish: 2)
        }
        return suc
    }
    
    public func setPublish(needPublishing: Bool) {
        isPublishing = needPublishing
        publisher.setNeedPublishing(needPublishing)
    }
    
    private func updateBagList() {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let directoryContent = try! FileManager.default.contentsOfDirectory(atPath: dirPaths[0])
//        var hasFile = false
        for i in 0 ..< directoryContent.count {
            if i == 0 {
                selectedFile = directoryContent[i]
//                hasFile = true
                break
            }
//            print("file: \(directoryContent[i+1])")
        }
        fileListData = directoryContent
        fileList.reloadAllComponents()
        if directoryContent.count > 0 {
            fileList.selectRow(0, inComponent: 0, animated: false)
        }
    }
    
    private func deleteBagList(filename: String?) {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let directoryContent = try! FileManager.default.contentsOfDirectory(atPath: dirPaths[0])
        let delAll: Bool = filename == nil ? true: false
        for i in 0 ..< directoryContent.count {
            let fullAddr = dirPaths[0].stringByAppendingPathComponent(path: directoryContent[i])
            if delAll {
                try? FileManager.default.removeItem(atPath: fullAddr)
            } else {
                if filename == directoryContent[i] {
                    try? FileManager.default.removeItem(atPath: fullAddr)
                }
            }
        }
    }
    
    public func openRecording() {
        sessionQueue.async {
            let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd-HH-mm-ss"
            let timeString = formatter.string(from: Date()) + ".bag"
            let fn = dirPaths[0].stringByAppendingPathComponent(path: timeString)
//            print("filename: \(fn)\n")
            self.publisher.open(fn, isWrite: true)
            self.isRecordingBag = true
        }
    }
    
    public func closeRecording() {
        isRecordingBag = false
        sessionQueue.async {
            self.publisher.close()
        }
        updateBagList()
    }
}

private extension SensorSettingVC {
    enum ModeSel: Int {
        case ROS = 0
        case CAMERA = 1
        case CONTROL = 2
    }
    
    func getWifiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}

extension SensorSettingVC {
    
    private func processIMU() {
        func interpolate(v1: Double, v2: Double, t1: Double, t2:Double, t3: Double) -> Double {
            return v1+(v2-v1)*(t3-t1)/(t2-t1)
        }

        var last_acc_id = -1
        var last_gryo_id = -1
        for i in 0 ..< self.gyros.count {
            for j in 0 ..< self.acces.count - 1 {
                if (self.gyros[i].timestamp > self.acces[j].timestamp && self.gyros[i].timestamp <= self.acces[j+1].timestamp) {
                    let acc_x = interpolate(v1: self.acces[j].acceleration.x, v2: self.acces[j+1].acceleration.x, t1: self.acces[j].timestamp, t2: self.acces[j+1].timestamp, t3: self.gyros[i].timestamp)
                    let acc_y = interpolate(v1: self.acces[j].acceleration.y, v2: self.acces[j+1].acceleration.y, t1: self.acces[j].timestamp, t2: self.acces[j+1].timestamp, t3: self.gyros[i].timestamp)
                    let acc_z = interpolate(v1: self.acces[j].acceleration.z, v2: self.acces[j+1].acceleration.z, t1: self.acces[j].timestamp, t2: self.acces[j+1].timestamp, t3: self.gyros[i].timestamp)
                    let gyro_x = self.gyros[i].rotationRate.x
                    let gyro_y = self.gyros[i].rotationRate.y
                    let gyro_z = self.gyros[i].rotationRate.z
                    let timestamp = self.gyros[i].timestamp
                    let count = self.imuCount
                    let topic = self.imuTopic.text!
                    if self.isRecordingBag || self.isPublishing {
                        sessionQueue.async {
                            let imu_data = Imu_T(acc_x: acc_x*9.8, acc_y: acc_y*9.8, acc_z: acc_z*9.8, gyro_x: gyro_x, gyro_y: gyro_y, gyro_z: gyro_z, header_seq: count, timestamp: timestamp)
                            self.publisher.publishImu(imu_data, topic: topic)
                        }
                    }
                    self.imuCount += 1
                    last_acc_id = j
                    last_gryo_id = i
                    break
                }
            }
        }
        
        if last_acc_id > 0 {
            if last_acc_id - 1 < self.acces.count {
                self.acces.removeSubrange(0 ..< last_acc_id)
            } else {
                print("imu acc data bad happned")
                exit(0)
            }
        }
        if last_gryo_id >= 0 {
            if (last_gryo_id < self.gyros.count) {
                self.gyros.removeSubrange(0 ... last_gryo_id)
            } else {
                print("imu gyro data bad happned")
                exit(0)
            }
        }
    }
       
    private func startImuUpdate() {
        if (motionManager.isAccelerometerAvailable) {
            motionManager.accelerometerUpdateInterval = 1.0 / Double(imuHz)
            motionManager.startAccelerometerUpdates(to: retrieveQueue) {
                (data, error) in if let data = data {
                    guard self.imuSwitch.isOn else {return}
                    self.acces.append(data)
                }
            }
        }
        if (motionManager.isGyroAvailable) {
            motionManager.gyroUpdateInterval = 1.0 / Double(imuHz)
            motionManager.startGyroUpdates(to: retrieveQueue) {
                (data, error) in if let data = data {
                    guard self.imuSwitch.isOn else {return}
                    self.gyros.append(data)
                    if !(self.gyros.count == 0 || self.acces.count == 0) {
                        self.processIMU()
                    }
                }
            }
        }
    }
    
    private func stopImuUpdate() {
        motionManager.stopGyroUpdates()
        motionManager.stopAccelerometerUpdates()
    }
}

extension SensorSettingVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard imgSwitch.isOn && (isRecordingBag || isPublishing) else {
            return
        }
        let topic = self.camTopic.text!
        sessionQueue.async {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.syncSensorTime = (Double)(timestamp.value) / (Double)(timestamp.timescale)
            self.syncSysTime = Date()
            self.publisher.publishImg(sampleBuffer.uiImg, timestamp: self.syncSensorTime, topic: topic, imgCount: self.imgCount)
            self.imgCount += 1
        }
    }
}

extension SensorSettingVC: CLLocationManagerDelegate {
    private func processGPS(location: CLLocation) {
        DispatchQueue.main.async {
            let gpsInfo = "gps: \(location.horizontalAccuracy) m"
            self.sensorSettingDelegate?.updateGps(info: gpsInfo)
        }
        
        let eventDate = location.timestamp
        let timeChange = eventDate.timeIntervalSince(self.syncSysTime)
        let howRecent = timeChange + self.syncSensorTime
        
        if self.isRecordingBag || self.isPublishing{
            sessionQueue.async {
                self.publisher.publishGps(location, topic: self.gpsTopic.text!, timestamp: howRecent, gpsCount: self.gpsCount)
            }
        }
        self.gpsCount += 1
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        guard gpsSwitch.isOn && syncSensorTime >= 0 else {
            return
        }
        var newLocation: CLLocation = CLLocation()
        var found = false
        for location in locations.reversed() {
            if location.horizontalAccuracy >= 0 {
                found = true
                newLocation = location
                break
            }
        }
        if !found {
            return
        }
        // discard longterm result
        let locationAge = -newLocation.timestamp.timeIntervalSinceNow
        if locationAge > 5.0 {
            return
        }
        
        self.processGPS(location: newLocation)
    }
}

extension SensorSettingVC: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < fileListData.count {
            selectedFile = fileListData[row]
            let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let fullAddr = dirPaths[0].stringByAppendingPathComponent(path: selectedFile)
            let info = publisher.getInfo(fullAddr)
            sensorSettingDelegate?.updateInfo(info: info)
        }
    }
}

extension SensorSettingVC: UIPickerViewDataSource {
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return fileListData.count
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return fileListData[row]
    }
}
