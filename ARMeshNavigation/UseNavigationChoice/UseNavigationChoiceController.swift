//
//  UseNavigationChoiceController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/17.
//

import UIKit

class UseNavigationChoiceController: UIViewController {

    //どのボタンから画面遷移したかを表すID
    var seni_id = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func to_SaveDataChoiceController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "SaveDataNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SaveDataChoiceController") as! SaveDataChoiceController
        vc.seni_id = seni_id
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_ARColabNavigationController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "ARColabNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ARColabNavigationController") as! ARColabNavigationController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_VRColabNavigationController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "VRColabNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ColabDataChoiceController") as! ColabDataChoiceController
        vc.seni_id = 5
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
