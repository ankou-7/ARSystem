//
//  NavigationDataCell1Controller.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/16.
//

import UIKit
import RealmSwift

class EditDataChoiceController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    //どのボタンから画面遷移したかを表すID
    var seni_id = Int()
    
    @IBOutlet var tableview: UITableView!
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //sectionの高さを決める
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    //sectionの数
    func numberOfSections(in tableview: UITableView) -> Int {
        return results.count
    }
    //sectionに値を設定
//    func tableView(_ tableview: UITableView, titleForHeaderInSection section: Int) -> String? {
//        let realm = try! Realm()
//        let results = realm.objects(Navi_SectionTitle.self)
//        return results[section].sectionName
//    }
    //sectionのviewを編集
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect.zero) //zeroは目一杯に広げる
        view.backgroundColor = UIColor(red: CGFloat(229) / 255.0, green: CGFloat(229) / 255.0, blue: CGFloat(229) / 255.0, alpha: 1.0)

        let label = UILabel(frame: CGRect(x:20, y:0, width: tableView.bounds.width, height: 50))
        label.text = results[section].sectionName //追加の際入力した文字を表示
        //label.textAlignment = NSTextAlignment.center //文字位置変更[.right][.center][.left]
        label.font = UIFont.boldSystemFont(ofSize: 20) //文字サイズ変更
        label.textColor =  UIColor.black //文字色変更
        view.addSubview(label)

        return view
    }
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results[section].cells.count
    }
    //cellに値を設定
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "EditData_choice_cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.section].cells[indexPath.row].cellName
        return cell
    }
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //print(indexPath)
        //ナビゲーション作成ボタンから遷移してナビゲーション編集ボタンから遷移した場合
        if seni_id == 2 {
            let storyboard = UIStoryboard(name: "EditData", bundle: nil)
            //let vc = storyboard.instantiateViewController(withIdentifier: "NavigationEditModelController") as! NavigationEditModelController
            let vc = storyboard.instantiateViewController(withIdentifier: "EditDataController") as! EditDataController
            vc.section_num = indexPath.section
            vc.cell_num = indexPath.row
            //vc.view.backgroundColor = UIColor.white
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    //セルの編集許可
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        return true
    }
    
    //スワイプしたセルを削除　※arrayNameは変数名に変更してください
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            
            //データベースから指定したセルを削除し，更新
            //documents内のファイル削除
            for i in 0..<results[indexPath.section].cells[indexPath.row].models.count {
                let objName = results[indexPath.section].cells[indexPath.row].models[i].modelname
                
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentsDirectory = paths[0]
                
                if results[indexPath.section].cells[indexPath.row].models[i].exit_mesh == 1 {
                    do {
                        let modelname: String? =  "\(documentsDirectory)/\(objName).scn"
                        try FileManager.default.removeItem(atPath: modelname!)
                    }catch {
                        print("ファイル削除失敗")
                    }
                }
                if results[indexPath.section].cells[indexPath.row].models[i].exit_point == 1 {
                    do {
                        let txtname: String? = "\(documentsDirectory)/\(objName).txt"
                        let dataname: String? = "\(documentsDirectory)/\(objName).data"
                        try FileManager.default.removeItem(atPath: txtname!)
                        try FileManager.default.removeItem(atPath: dataname!)
                    }catch {
                        print("ファイル削除失敗")
                    }
                }
            }
        
            //データベースからcell削除
            try! Realm().write {
                results[indexPath.section].cells.remove(at: indexPath.row)
            }
            //print(realm.objects(Navi_SectionTitle.self))
            
            //データベース更新
            tableView.deleteRows(at: [indexPath as IndexPath], with: UITableView.RowAnimation.automatic)
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
