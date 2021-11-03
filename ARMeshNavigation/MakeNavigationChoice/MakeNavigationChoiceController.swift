//
//  MakeNavigationChoice.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/18.
//

import UIKit

class MakeNavigationChoiceController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let dataSource = DataSource()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.samples.count
    }
    
    func tableView(_ table: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MakeNavigationChoice_cell", for: indexPath)
        
        let sample = dataSource.samples[(indexPath as NSIndexPath).row]
        let choiceTitleLabel = cell.viewWithTag(1) as! UILabel
        let detaiLabel = cell.viewWithTag(2) as! UILabel
        choiceTitleLabel.text = sample.title
        detaiLabel.text = sample.detail
        //cell.showSample(sample)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let sample = dataSource.samples[(indexPath as NSIndexPath).row]
//
//        navigationController?.pushViewController(sample.controller(), animated: true)
//
//        tableView.deselectRow(at: indexPath, animated: true)
        let storyboard = UIStoryboard(name: "MakeNavigation", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MakeNavigationController") as! MakeNavigationController
        //vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
        //self.navigationController?.pushViewController(vc, animated: true)
    }
}
