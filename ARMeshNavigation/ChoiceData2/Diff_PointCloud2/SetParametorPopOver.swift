//
//  SetParametorPopOver.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/18.
//

import UIKit

class SetParametorPopOver: UIViewController {
    
    var voxel_size: Float!
    @IBOutlet weak var voxel_size_label: UILabel!
    @IBOutlet weak var voxel_slider: UISlider!
    var closure: ((Float) -> Void)?
    
    @IBOutlet weak var UISwitch1: UISwitch!
    @IBOutlet weak var UISwitch2: UISwitch!
    var diff_mode_num: Int!
    var closure2: ((Int) -> Void)?
    
    var in_voxel_count: Int!
    @IBOutlet weak var in_voxel_count_label: UILabel!
    @IBOutlet weak var in_voxel_count_slider: UISlider!
    var closure3: ((Int) -> Void)?
    
    var remove_voxel_num: Int!
    @IBOutlet weak var remove_voxel_num_label: UILabel!
    @IBOutlet weak var remove_voxel_slider: UISlider!
    var closure4: ((Int) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        voxel_slider.value = voxel_size
        voxel_size_label.text = String(voxel_size) + "cm"
        
        if diff_mode_num == 1 {
            UISwitch1.isOn = true
        }
        else if diff_mode_num == 2 {
            UISwitch2.isOn = true
        }
        
        in_voxel_count_slider.value = Float(in_voxel_count)
        in_voxel_count_label.text = "\(String(in_voxel_count))個以上を残す"
        
        remove_voxel_slider.value = Float(remove_voxel_num)
        remove_voxel_num_label.text = "周囲\(String(remove_voxel_num))個以上を残す"
    }
    
    @IBAction func voxel_slider(_ sender: UISlider) {
        let value = round(sender.value * 10)
        voxel_size_label.text = String(value / 10) + "cm"
        voxel_size = value / 10
        closure?(voxel_size)
    }
    
    @IBAction func switch1(_ sender: UISwitch) {
        UISwitch2.isOn = false
        if sender.isOn == true {
            diff_mode_num = 1
            closure2?(diff_mode_num)
        }
    }
    
    @IBAction func switch2(_ sender: UISwitch) {
        UISwitch1.isOn = false
        if sender.isOn == true {
            diff_mode_num = 2
            closure2?(diff_mode_num)
        }
    }
    
    @IBAction func in_voxel_count_slider(_ sender: UISlider) {
        let value = round(sender.value)
        in_voxel_count_label.text = "\(String(Int(value)))個以上を残す"
        in_voxel_count = Int(value)
        closure3?(in_voxel_count)
    }
    
    @IBAction func remove_voxel_slider(_ sender: UISlider) {
        let value = round(sender.value)
        remove_voxel_num_label.text = "周囲\(String(Int(value)))個以上を残す"
        remove_voxel_num = Int(value)
        closure4?(remove_voxel_num)
    }
    
}
