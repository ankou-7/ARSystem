//
//  MapExpansionChoiceController.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//

import UIKit

class MapExpansionChoiceController: UIViewController {

    //どのボタンから画面遷移したかを表すID
    var seni_id = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func to_MapExpansionTransmitController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "MapExpansionTransmit", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapExpansionTransmitController") as! MapExpansionTransmitController
        //vc.seni_id = seni_id
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func to_MapExpansionReceiveController(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "MapExpansionReceive", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MapExpansionReceiveController") as! MapExpansionReceiveController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
