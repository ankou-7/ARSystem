//
//  PictureChoiceController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/08/13.
//

import UIKit
import RealmSwift

class PictureChoiceController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableview1: UITableView!
    @IBOutlet weak var tableview2: UITableView!
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var model_name1_num = Int()
    var model_name2_num = Int()
    
    var picture1_num = Int()
    var picture2_num = Int()
    
    var choice_count = 0
    
    var model_array: [Bool] = []
    var picture_array1: [Bool] = []
    var picture_array2: [Bool] = []
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    
    @IBOutlet weak var model_name1: UILabel!
    @IBOutlet weak var model_name2: UILabel!
    @IBOutlet weak var choice_picture1: UILabel!
    @IBOutlet weak var choice_picture2: UILabel!
    
    // 処理分岐用
    var tag:Int = 0
    var cellIdentifier:String = ""
    var model_num = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let index = model_array.indices.filter{model_array[$0] == true}
        picture_array1 = [Bool](repeating: false, count: results[section_num].cells[cell_num].models[index[0]].parametaNum)
        picture_array2 = [Bool](repeating: false, count: results[section_num].cells[cell_num].models[index[1]].parametaNum)
        
        model_name1.text = results[section_num].cells[cell_num].models[index[0]].modelname
        model_name2.text = results[section_num].cells[cell_num].models[index[1]].modelname
        
        model_name1_num = index[0]
        model_name2_num = index[1]
        
    }
    
    // 処理を分岐するメソッド
    func checkTableView(_ tableView: UITableView) -> Void{
        let index = model_array.indices.filter{model_array[$0] == true}
        
        if (tableView.tag == 1) {
            tag = 1
            cellIdentifier = "picture_choice_cell1"
            model_num = index[0]
        }
        else {
            tag = 2
            cellIdentifier = "picture_choice_cell2"
            model_num = index[1]
        }
    }
    
    //cellの数
    func tableView(_ tableview: UITableView, numberOfRowsInSection section: Int) -> Int {
        checkTableView(tableview)
        
        return results[section_num].cells[cell_num].models[model_num].parametaNum
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableview: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        checkTableView(tableview)
        
        let cell = tableview.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        let pictureImage = cell.viewWithTag(1) as! UIImageView
        //pictureImage.image = UIImage(data: results[section_num].cells[cell_num].models[model_num].pic[indexPath.row].pic_data!)
        
        let picture_name = cell.viewWithTag(2) as! UILabel
        //picture_name.text = results[section_num].cells[cell_num].models[model_num].pic[indexPath.row].pic_name
        
        return cell
    }
    
    //cellを選択直後に呼び出し
    func tableView(_ tableview: UITableView, didSelectRowAt indexPath: IndexPath) {
        checkTableView(tableview)
        
        choice_count += 1
        
        if tableview.tag == 1 {
            //choice_picture1.text = "選択画像：\(results[section_num].cells[cell_num].models[model_num].pic[indexPath.row].pic_name)"
            
            picture1_num = indexPath.row
        }
        else if tableview.tag == 2 {
            //choice_picture2.text = "選択画像：\(results[section_num].cells[cell_num].models[model_num].pic[indexPath.row].pic_name)"
            
            picture2_num = indexPath.row
        }
    }
    
    @IBAction func next(_ sender: UIButton) {
        if choice_count >= 2 {
            print("next")
            let storyboard = UIStoryboard(name: "Diff_PointCloud", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "Diff_PointCloudViewController") as! Diff_PointCloudViewController
            vc.section_num = section_num
            vc.cell_num = cell_num
            vc.model_name1_num = model_name1_num
            vc.model_name2_num = model_name2_num
            vc.picture1_num = picture1_num
            vc.picture2_num = picture2_num
            vc.view.backgroundColor = UIColor.white
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true, completion: nil)
        }
        else {
            Alert()
        }
    }
    
    func Alert() {
        let title = "選択画像数Error"
        let message = "画像を２つ選んでください"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [] _ in
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
