//
//  NavigationDataCell2Controller.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/16.
//

import UIKit
import RealmSwift

class ChoiceDataAllCheckController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableview: UITableView!
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results[section_num].cells[cell_num].models.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "CheckData_all_cell", for: indexPath)
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        //pictureImage.image = UIImage(data: results[section_num].cells[cell_num].models[indexPath.row].worldimage!)
        let modelName = cell.viewWithTag(2) as! UILabel
        modelName.text = results[section_num].cells[cell_num].models[indexPath.row].modelname
        let dayLabel = cell.viewWithTag(3) as! UILabel
        dayLabel.text = results[section_num].cells[cell_num].models[indexPath.row].dayString
        
        return cell
    }
    
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        
        let storyboard = UIStoryboard(name: "CheckAllData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckDataController") as! CheckDataController
        vc.section_num = section_num//indexPath.section
        vc.cell_num = cell_num//indexPath.row
        vc.current_model_num = indexPath.row
        //vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
