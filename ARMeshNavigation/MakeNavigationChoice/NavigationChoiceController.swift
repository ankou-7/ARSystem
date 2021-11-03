//
//  NavigationChoiceController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/15.
//

import UIKit

class NavigationChoiceController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func to_MakeNavigationController(_ sender: Any) {
        let storyboard = UIStoryboard(name: "MakeNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MakeNavigationController") as! MakeNavigationController
        //vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_NavigationDataCell1(_ sender: Any) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "EditDataChoiceController") as! EditDataChoiceController
        vc.seni_id = 2
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_NavigationDataCell1_eturan(_ sender: Any) {
        let storyboard = UIStoryboard(name: "CheckAllData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckDataChoiceController") as! CheckDataChoiceController
        vc.seni_id = 4
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
