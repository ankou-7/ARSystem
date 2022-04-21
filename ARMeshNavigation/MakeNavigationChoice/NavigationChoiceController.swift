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
    }
    
    @IBAction func to_MakeNavigationController(_ sender: Any) {
        let storyboard = UIStoryboard(name: "MakeNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MakeNavigationController") as! MakeNavigationController
        vc.modalPresentationStyle = .fullScreen
        
        let transition = CATransition()
        transition.duration = 0.25
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromRight
        view.window!.layer.add(transition, forKey: kCATransition)
        
        self.present(vc, animated: false, completion: nil)
        //self.navigationController?.pushViewController(vc, animated: true)//遷移する
    }
    
    @IBAction func to_NavigationDataCell1(_ sender: Any) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "EditDataChoiceController") as! EditDataChoiceController
//        vc.view.backgroundColor = UIColor.white
//        vc.modalPresentationStyle = .fullScreen
//        self.present(vc, animated: true, completion: nil)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func to_EditColabViewController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "EditColabViewController") as! EditColabViewController
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    
    @IBAction func to_NavigationDataCell1_eturan(_ sender: Any) {
        let storyboard = UIStoryboard(name: "CheckAllData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckDataChoiceController") as! CheckDataChoiceController
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
//    @IBAction func back(_ sender: Any) {
//        self.dismiss(animated: true, completion: nil)
//    }
}
