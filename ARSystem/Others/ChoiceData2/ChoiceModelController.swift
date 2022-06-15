//
//  ChoiceModelController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/18.
//

import UIKit
import RealmSwift

class ChoiceModelController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var model_name1_num = Int()
    var model_name2_num = Int()
    
    //選択したモデルのインデックスをtrueとし，それ以外をfalseにした配列
    var model_array: [Bool] = []
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        model_array = [Bool](repeating: false, count: results[section_num].cells[cell_num].models.count)
        
        tableView.allowsSelection = false
    }
    
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results[section_num].cells[cell_num].models.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "CheckModelData_all_cell", for: indexPath)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        //pictureImage.image = UIImage(data: results[section_num].cells[cell_num].models[indexPath.row].worldimage!)
        let modelName = cell.viewWithTag(2) as! UILabel
        modelName.text = results[section_num].cells[cell_num].models[indexPath.row].modelname
        let dayLabel = cell.viewWithTag(3) as! UILabel
        dayLabel.text = results[section_num].cells[cell_num].models[indexPath.row].dayString
        
        let picture_num_Label = cell.viewWithTag(4) as! UILabel
        picture_num_Label.text = "RGB画像数：\(results[section_num].cells[cell_num].models[indexPath.row].parametaNum)"
        
        let parameta_num_Label = cell.viewWithTag(5) as! UILabel
        parameta_num_Label.text = "jsonファイル数：\(results[section_num].cells[cell_num].models[indexPath.row].parametaNum)"
        
        let switchView = UISwitch()
        if cell.accessoryView == nil {
            cell.accessoryView = switchView
        }
        //スイッチの状態
        //switchView.isOn = menu_array[indexPath.row]
        //タグの値にindexPath.rowを入れる。
        switchView.tag = indexPath.row
        //スイッチが押されたときの動作
        switchView.addTarget(self, action: #selector(fundlSwitch(_:)), for: UIControl.Event.valueChanged)
        
        return cell
    }
    
    //スイッチのテーブルが変更されたときに呼ばれる
    @objc func fundlSwitch(_ sender: UISwitch) {
        print(sender.tag)
        print(sender.isOn)
        //closure?(sender.tag, sender.isOn)
        model_array[sender.tag] = sender.isOn
        print(model_array)
    }
    
    @IBAction func next(_ sender: UIButton) {
        let index = model_array.indices.filter{model_array[$0] == true}
        if index.count == 2 {
            print("next")
            let storyboard = UIStoryboard(name: "Diff_PointCloud2", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "Diff_PointCloud2Controller") as! Diff_PointCloud2Controller
            vc.section_num = section_num
            vc.cell_num = cell_num
            vc.model_array = model_array
            vc.model_name1_num = index[0]
            vc.model_name2_num = index[1]
            vc.view.backgroundColor = UIColor.white
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        } else {
            Alert()
        }
    }
    
    func Alert() {
        let title = "選択モデル数Error"
        let message = "モデルを２つ選んでください"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [] _ in
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

