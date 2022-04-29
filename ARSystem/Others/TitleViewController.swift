//
//  TitleViewController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/15.
//

import UIKit

class TitleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func to_MakeMapViewController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "MakeMap", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MakeMapViewController") as! MakeMapViewController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_ChoiceModelDataController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "ChoiceModelData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ChoiceModelDataController") as! ChoiceModelDataController
        //let vc = SceneViewController()
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_SceneViewController(_ sender: Any) {
//        let storyboard = UIStoryboard(name: "FeatureMatching", bundle: nil)
//        let vc = storyboard.instantiateViewController(withIdentifier: "FeatureMatchingController") as! FeatureMatchingController
        let storyboard = UIStoryboard(name: "ChoicePictureData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckPictureChoiceController") as! CheckPictureChoiceController
        //let vc = SceneViewController()
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_MapExpansionChoiceController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "MapExpansionChoice", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapExpansionChoiceController") as! MapExpansionChoiceController
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
}
