//
//  PopOverController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/09.
//

import UIKit
import RealmSwift

class
PopOverController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableview: UITableView!
    var closure: ((Int,Int) -> Void)?
    
    let array = ["1", "10", "100", "1000", "10000", "100000"]
    let section_array = ["オブジェクト",
                        "ナビゲーション用"]
    let url_name = [["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip"],
    ["arrow100"]]
//    let url_name = [["toy_drummer", "toy_drummer"],
//                    ["toy_robot_vintage", "toy_robot_vintage"],
//                    ["chair_swan", "chair_swan"],
//                    ["toy_biplane", "toy_biplane"],
//                    ["tv_retro", "tv_retro"],
//                    ["flower_tulip", "flower_tulip"]]
    

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //sectionの高さを決める
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section_array[section]
    }
    
    //sectionの数
    func numberOfSections(in tableview: UITableView) -> Int {
        return section_array.count
    }

    //cellの数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return url_name[section].count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }

    //各cellの内容
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell_name", for: indexPath)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        pictureImage.image = UIImage(named: url_name[indexPath.section][indexPath.row])

//        DispatchQueue.main.async() { [self] in
//            cell.setCell3(image: UIImage(named: url_name[indexPath.row][0])!)
//        }

        return cell
    }
    
    //cell選択時
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //print(array[indexPath.row])
        closure?(indexPath.section,indexPath.row) //EditModelControllerに値渡し
        //closure2?(url_name[indexPath.row][0])
        self.dismiss(animated: true, completion: nil)
    }
    
}
