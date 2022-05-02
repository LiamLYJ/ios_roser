//
//  SensorSettingVC.swift
//  ios_roser
//
//  Created by lyj on 2022/04/29.
//

import UIKit
import AVFoundation
import CoreMotion
import CoreLocation

private var lenPosCxt = 0
private var shutterCxt = 0
private var isoCxt = 0
private let expPower: Double = 10.0  // for mapping shuttertime from linear to exponential
private let imuHz = 0.01

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
    @IBOutlet weak var cameraStackView: UIStackView!
    @IBOutlet weak var controlStackView: UIStackView!
    @IBOutlet weak var imuSwitch: UISwitch!
    @IBOutlet weak var gpsSwitch: UISwitch!
    @IBOutlet weak var imgSwitch: UISwitch!
    
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

    private lazy var motionManager: CMMotionManager = {
        return CMMotionManager()
    } ()
    private var acces: [Imu_T] = []
    private var gyros: [Imu_T] = []
    
    private lazy var locationManager: CLLocationManager = {
        return CLLocationManager()
    }()
    
    let publisher: Publisher = Publisher()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingView.isHidden = true
        cameraStackView.isHidden = true
        controlStackView.isHidden = true
        modeSelect.isHidden = false
        
        loadSetting()
        
        sessionQueue.async {
            self.configureSession()
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = 10
        locationManager.distanceFilter = 1
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func loadSetting() {
        if UserDefaults.standard.string(forKey: "cam_size") != nil {
            camSizeBtn.setTitle(UserDefaults.standard.string(forKey: "cam_size"), for: .normal)
        }
        if UserDefaults.standard.string(forKey: "cam_hz") != nil {
            imgHzText.text = UserDefaults.standard.string(forKey: "cam_hz")
        }
    }
    
    @IBAction func changeHUD(_ sender: Any) {
        cameraStackView.isHidden = true
        controlStackView.isHidden = true
        if modeSelect.selectedSegmentIndex == ModeSel.ROS.rawValue {
            // TODO
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
            let alert = UIAlertController(title: "hz range need to be a number", message: "error!", preferredStyle: .alert)
            present(alert, animated: true, completion: nil)
            let when = DispatchTime.now() + 3
            DispatchQueue.main.asyncAfter(deadline: when){
                alert.dismiss(animated: true, completion: nil)
            }
            return
        }
        if val <= 30 && val >= 1 {
            guard let _ = try? videoDevice.lockForConfiguration() else {
                print(" can not lock configure to change framerate!\n")
                return
            }
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(val))
            videoDevice.unlockForConfiguration()
 
            UserDefaults.standard.set(String(val), forKey: "cam_hz")
        } else {
            let alert = UIAlertController(title: "hz range in 1-30", message: "error!", preferredStyle: .alert)
            present(alert, animated: true, completion: nil)
            let when = DispatchTime.now() + 3
            DispatchQueue.main.asyncAfter(deadline: when){
                alert.dismiss(animated: true, completion: nil)
            }
            return
        }
    }
    
    @IBAction func done(_ sender: UITextField) {
        sender.resignFirstResponder()
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
       
    private func startImuUpdate() {
        if (motionManager.isAccelerometerAvailable && imuSwitch.isOn) {
            motionManager.accelerometerUpdateInterval = imuHz
            motionManager.startAccelerometerUpdates(to: retrieveQueue) {
                (data, error) in if let data = data {
                    let cur: Imu_T = Imu_T(acc: data.acceleration, timestamp: data.timestamp)
                    self.acces.append(cur)
                }
            }
        }
        if (motionManager.isGyroAvailable && imuSwitch.isOn) {
            motionManager.gyroUpdateInterval = imuHz
            motionManager.startGyroUpdates(to: retrieveQueue) {
                (data, error) in if let data = data {
                    let cur: Imu_T = Imu_T(gyro: data.rotationRate, timestamp: data.timestamp)
                    self.gyros.append(cur)
                    self.publisher.publishImu(gyros: &self.gyros, acces: &self.acces)
                }
            }
        }
    }
    
    private func stopImuUpdate() {
        motionManager.stopGyroUpdates()
        motionManager.stopAccelerometerUpdates()
    }
    
    public func startSenor() {
        captureSession.startRunning()
        startImuUpdate()
        locationManager.startUpdatingLocation()
        
        addObservers()
    }
 
    public func stopSenor() {
        captureSession.stopRunning()
        stopImuUpdate()
        locationManager.stopUpdatingLocation()
        
        removeObservers()
    }
}

private extension SensorSettingVC {
    enum ModeSel: Int {
        case ROS = 0
        case CAMERA = 1
        case CONTROL = 2
    }    
}

extension SensorSettingVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard imgSwitch.isOn else {
            return
        }
        publisher.publishImg()
    }
}

extension SensorSettingVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard gpsSwitch.isOn else {
            return
        }
        publisher.publishGps()
    }
}
