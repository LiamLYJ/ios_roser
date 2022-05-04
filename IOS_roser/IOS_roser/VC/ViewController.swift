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
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var gpsSign: UILabel!
    @IBOutlet weak var recordSign: UILabel!
    
    @IBOutlet weak var preview: AVPreview!
    
    private var sensorSettingVC: SensorSettingVC!
    private var isSensorOn: Bool = false
    private var isSettingOn: Bool = false {
        didSet {
            sensorSettingVC.view.isHidden = !isSettingOn
        }
    }
    private var isRecordOn: Bool = false {
        didSet {
            recordSign.isHidden = !isRecordOn
        }
    }
    
    let videoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sensorSettingVC.sensorSettingDelegate = self
        recordSign.isHidden = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination
        if let _sensorSettingVC = destination as? SensorSettingVC {
            sensorSettingVC = _sensorSettingVC
        }
    }
    
    @IBAction func toggleSensor(_ sender: Any) {
        if (!isSensorOn) {
            sensorSettingVC.startSenor()
            sensorBtn.setTitle("Stop", for: .normal)
            isSensorOn = true
        } else {
            sensorSettingVC.stopSenor()
            sensorBtn.setTitle("Sensor", for: .normal)
            isSensorOn = false
        }
    }
    
    @IBAction func toggleSetting(_ sender: Any) {
        if (!isSettingOn) {
            isSettingOn = true
        } else {
            isSettingOn = false
        }
    }
    
    @IBAction func toggleRecord(_ sender: Any) {
        if (!isRecordOn) {
            sensorSettingVC.openRecording()
            recordBtn.setTitle("Stop", for: .normal)
            isRecordOn = true
        } else {
            sensorSettingVC.closeRecording()
            recordBtn.setTitle("Record", for: .normal)
            isRecordOn = false
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
    
    func updateInfo(info: String) {
        infoLabel.text = info
    }
    
    func updateGps(info: String) {
        gpsSign.text = info
    }

}
