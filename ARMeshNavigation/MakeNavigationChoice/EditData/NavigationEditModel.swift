//
//  NavigationEditModel.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/17.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class NavigationEditModelController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数
    
    @IBOutlet var sceneView: SCNView!
    let scene = SCNScene()
    
    var lastGestureScale: Float = 0.0
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var left_arrowImage: UIImageView!
    @IBOutlet weak var right_arrowImage: UIImageView!
    
    @IBOutlet weak var gobutton: UIButton!
    @IBOutlet weak var backbutton: UIButton!
    @IBOutlet weak var rightbutton: UIButton!
    @IBOutlet weak var leftbutton: UIButton!
    @IBOutlet weak var upbutton: UIButton!
    @IBOutlet weak var downbutton: UIButton!
    @IBOutlet weak var rightroll: UIButton!
    @IBOutlet weak var leftroll: UIButton!
    @IBOutlet weak var downroll: UIButton!
    @IBOutlet weak var uproll: UIButton!
    
    @IBOutlet weak var movelabel1: UILabel!
    @IBOutlet weak var movelabel2: UILabel!
    @IBOutlet weak var movelabel3: UILabel!
    
    @IBOutlet weak var dataSizelabel: UILabel!
    
    @IBOutlet weak var picture_button: UIButton!
    @IBOutlet weak var video_button: UIButton!
    @IBOutlet weak var picture_button_label: UILabel!
    @IBOutlet weak var video_button_label: UILabel!
    @IBOutlet weak var picture_saveButton: UIButton!
    @IBOutlet weak var picture_deleteButton: UIButton!
    
    @IBOutlet weak var object_button: UIButton! //オブジェクト配置用のボタン
    @IBOutlet weak var arrow_button: UIButton! //矢印オブジェクト配置用のボタン
    @IBOutlet weak var object_hyouji_view: UIImageView!
    @IBOutlet weak var object_saveButton: UIButton!
    @IBOutlet weak var object_deleteButton: UIButton!
    
    var flash_button_count = 0
    
    var plus_flag = false
    var model_posi: SCNVector3!
    let url_name = [["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip"],
    ["arrow", "arrow2", "arrow3"]]
    var usdz_num: [Int] = [-100, -100]
    var usdzInfo: [(id_name: String,
                    usdz_name: String,
                    usdz_num: Int,
                    usdz_posi_x: Float,
                    usdz_posi_y: Float,
                    usdz_posi_z: Float)] = []
    
    var arrowInfo: [(arrow_name: String,
                    arrow_posi_x: Float,
                    arrow_posi_y: Float,
                    arrow_posi_z: Float,
                    arrow_scale_x: Float,
                    arrow_scale_y: Float,
                    arrow_scale_z: Float,
                    arrow_euler_x: Float,
                    arrow_euler_y: Float,
                    arrow_euler_z: Float)] = []
    
    var pictureInfo: [(pic_name: String,
                       pic_data: Data,
                       pic_posi_x: Float,
                       pic_posi_y: Float,
                       pic_posi_z: Float,
                       pic_scale_x: Float,
                       pic_scale_y: Float,
                       pic_scale_z: Float,
                       pic_euler_x: Float,
                       pic_euler_y: Float,
                       pic_euler_z: Float)] = []
    
    var moveNode_name = ""
    var arrowNode_name = ""
    var pictureNode_name = ""
    
    var all_pic = SCNNode()
    var picturePlane = SCNGeometry()
//    var pictureNode = SCNNode()
    
    var button_flag = false
    var current_kakudo_y: Float = 0.0
    var current_kakudo_x: Float = 0.0
    var current_image: UIImage!
    
    var current_mode_num = 0 //現在のモードの番号を格納
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let screenWidth:CGFloat = view.frame.size.width
//        let screenHeight:CGFloat = view.frame.size.height
        
        //MARK: - UIの配置
        
        //sceneView.backgroundColor = UIColor.lightGray //.lightGray
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        sceneView.scene = scene
        //self.view.addSubview(self.sceneView)
        
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        
        //MARK: -操作UI
        
        gobutton.addTarget(self, action: #selector(goButton), for: .touchDown)
        gobutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        gobutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)
        
        backbutton.addTarget(self, action: #selector(backButton), for: .touchDown)
        backbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        backbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)
        
        rightbutton.addTarget(self, action: #selector(rightButton), for: .touchDown)
        rightbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        rightbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)

        leftbutton.addTarget(self, action: #selector(leftButton), for: .touchDown)
        leftbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        leftbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)

        upbutton.addTarget(self, action: #selector(upButton), for: .touchDown)
        upbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        upbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)

        downbutton.addTarget(self, action: #selector(downButton), for: .touchDown)
        downbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        downbutton.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)

        rightroll.addTarget(self, action: #selector(rightRollButton), for: .touchDown)
        rightroll.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        rightroll.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)
        self.view.addSubview(rightroll)
        

        leftroll.addTarget(self, action: #selector(leftRollButton), for: .touchDown)
        leftroll.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        leftroll.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)
        
        downroll.addTarget(self, action: #selector(downrollButton), for: .touchDown)
        downroll.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        downroll.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)
        
        uproll.addTarget(self, action: #selector(uprollButton), for: .touchDown)
        uproll.addTarget(self, action: #selector(releaseButton), for: .touchUpInside)
        uproll.addTarget(self, action: #selector(releaseButton), for: .touchUpOutside)

//        rightbutton.isHidden = true
//        leftbutton.isHidden = true
//        gobutton.isHidden = true
//        backbutton.isHidden = true
//        upbutton.isHidden = true
//        downbutton.isHidden = true
//        rightroll.isHidden = true
//        leftroll.isHidden = true
//
//        movelabel1.isHidden = true
//        movelabel2.isHidden = true
//        movelabel3.isHidden = true
        
        object_button.isHidden = true
        arrow_button.isHidden = true
        object_hyouji_view.isHidden = true
        object_saveButton.isHidden = true
        object_deleteButton.isHidden = true
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        let cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.5)
        scene.rootNode.addChildNode(cameraNode)
        
//        //全体を均一な明るさで照らすライトの設定
//        let ambientLightNode = SCNNode()
//        ambientLightNode.light = SCNLight()
//        ambientLightNode.light!.type = .ambient //.omni
//        ambientLightNode.light!.color = UIColor.darkGray //ライトの色を設定
//        scene.rootNode.addChildNode(ambientLightNode)
//
//        let lightNode = SCNNode()
//        lightNode.light = SCNLight()
//        lightNode.light?.type = .directional
//        lightNode.light?.spotOuterAngle = 90
//        lightNode.light?.color = UIColor.white
//        lightNode.light?.castsShadow = true
//        lightNode.position = SCNVector3(x: 0, y: 0.5, z: 0.1)
//        scene.rootNode.addChildNode(lightNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        //lightNode.position = SCNVector3(x: 0, y: 10, z: -10)
        scene.rootNode.addChildNode(lightNode)
        
//        let sphere:SCNGeometry = SCNSphere(radius: 0.1)
//        sphere.firstMaterial?.diffuse.contents = UIColor.yellow
//        let geometryNode = SCNNode(geometry: sphere)
//        geometryNode.position = SCNVector3(0,0,0)
//        scene.rootNode.addChildNode(geometryNode)
        
        sceneView.delegate = self //delegateのセット
        
    }
    
    //遷移時に指定したセル番号から.objファイルをロード
    override func viewDidAppear(_ animated: Bool) {
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        
        //self.dataSizelabel.text = "byte:\( results[section_num].cells[cell_num].models[current_model_num].worlddata!)"
        //self.dataSizelabel.text = "byte:\(UserDefaults.standard.data(forKey: modelname)!)"
        
        self.database_model_num = results[section_num].cells[cell_num].models.count
        self.nameLabel.text = modelname
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let filename = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
            if let referenceNode = SCNReferenceNode(url: filename) {
                referenceNode.load()
                referenceNode.name = "obj"
                self.scene.rootNode.addChildNode(referenceNode)
            }
            else {print("失敗")}
            
        }
        
        //re_haiti() //保存してある画像データから背景オブジェクトを復元
        object_re_haiti()
    }
    
    @IBAction func mode_change(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            current_mode_num = sender.selectedSegmentIndex
            
            picture_button.isHidden = false
            video_button.isHidden = false
            //picture_button_label.isHidden = false
            //video_button_label.isHidden = false
            picture_saveButton.isHidden = false
            picture_deleteButton.isHidden = false
            
            object_button.isHidden = true
            arrow_button.isHidden = true
            object_hyouji_view.isHidden = true
            object_saveButton.isHidden = true
            object_deleteButton.isHidden = true
            video_button_label.text = "保存動画から取得"
            picture_button_label.text = "新しく画像を取得"
            
        case 1:
            current_mode_num = sender.selectedSegmentIndex
            
            picture_button.isHidden = true
            video_button.isHidden = true
            //picture_button_label.isHidden = true
            //video_button_label.isHidden = true
            picture_saveButton.isHidden = true
            picture_deleteButton.isHidden = true
            
            object_button.isHidden = false
            arrow_button.isHidden = false
            object_hyouji_view.isHidden = false
            object_saveButton.isHidden = false
            object_deleteButton.isHidden = false
            video_button_label.text = "オブジェクトを配置"
            picture_button_label.text = "ナビゲーションオブジェクトを配置"
            
        default:
            print("該当なし")
        }
    }
    
    //MARK: -オブジェクト配置用
    //画面タップ時に呼び出し
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        //オブジェクト配置用の時
        if current_mode_num == 1 {
            if plus_flag == false {
                no_model_senntaku_alert()
            }
            else if plus_flag == true {
            
                let location = sender.location(in: sceneView)
                let hitResults = sceneView.hitTest(location, options: [:])
                if !hitResults.isEmpty {
                    let posi = hitResults[0].worldCoordinates
                    self.model_posi = posi
                    print(posi)
                    
                    if usdz_num[0] == 0 {
                        guard let url = Bundle.main.url(forResource: "art.scnassets/"+url_name[usdz_num[0]][usdz_num[1]], withExtension: "usdz") else { return }
                        let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
                        let node = scene1.rootNode.childNode(withName: url_name[usdz_num[0]][usdz_num[1]], recursively: true)
                        node?.scale = SCNVector3(0.01, 0.01, 0.01)
                        node?.position = posi
                        node!.name = "usdz" + String(usdzInfo.count)
                        //sceneView.scene!.rootNode.addChildNode(node!)
                        scene.rootNode.addChildNode(node!)
                        
                        let tuple_youso = (node!.name!, url_name[usdz_num[0]][usdz_num[1]], usdz_num[1], posi.x, posi.y, posi.z)
                        usdzInfo.append(tuple_youso)
                        print(usdzInfo)
                        
                        flash_button_count += 1
                        if flash_button_count == 1 {
                            UIView.animate(withDuration: 2.0,
                                           delay: 0.0,
                                           options: [.allowUserInteraction, .repeat],
                                           animations: {
                                            self.object_saveButton.alpha = 0.011
                                            self.object_saveButton.setTitleColor(UIColor.red, for: .normal)
                                           }) { (_) in
                                self.object_saveButton.alpha = 1.0
                                self.object_saveButton.setTitleColor(UIColor.blue, for: .normal)
                            }
                        }
                    }
                    else {
                        not_navi_alert()
                    }
                    
                    let thita = atan(-(posi.z-0)/(posi.x-0))
                    var kakudo = (thita*180)/Float.pi
                    if posi.x < 0 {
                        kakudo += 90
                    }
                    if posi.x > 0 {
                        kakudo -= 90 - 360
                    }
                    
                }
            }
        }
    }
    
    @IBAction func arrow_object_haiti(_ sender: UIButton) {
        flash_button_count += 1
        if flash_button_count == 1 {
            UIView.animate(withDuration: 2.0,
                           delay: 0.0,
                           options: [.allowUserInteraction, .repeat],
                           animations: {
                            self.object_saveButton.alpha = 0.011
                            self.object_saveButton.setTitleColor(UIColor.red, for: .normal)
                           }) { (_) in
                self.object_saveButton.alpha = 1.0
                self.object_saveButton.setTitleColor(UIColor.blue, for: .normal)
            }
        }
        
        if arrowInfo.last?.0 != arrowNode_name {
            if let node = sceneView.scene!.rootNode.childNode(withName: arrowNode_name, recursively: false) {
                let scale = node.scale
                let posi = node.position
                let euler = node.eulerAngles
                let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
                arrowInfo.append(tuple_youso)
            }
        }
        
        let scene1 = SCNScene(named: "art.scnassets/try.scn")
        let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
        node.position = SCNVector3(0, 0, 0)
        node.scale = SCNVector3(0.3, 0.3, 0.3)
        node.eulerAngles = .init(-Float.pi/2, 0, -Float.pi/2)
        node.opacity = 0.9
        node.name = "arrow" + String(arrowInfo.count)
        arrowNode_name = node.name!
        scene.rootNode.addChildNode(node)
        
    }
    
    
    @IBAction func object_save(_ sender: UIButton) {
        flash_button_count = 0
        self.object_saveButton.alpha = 1.0
        self.object_saveButton.setTitleColor(UIColor.blue, for: .normal)
        self.object_saveButton.layer.removeAllAnimations()
        
        print("object save")
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
//        //データ消去
//        try! realm.write {
//            realm.delete(results[section_num].cells[cell_num].models[current_model_num].usdz)
//        }
        //データ書き込み
//        for usdz in usdzInfo {
//            try! realm.write {
//                results[section_num].cells[cell_num].models[current_model_num].usdz.append(Navi_Usdz_ModelInfo(value:
//                                                                                                                ["usdz_name": usdz.usdz_name,
//                                                                                                                 "usdz_num": usdz.usdz_num,
//                                                                                                                 "usdz_posi_x": usdz.usdz_posi_x,
//                                                                                                                 "usdz_posi_y": usdz.usdz_posi_y,
//                                                                                                                 "usdz_posi_z": usdz.usdz_posi_z]))
//            }
//        }
        
        print(arrowInfo.last?.0 as Any)
        if arrowInfo.last?.0 != arrowNode_name {
            if let node = sceneView.scene!.rootNode.childNode(withName: arrowNode_name, recursively: false) {
                let scale = node.scale
                let posi = node.position
                let euler = node.eulerAngles
                let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
                arrowInfo.append(tuple_youso)
            }
        }
//        for arrow in arrowInfo {
//            try! realm.write {
//                results[section_num].cells[cell_num].models[current_model_num].usdz.append(Navi_Usdz_ModelInfo(value:
//                                                                                                                ["usdz_name": arrow.arrow_name, "usdz_num" : -100,
//                                                                                                                 "usdz_posi_x": arrow.arrow_posi_x, "usdz_posi_y": arrow.arrow_posi_y, "usdz_posi_z": arrow.arrow_posi_z,
//                                                                                                                 "usdz_scale_x": arrow.arrow_scale_x, "usdz_scale_y": arrow.arrow_scale_y, "usdz_scale_z": arrow.arrow_scale_z,
//                                                                                                                 "usdz_euler_x": arrow.arrow_euler_x, "usdz_euler_y": arrow.arrow_euler_y, "usdz_euler_z": arrow.arrow_euler_z]))
//            }
//        }
        
//        usdzInfo = []
//        arrowInfo = []
    }
    
    @IBAction func object_delete(_ sender: UIButton) {
        print("object_delete")
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        //データ消去
//        try! realm.write {
//            realm.delete(results[section_num].cells[cell_num].models[current_model_num].usdz)
//        }
        
        if usdzInfo.count > 0 {
            for n in usdzInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
        }
        
        //配列に格納した分の情報と現在表示しているarrowオブジェクトを削除
        if arrowInfo.count > 0 {
            for n in arrowInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
        }
        if let node = sceneView.scene!.rootNode.childNode(withName: arrowNode_name, recursively: false) {
            node.removeFromParentNode()
        }
        
        //print(results[section_num].cells[cell_num].models[current_model_num].usdz)
    }
    
    func object_re_haiti() {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
//        print(results[section_num].cells[cell_num].models[current_model_num].usdz)
//        print(results[section_num].cells[cell_num].models[current_model_num].usdz.count)
        usdzInfo = []
        arrowInfo = []
        
//        for usdz in results[section_num].cells[cell_num].models[current_model_num].usdz {
//            if usdz.usdz_num >= 0 {
//                guard let url = Bundle.main.url(forResource: "art.scnassets/"+usdz.usdz_name, withExtension: "usdz") else { return }
//                let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
//                let node = scene1.rootNode.childNode(withName: usdz.usdz_name, recursively: true)
//                node?.scale = SCNVector3(0.01, 0.01, 0.01)
//                node?.position = SCNVector3(usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
//                node!.name = "usdz" + String(usdzInfo.count)
//                //sceneView.scene!.rootNode.addChildNode(node!)
//                scene.rootNode.addChildNode(node!)
//                
//                let tuple_youso = (node!.name!, usdz.usdz_name, usdz.usdz_num, usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
//                usdzInfo.append(tuple_youso)
//            }
//            else if usdz.usdz_num == -100 {
//                let scene1 = SCNScene(named: "art.scnassets/try.scn")
//                let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
//                node.position = SCNVector3(usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
//                node.scale = SCNVector3(usdz.usdz_scale_x, usdz.usdz_scale_y, usdz.usdz_scale_z)
//                node.eulerAngles = .init(usdz.usdz_euler_x, usdz.usdz_euler_y, usdz.usdz_euler_z)
//                node.opacity = 0.9
//                node.name = "arrow" + String(arrowInfo.count)
//                //arrowNode_name = node.name!
//                scene.rootNode.addChildNode(node)
//                
//                let tuple_youso = (node.name!, usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z, usdz.usdz_scale_x, usdz.usdz_scale_y, usdz.usdz_scale_z, usdz.usdz_euler_x, usdz.usdz_euler_y, usdz.usdz_euler_z)
//                arrowInfo.append(tuple_youso)
//            }
//            //arrowNode_name = ""
//        }
    }
    
    //オブジェクト選択画面をポップアップ表示
    @IBAction func object_plus(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "PopOver", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "PopOverController") as! PopOverController
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 100, height: 400)
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = {(sec_num: Int, cell_num: Int) -> Void in
            self.usdz_num[0] = sec_num
            self.usdz_num[1] = cell_num
            //self.model_numLabel.text = String(num)
            self.object_hyouji_view.image = UIImage(named: self.url_name[sec_num][cell_num])
        }
        
        if plus_flag == false {
            self.plus_flag = true
        }
        
        present(contentVC, animated: true, completion: nil)
    }
    
    func no_model_senntaku_alert() {
        let title = "配置オブジェクト未選択"
        let message = "オブジェクトを指定してください。"
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            //okが押されたら
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func not_navi_alert() {
        let title = "オブジェクト使用不可"
        let message = "ここでは使用できないオブジェクトです。\n選択し直してください。"
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        //alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            //okが押されたら
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    
    //MARK: -背景画像配置用
    @IBAction func picturedata_delete(_ sender: Any) {
        print("picture_delete")
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        try! realm.write {
            //realm.delete(realm.objects(.self))
            realm.delete(results[section_num].cells[cell_num].models[current_model_num].pic)
        }
        
        for n in pictureInfo {
            let name = n.0
            if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                node.removeFromParentNode()
            }
        }
        if let node = sceneView.scene!.rootNode.childNode(withName: pictureNode_name, recursively: false) {
            node.removeFromParentNode()
        }
        
//        if let node = sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
//            node.removeFromParentNode()
//            all_pic = SCNNode()
//        }
        print(results[section_num].cells[cell_num].models[current_model_num].pic)
    }
    
    @IBAction func take_photo(_ sender: Any) {
//        if pictureNode_name.count > 0 {
//            if let node = sceneView.scene!.rootNode.childNode(withName: pictureNode_name, recursively: false) {
//                let scale = node.scale
//                let posi = node.position
//                let euler = node.eulerAngles
//                let picturedata = current_image.jpegData(compressionQuality: 0.5)//toJPEGData()
//                let tuple_youso = (node.name!, picturedata, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
//                pictureInfo.append(tuple_youso)
//            }
//        }
            
        // カメラが利用可能かチェック
        if UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerController.SourceType.camera){
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = true
            picker.delegate = self
            // UIImagePickerController カメラを起動する
            present(picker, animated: true, completion: nil)
        }
        else{
            print("error")
        }
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        print(results[section_num].cells[cell_num].models[current_model_num].pic)
        
        picturePlane = SCNPlane(width: 0.5, height: 0.5)
        //picturePlane.firstMaterial?.transparency = 0.5
        let node = SCNNode(geometry: picturePlane)
        node.position = SCNVector3(0,0,-0.2)
        node.opacity = 0.5
        //pictureNode_name = "pictureNode_name\(String(results[section_num].cells[cell_num].models[current_model_num].pic.count))"
        node.name = "picture" + String(pictureInfo.count)
        pictureNode_name = node.name!
        //print(node.name)
        print(pictureNode_name)
        scene.rootNode.addChildNode(node)
        
    }
    
    /// シャッターボタンを押下した際、確認メニューに切り替わる
    /// - Parameters:
    ///   - picker: ピッカー
    ///   - info: 写真情報
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        //let image = info[.originalImage] as! UIImage
        if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            //UIImageWriteToSavedPhotosAlbum(editedImage, self, nil, nil) //"写真を使用"を押下した際、写真アプリに保存する
            self.picturePlane.firstMaterial?.diffuse.contents = editedImage
            self.current_image = editedImage
        }
//        else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
//        }

        // UIImagePickerController カメラが閉じる
        self.dismiss(animated: true, completion: nil)
        
    }
    
    //現在のpicture_modelを保存
    @IBAction func save_button(_ sender: Any) {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        
        //データ消去
        try! realm.write {
            realm.delete(results[section_num].cells[cell_num].models[current_model_num].pic)
        }
        
//        if pictureInfo.last?.pic_name != pictureNode_name {
//            if let node = sceneView.scene!.rootNode.childNode(withName: pictureNode_name, recursively: false) {
//                let scale = node.scale
//                let posi = node.position
//                let euler = node.eulerAngles
//                let picturedata = current_image.toJPEGData()
//                let tuple_youso = (node.name!, picturedata, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
//                pictureInfo.append(tuple_youso)
//            }
//        }
        
//        for pic in pictureInfo {
//            try! realm.write {
//                results[section_num].cells[cell_num].models[current_model_num].pic.append(Navi_PicturePlane_Info(value:
//                                                                                                                    ["picturedata": pic.pic_data,
//                                                                                                                     "scale_x": pic.pic_scale_x,
//                                                                                                                     "scale_y": pic.pic_scale_y,
//                                                                                                                     "scale_z": pic.pic_scale_z,
//                                                                                                                     "posi_x": pic.pic_posi_x,
//                                                                                                                 "posi_y": pic.pic_posi_y,
//                                                                                                                 "posi_z": pic.pic_posi_z,
//                                                                                                                 "euler_x": pic.pic_euler_x,
//                                                                                                                 "euler_y": pic.pic_euler_y,
//                                                                                                                 "euler_z": pic.pic_euler_z]))
//            }
//        }
    }
    
//    @objc func re_haiti() {
//        let realm = try! Realm()
//        let results = realm.objects(Navi_SectionTitle.self)
//        print(results[section_num].cells[cell_num].models[current_model_num].pic)
//        for pic in results[section_num].cells[cell_num].models[current_model_num].pic {
//            picturePlane = SCNPlane(width: 0.5, height: 0.5)
//            picturePlane.firstMaterial?.diffuse.contents = pic.picturedata.toImage()
//            //picturePlane.firstMaterial?.transparency = 0.5
//            let node = SCNNode(geometry: picturePlane)
//            node.position = SCNVector3(pic.posi_x, pic.posi_y, pic.posi_z)
//            node.eulerAngles = SCNVector3(pic.euler_x, pic.euler_y, pic.euler_z)
//            node.scale = SCNVector3(pic.scale_x, pic.scale_y, pic.scale_z)
//            node.opacity = 0.5
//            node.name = "picture" + String(pictureInfo.count)
//            //scene.rootNode.addChildNode(node)
//            all_pic.addChildNode(node)
//
//            let tuple_youso = (node.name!, pic.picturedata!, pic.posi_x, pic.posi_y, pic.posi_z, pic.scale_x, pic.scale_y, pic.scale_z, pic.euler_x, pic.euler_y, pic.euler_z)
//            pictureInfo.append(tuple_youso)
//        }
//        //pictureNode_name = ""
//
//        all_pic.name = "all_pic"
//        all_pic.opacity = 0.5
//        scene.rootNode.addChildNode(all_pic)
//    }
    
    @IBAction func to_VideoEditController(_ sender: Any) {
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let vc = storyboard.instantiateViewController(withIdentifier: "VideoEditController") as! VideoEditController
//        vc.section_num = section_num
//        vc.cell_num = cell_num
//        vc.current_model_num = current_model_num
//        vc.closure = { [self](image: UIImage) -> Void in
//
//            if pictureNode_name.count > 0 {
//                if let node = sceneView.scene!.rootNode.childNode(withName: pictureNode_name, recursively: false) {
//                    let scale = node.scale
//                    let posi = node.position
//                    let euler = node.eulerAngles
//                    let picturedata = current_image.toJPEGData()
//                    let tuple_youso = (node.name!, picturedata, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
//                    pictureInfo.append(tuple_youso)
//                }
//            }
//
//            picturePlane = SCNPlane(width: 0.5, height: 0.5)
//            picturePlane.firstMaterial?.diffuse.contents = image
//            self.current_image = image
//            let node = SCNNode(geometry: picturePlane)
//            node.position = SCNVector3(0,0,-0.2)
//            node.opacity = 0.5
//            node.name = "picture\(String(pictureInfo.count))"
//            pictureNode_name = node.name!
//            scene.rootNode.addChildNode(node)
//        }
//        vc.view.backgroundColor = UIColor.white
//        vc.modalPresentationStyle = .fullScreen
//        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func mesh_kirikae(_ sender: UISlider) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "obj", recursively: false) {
            node.opacity =  CGFloat(sender.value)
        }
    }
    
    @IBAction func pic_kirikae(_ sender: UISlider) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
            node.opacity =  CGFloat(sender.value)
        }
    }
    @IBAction func right_modelButton(_ sender: UIButton) {
        if current_model_num < database_model_num - 1 {
//            if let node = sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
//                node.removeFromParentNode()
//                all_pic = SCNNode()
//            }
            for n in pictureInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            pictureInfo = []
            
            for n in usdzInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            //usdzInfo = []
            
            for n in arrowInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            //arrowInfo = []
            
            current_model_num += 1
            model_kirikae_hyouji()
            //re_haiti()
            object_re_haiti()
        }
    }
    @IBAction func left_modelButton(_ sender: UIButton) {
        if current_model_num > 0 {
//            if let node = sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
//                node.removeFromParentNode()
//                all_pic = SCNNode()
//            }
            for n in pictureInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            pictureInfo = []
            
            for n in usdzInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            usdzInfo = []
            
            for n in arrowInfo {
                let name = n.0
                if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            arrowInfo = []
            
            current_model_num -= 1
            model_kirikae_hyouji()
            //re_haiti()
            object_re_haiti()
        }
    }
    
    func model_kirikae_hyouji() {
        if let node = sceneView.scene!.rootNode.childNode(withName: "obj", recursively: false) {
            node.removeFromParentNode()
        }
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        self.nameLabel.text = modelname
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let filename = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
            if let referenceNode = SCNReferenceNode(url: filename) {
                referenceNode.load()
                referenceNode.name = "obj"
                self.scene.rootNode.addChildNode(referenceNode)
            }
            else {print("失敗")}
            
        }
    }
    
    //MARK: -オブジェクトを操作する関数
    
    @objc func goButton() {
        button_flag = true
        
        if current_mode_num == 0 {
            print(pictureNode_name)
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.position.x += cos(self.current_kakudo_y + (90*Float.pi)/180) / 10000
                        node.position.z += -sin(self.current_kakudo_y + (90*Float.pi)/180) / 10000
                    }
                    else {
                        node.position.x += -sin(self.current_kakudo_x - (90*Float.pi)/180) / 10000
                        node.position.z += cos(self.current_kakudo_x - (90*Float.pi)/180) / 10000
                    }
                    self.goButton()
                }
            }
        }
    }
    @objc func backButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.position.x += cos(self.current_kakudo_y - (90*Float.pi)/180) / 10000
                        node.position.z += -sin(self.current_kakudo_y - (90*Float.pi)/180) / 10000
                    }
                    else {
                        node.position.x += -sin(self.current_kakudo_x + (90*Float.pi)/180) / 10000
                        node.position.z += cos(self.current_kakudo_x + (90*Float.pi)/180) / 10000
                    }
                    self.backButton()
                }
            }
        }
    }
    @objc func rightButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.position.x += cos(self.current_kakudo_y) / 10000
                        node.position.z += -sin(self.current_kakudo_y) / 10000
                    }
                    else {
                        node.position.x += -sin(self.current_kakudo_x) / 10000
                        node.position.z += cos(self.current_kakudo_x) / 10000
                    }
                    self.rightButton()
                }
            }
        }
    }
    @objc func leftButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.position.x -= cos(self.current_kakudo_y) / 10000
                        node.position.z -= -sin(self.current_kakudo_y) / 10000
                    }
                    else {
                        node.position.x -= -sin(self.current_kakudo_x) / 10000
                        node.position.z -= cos(self.current_kakudo_x) / 10000
                    }
                    self.leftButton()
                }
            }
        }
    }
    @objc func upButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.y += 0.00005
                    self.upButton()
                }
            }
        }
    }
    @objc func downButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.y -= 0.00005
                    self.downButton()
                }
            }
        }
    }
    @objc func rightRollButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.eulerAngles.y += 0.008 * (Float.pi / 180)
                    }
                    else {
                        node.eulerAngles.x -= 0.008 * (Float.pi / 180)
                    }
                    self.rightRollButton()
                }
            }
        }
    }
    @objc func leftRollButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.eulerAngles.y -= 0.008 * (Float.pi / 180)
                    }
                    else {
                        node.eulerAngles.x += 0.008 * (Float.pi / 180)
                    }
                    self.leftRollButton()
                }
            }
        }
    }
    
    @objc func downrollButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.eulerAngles.x -= 0.008 * (Float.pi / 180)
                    }
                    else {
                        node.eulerAngles.y -= 0.008 * (Float.pi / 180)
                    }
                    self.downrollButton()
                }
            }
        }
    }
    
    @objc func uprollButton() {
        button_flag = true
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    if self.current_mode_num == 0 {
                        node.eulerAngles.x += 0.008 * (Float.pi / 180)
                    }
                    else {
                        node.eulerAngles.y += 0.008 * (Float.pi / 180)
                    }
                    self.uprollButton()
                }
            }
        }
    }
    
    
    @objc func releaseButton() {
        button_flag = false
    }
    
    //フレーム更新毎に呼び出し
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        
        if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
            if current_mode_num == 0 {
                self.current_kakudo_y = node.eulerAngles.y
            }
            else {
                self.current_kakudo_x = node.eulerAngles.x
            }
        }
        
        DispatchQueue.main.async {
            if self.current_model_num == 0 {
                self.left_arrowImage.isHidden = true
            }
            else {
                self.left_arrowImage.isHidden = false
            }
            
            if self.current_model_num == self.database_model_num-1 {
                self.right_arrowImage.isHidden = true
            }
            else {
                self.right_arrowImage.isHidden = false
            }
        }
    }
    
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if current_mode_num == 0 {
            moveNode_name = pictureNode_name
        }
        else {
            moveNode_name = arrowNode_name
        }
        
        if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
        
            if recognizer.state == .began {
                lastGestureScale = 1
            }

            let newGestureScale: Float = Float(recognizer.scale)
            // ここで直前のscaleとのdiffぶんだけ取得しときます
            let diff = newGestureScale - lastGestureScale
            let currentScale = node.scale

            // diff分だけscaleを変化させる。1は1倍、1.2は1.2倍の大きさになります。
            node.scale = SCNVector3Make(
                currentScale.x * (1 + diff),
                currentScale.y * (1 + diff),
                currentScale.z * (1 + diff)
            )
            // 保存しとく
            lastGestureScale = newGestureScale
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
