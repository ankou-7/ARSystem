//
//  NavigationChoiceController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/15.
//

import UIKit

class NavigationChoiceController: UIViewController {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var collabButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let items = UIMenu(options: .displayInline, children: [
            UIAction(title: "ARコラボレーション", image: .none, handler: { _ in
                print("AR")
                self.to_ColabARViewController()
            }),
            UIAction(title: "VRコラボレーション", image: .none, handler: { _ in
                print("VR")
                self.to_ColabVRViewController()
            }),
        ])


        button.menu = UIMenu(title: "", children: [items])
        button.showsMenuAsPrimaryAction = true
        
    }
    
    @IBAction func ExpandButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TitleViewController") as! TitleViewController
        self.navigationController?.pushViewController(vc, animated: true)
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
    
    func to_ColabVRViewController() {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ColabVRViewController") as! ColabVRViewController
        vc.modalPresentationStyle = .fullScreen
        
        let transition = CATransition()
        transition.duration = 0.25
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromRight
        view.window!.layer.add(transition, forKey: kCATransition)
        
        self.present(vc, animated: false, completion: nil)
    }
    
    func to_ColabARViewController() {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ColabARViewController") as! ColabARViewController
        vc.modalPresentationStyle = .fullScreen
        
        let transition = CATransition()
        transition.duration = 0.25
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromRight
        view.window!.layer.add(transition, forKey: kCATransition)
        
        self.present(vc, animated: false, completion: nil)
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
