//
//  SwitchPopOver.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//
import UIKit

class SwitchPopOver: UITableViewController {
    let viewModel = MenuViewModel()
    var closure: ((Int,Bool) -> Void)?
    var menu_array: [Bool] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Menu_cell", for: indexPath)
        
        let item = viewModel.item(row: indexPath.row)
        let title = cell.viewWithTag(1) as! UILabel
        title.text = item.title
        
        let switchView = UISwitch()
        if cell.accessoryView == nil {
            cell.accessoryView = switchView
        }
        //スイッチの状態
        switchView.isOn = menu_array[indexPath.row]
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
        closure?(sender.tag, sender.isOn)
    }
}
