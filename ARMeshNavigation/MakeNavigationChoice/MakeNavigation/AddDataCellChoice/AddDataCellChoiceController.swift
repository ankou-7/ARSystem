//
//  AddDataCellChoiceController.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/17.
//

import UIKit
import RealmSwift
import SceneKit

class AddDataCellChoiceController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableview: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //sectionの高さ
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    //sectionの数
    func numberOfSections(in tableview: UITableView) -> Int {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results.count
    }
    //sectionのviewを編集
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)

        let view = UIView(frame: CGRect.zero) //zeroは目一杯に広げる
        view.backgroundColor = UIColor(red: CGFloat(229) / 255.0, green: CGFloat(229) / 255.0, blue: CGFloat(229) / 255.0, alpha: 1.0)

        let label = UILabel(frame: CGRect(x:20, y:0, width: tableView.bounds.width, height: 50))
        label.text = results[section].sectionName //追加の際入力した文字を表示
        //label.textAlignment = NSTextAlignment.center //文字位置変更[.right][.center][.left]
        label.font = UIFont.boldSystemFont(ofSize: 20) //文字サイズ変更
        //label.alpha = 0.7
        label.textColor =  UIColor.black //文字色変更
        view.addSubview(label)

        //self.view.frame.maxX は横幅の最大値を取得　基本的には左上が座標(0,0)
        let button = UIButton(frame: CGRect(x:self.view.frame.maxX - 60, y:0, width:50, height: 50))
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle("+", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        button.tag = section //ボタンにタグをつける
        //追加ボタンがタップされた際に画面遷移をする
        button.addTarget(self, action: #selector(add_cell_button(sender:)), for: .touchUpInside)
        view.addSubview(button)

        return view
    }
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        return results[section].cells.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    //cellに値を設定
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "Save_cell", for: indexPath)
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let cell_title_label = cell.viewWithTag(1) as! UILabel
        let cell_saveday_label = cell.viewWithTag(2) as! UILabel
        cell_title_label.text = results[indexPath.section].cells[indexPath.row].cellName
        if results[indexPath.section].cells[indexPath.row].models.count > 0 {
            cell_saveday_label.text = results[indexPath.section].cells[indexPath.row].models[0].dayString
        } else {
            cell_saveday_label.text = "データなし"
        }
        return cell
    }
    
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let title = "データ保存"
        let message = "ここに取得したデータを保存します．"
        alert(id: 2, title: title, message: message, indexPath: indexPath)
        print(indexPath)
    }
    
    func alert(id: Int, title: String, message: String, section_button_num: Int = 0, indexPath: IndexPath = [0, 0]) {
        var alertTextField: UITextField?
        let title = title
        let message = message
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if id != 2 {
            alertController.addTextField(configurationHandler: {(textField: UITextField!) in
                alertTextField = textField
            })
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            
            if let text = alertTextField?.text {
                if id == 0 { //section追加時
                    add_Section(text: text, section_num: indexPath.section)
                }
                else if id == 1 { //cell追加時
                    add_Cell(text: text, sec_num: section_button_num)
                }
            }
            
            if id == 2 { //data書き込み時
                Write_Navi_Data(section_num: indexPath.section, cell_num: indexPath.row)
                self.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func add_section_button(_ sender: UIButton) {
        let title = "新しいSectionを追加"
        let message = "Sectionの名前を記入してください。"
        alert(id: 0, title: title, message: message)
    }
    //アラートで入力したテキストをsection名として作成
    func add_Section(text: String, section_num: Int) {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        try! realm.write {
            realm.add(Navi_SectionTitle(value: ["sectionName": text]))
            results[section_num].add_section_count = results[section_num].add_section_count + 1
        }
        self.tableview.reloadData()
    }
    
    @objc func add_cell_button(sender:UIButton) {
        let title = "新しい場所を追加"
        let message = "場所の名前を記入してください。"
        alert(id: 1, title: title, message: message, section_button_num: sender.tag)
    }
    
    //指定したsectionに新しいcellを作成
    func add_Cell(text: String, sec_num: Int) {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        try! realm.write {
            results[sec_num].cells.append(Navi_CellTitle(value: ["cellName": text]))
        }
        self.tableview.reloadData()
    }
    
    func Write_Navi_Data(section_num: Int, cell_num: Int) {
        let realm = try! Realm()
        let navityu_results = realm.objects(Navityu.self)
        let data_parameta_results = realm.objects(Data_parameta.self)
        let results = realm.objects(Navi_SectionTitle.self)
        
        try! realm.write {
            results[section_num].add_cell_count = results[section_num].add_cell_count + 1
        }
        
        for i in 0...navityu_results.count-1 {
            let objName = "NaviModel\(results[section_num].add_section_count)\(results[section_num].add_cell_count)-\(i)"
            
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0]
            
            if navityu_results[i].exit_mesh == 1 {
                do {
                    print("mesh書き込み")
                    let old_modelname: String? = "\(documentsDirectory)/\(navityu_results[i].modelname).scn"
                    let new_modelname: String? =  "\(documentsDirectory)/\(objName).scn"
                    try FileManager.default.moveItem(atPath: old_modelname!, toPath: new_modelname!)
                } catch {
                    fatalError()
                }
            }
            if navityu_results[i].exit_point == 1 {
                do {
                    print("point書き込み")
                    let old_txtname: String? = "\(documentsDirectory)/\(navityu_results[i].modelname).txt"
                    let new_txtname: String? =  "\(documentsDirectory)/\(objName).txt"
                    
                    let old_mesh_modelname: String? = "\(documentsDirectory)/\(navityu_results[i].modelname).data"
                    let new_mesh_modelname: String? =  "\(documentsDirectory)/\(objName).data"
                    try FileManager.default.moveItem(atPath: old_txtname!, toPath: new_txtname!)
                    try FileManager.default.moveItem(atPath: old_mesh_modelname!, toPath: new_mesh_modelname!)
                } catch {
                    fatalError()
                }
            }
            
            try! realm.write {
                results[section_num].cells[cell_num].models.append(Navi_Modelname(
                                                                    value: ["modelname": objName,
                                                                            "dayString": navityu_results[i].dayString,
                                                                            "worlddata": navityu_results[i].worlddata!,
                                                                            "worldimage": navityu_results[i].worldimage!,
                                                                            "exit_mesh": navityu_results[i].exit_mesh,
                                                                            "exit_point": navityu_results[i].exit_point]))
                
                if navityu_results[i].usdz.count > 0 {
                    for j in 0...navityu_results[i].usdz.count-1 {
                        results[section_num].cells[cell_num].models[i].usdz.append(Navi_Usdz_ModelInfo(value: ["usdz_name": navityu_results[i].usdz[j].usdz_name, "usdz_num": navityu_results[i].usdz[j].usdz_num, "usdz_posi_x": navityu_results[i].usdz[j].usdz_posi_x, "usdz_posi_y": navityu_results[i].usdz[j].usdz_posi_y, "usdz_posi_z": navityu_results[i].usdz[j].usdz_posi_z]))
                    }
                    print(results[section_num].cells[cell_num].models[i].usdz)
                }
                
                if navityu_results[i].exit_mesh == 1 {
                    for j in 0...data_parameta_results[i].mesh_anchor.count-1 {
                        results[section_num].cells[cell_num].models[i].mesh_anchor.append(
                            anchor_data(value: ["mesh": data_parameta_results[i].mesh_anchor[j].mesh]))
                    }
                }
                
                if navityu_results[i].exit_parameta == 1 {
                    if data_parameta_results[i].pic.count > 0 {
                        for j in 0...data_parameta_results[i].pic.count-1 {
                            results[section_num].cells[cell_num].models[i].pic.append(
                                pic_data(value: ["pic_name": data_parameta_results[i].pic[j].pic_name,
                                                 "pic_data": data_parameta_results[i].pic[j].pic_data]))
                        }
                    }
                    
                    if data_parameta_results[i].json.count > 0 {
                        for j in 0...data_parameta_results[i].json.count-1 {
                            results[section_num].cells[cell_num].models[i].json.append(
                                json_data(value: ["json_name": data_parameta_results[i].json[j].json_name,
                                                  "json_data": data_parameta_results[i].json[j].json_data]))
                        }
                    }
                }
                
            }
            
        }

        try! realm.write {
            realm.delete(realm.objects(Navityu.self))
        }
        
        print(realm.objects(Navi_SectionTitle.self))
        
    }
    
    // 全データ削除
    func deleteData(_ sender: Any) {
        let realm = try! Realm()
        try! realm.write {
            realm.delete(realm.objects(Navi_SectionTitle.self))
        }
        self.tableview.reloadData()
        print(realm.objects(Navi_SectionTitle.self))
    }
    
    //セルごとに編集モードでスワイプ削除を実行できるようにする
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        print(indexPath)
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        try! realm.write {
            results[indexPath.section].cells.remove(at: indexPath.row)
        }
        self.tableview.reloadData()
        print(realm.objects(Navi_SectionTitle.self))
    }
}
