//
//  MakeNavigationCheckController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/16.
//

import UIKit
import RealmSwift

class CheckDataCellController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
//    //画面遷移した際のsectionとcellの番号を格納
//    var section_num = Int()
//    var cell_num = Int()
    
    @IBOutlet var tableview: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
//    //sectionの高さを決める
//    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//        return 0
//    }
//    //sectionの数
//    func numberOfSections(in tableview: UITableView) -> Int {
//        //return mySections.count
//        let realm = try! Realm()
//        let results = realm.objects(SectionTitle3.self)
//        self.section_num = results.count - 1
//        return results.count
//    }
    
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        let realm = try! Realm()
        let results = realm.objects(Navityu.self)
        return results.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "Check_data_cell", for: indexPath)
        
        let realm = try! Realm()
        let results = realm.objects(Navityu.self)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        pictureImage.image = UIImage(data: results[indexPath.row].worldimage!)
        let modelName = cell.viewWithTag(2) as! UILabel
        modelName.text = results[indexPath.row].modelname
        let dayLabel = cell.viewWithTag(3) as! UILabel
        dayLabel.text = results[indexPath.row].dayString
        
        return cell
    }
    
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath)
    }
    
    @IBAction func delete_data(_ sender: Any) {
        let realm = try! Realm()
        //let navityu_results = realm.objects(Navityu.self)
        try! realm.write {
            realm.delete(realm.objects(Navityu.self))
        }
        self.tableview.reloadData()
    }
    
}
