//
//  ChangeModePopOver.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/08/15.
//

import UIKit

class ChangeModePopOver: UIViewController {
    
    @IBOutlet weak var switch1: UISwitch!
    @IBOutlet weak var switch2: UISwitch!
    @IBOutlet weak var switch3: UISwitch!
    @IBOutlet weak var switch4: UISwitch!
    var mode_num = 0
    var closure: ((Int) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func tap_switch1(_ sender: UISwitch) {
        switch2.isOn = false
        switch3.isOn = false
        switch4.isOn = false
        if sender.isOn == true {
            mode_num = 1
            closure?(mode_num)
        }
    }
    
    @IBAction func tap_switch2(_ sender: UISwitch) {
        switch1.isOn = false
        switch3.isOn = false
        switch4.isOn = false
        if sender.isOn == true {
            mode_num = 2
            closure?(mode_num)
        }
    }
    
    @IBAction func tap_switch3(_ sender: UISwitch) {
        switch1.isOn = false
        switch2.isOn = false
        switch4.isOn = false
        if sender.isOn == true {
            mode_num = 3
            closure?(mode_num)
        }
    }
    
    @IBAction func tap_switch4(_ sender: UISwitch) {
        switch1.isOn = false
        switch2.isOn = false
        switch3.isOn = false
        if sender.isOn == true {
            mode_num = 4
            closure?(mode_num)
        }
    }
}

