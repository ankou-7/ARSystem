//
//  CheckPictureChoiceController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/08/12.
//

import UIKit
import RealmSwift

class CheckPictureChoiceController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableview: UITableView!
    
    //どのボタンから画面遷移したかを表すID
    var seni_id = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //sectionの高さを決める
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    //sectionの数
    func numberOfSections(in tableview: UITableView) -> Int {
        //return mySections.count
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results.count
    }
    //sectionに値を設定
    func tableView(_ tableview: UITableView, titleForHeaderInSection section: Int) -> String? {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results[section].sectionName
    }
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results[section].cells.count
    }
    //cellに値を設定
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "CheckData_choice_cell", for: indexPath)
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        cell.textLabel?.text = results[indexPath.section].cells[indexPath.row].cellName
        return cell
    }
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "ChoicePictureData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ChoicePictureAllCheckController") as! ChoicePictureAllCheckController
        vc.section_num = indexPath.section
        vc.cell_num = indexPath.row
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
