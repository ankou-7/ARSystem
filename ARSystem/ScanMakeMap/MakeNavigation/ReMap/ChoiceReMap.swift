//
//  ChiceReMap.swift
//  ARSystem
//
//  Created by yasue kouki on 2022/05/25.
//

import UIKit
import RealmSwift

class ChoiceReMap: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    //let results = try! Realm().objects(Navi_SectionTitle.self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //print(results)
    }
    
    //sectionの高さを決める
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        return 50
//    }
    //sectionの数
    func numberOfSections(in tableview: UITableView) -> Int {
        return 1//results.count
    }
//    //sectionに値を設定
////    func tableView(_ tableview: UITableView, titleForHeaderInSection section: Int) -> String? {
////        let realm = try! Realm()
////        let results = realm.objects(Navi_SectionTitle.self)
////        return results[section].sectionName
////    }
//    //sectionのviewを編集
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let view = UIView(frame: CGRect.zero) //zeroは目一杯に広げる
//        view.backgroundColor = UIColor(red: CGFloat(229) / 255.0, green: CGFloat(229) / 255.0, blue: CGFloat(229) / 255.0, alpha: 1.0)
//
//        let label = UILabel(frame: CGRect(x:20, y:0, width: tableView.bounds.width, height: 50))
//        label.text = results[section].sectionName //追加の際入力した文字を表示
//        //label.textAlignment = NSTextAlignment.center //文字位置変更[.right][.center][.left]
//        label.font = UIFont.boldSystemFont(ofSize: 20) //文字サイズ変更
//        label.textColor =  UIColor.black //文字色変更
//        view.addSubview(label)
//
//        return view
//    }
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3//results[section].cells.count
    }
    
    //cellに値を設定
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "remap_cell", for: indexPath)
//        cell.textLabel?.text = "aaaa"//results[indexPath.section].cells[indexPath.row].cellName
//        cell.detailTextLabel?.text = "aaaa"//results[indexPath.section].cells[indexPath.row].models[0].dayString
        return cell
    }
    //cellを選択直後に呼び出し
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}


//extension ChoiceReMap {
//    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
//        super.dismiss(animated: flag, completion: completion)
//        guard let presentationController = presentationController else {
//            return
//        }
//        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
//    }
//}
