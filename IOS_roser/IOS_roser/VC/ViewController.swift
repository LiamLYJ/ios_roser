//
//  ViewController.swift
//  ios_roser
//
//  Created by lyj on 2022/04/27.
//

import UIKit
import AVFoundation

final class ViewController: UIViewController {

    @IBOutlet weak var sensorBtn: UIButton!
    @IBOutlet weak var settingBtn: UIButton!
    @IBOutlet weak var recordBtn: UIButton!
    
    @IBOutlet weak var preview: AVPreview!
    
    private var sensorSettingVC: SensorSettingVC!
    private var is_sensor_on: Bool = false
    private var is_setting_on: Bool = false
    
    let videoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sensorSettingVC.sensorSettingDelegate = self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination
        if let _sensorSettingVC = destination as? SensorSettingVC {
            sensorSettingVC = _sensorSettingVC
        }
    }
    
    @IBAction func toggleSensor(_ sender: Any) {
        if (!is_sensor_on) {
            sensorSettingVC.startSenor()
            sensorBtn.setTitle("Stop", for: .normal)
            is_sensor_on = true
        } else {
            sensorSettingVC.stopSenor()
            is_sensor_on = false
            sensorBtn.setTitle("Sensor", for: .normal)
        }
    }
    
    @IBAction func toggleSetting(_ sender: Any) {
        if (!is_setting_on) {
            
            is_setting_on = true
            sensorSettingVC.view.isHidden = false
        } else {
            is_setting_on = false
            sensorSettingVC.view.isHidden = true
        }
    }
    
}

extension ViewController: SensorSettingDelegate {
    func configPreview(captureSession: AVCaptureSession) {
        DispatchQueue.main.sync {
            let statusBarOrientation = UIApplication.shared.statusBarOrientation
            var initialVideoOrientation = AVCaptureVideoOrientation.portrait
            if statusBarOrientation != UIInterfaceOrientation.unknown {
                initialVideoOrientation = statusBarOrientation.avO
            }
            preview.videoPreviewLayer.session = captureSession
            preview.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
        }
    }
}
