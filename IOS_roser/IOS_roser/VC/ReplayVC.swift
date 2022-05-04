//
//  ReplayVC.swift
//  ios_roser
//
//  Created by lyj on 2022/05/02.
//

import UIKit
import Foundation

final class ReplayVC: UIViewController {

    public var filename: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    @IBAction func touchReturn(_ sender: Any) {
        dismiss(animated: false)
    }
}
