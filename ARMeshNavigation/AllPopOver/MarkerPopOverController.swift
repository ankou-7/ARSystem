//
//  MarkerPopOverController.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2020/11/24.
//

import UIKit
import RealmSwift

class MarkerPopOverController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var closure: ((Int) -> Void)?
    @IBOutlet weak var tableView: UITableView!
    private let ObjectdataSource = ObjectModel()
    
    //let marker_name = ["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip", "start", "goal"]

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    //cellの数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return marker_name.count
        return ObjectdataSource.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    //各cellの内容
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "marker_cell", for: indexPath)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        let item = ObjectdataSource.item(row: indexPath.row)
        //pictureImage.image = UIImage(named: marker_name[indexPath.row])
        pictureImage.image = UIImage(named: item.name)

        return cell
    }
    
    //cell選択時
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //let item = ObjectdataSource.item(row: indexPath.row)
        closure?(indexPath.row)
        //closure?(item.id)
        self.dismiss(animated: true, completion: nil)
    }
    
}

