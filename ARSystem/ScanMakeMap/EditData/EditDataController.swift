//
//  NavigationEditModel2.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2021/03/04.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity
import SVProgressHUD

class EditDataController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {

    //MARK: - 変数の設定
    //画面遷移した際のsectionとcellの番号を格納
    var section_num: Int!
    var cell_num: Int!
    var models: Navi_Modelname!
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    let decoder = JSONDecoder()
    let results = try! Realm().objects(Navi_SectionTitle.self)
    var knownAnchors = Dictionary<UUID, SCNNode>()
    
    var picCount: Int!
    var yoko: Float!
    var tate: Float!
    
    var anchors: [ARMeshAnchor] = []
    
    var new_uiimage: UIImage!
    var uiimage_array: [UIImage] = []
    @IBOutlet var imageView: UIImageView!
    
    var objectName_array: [String] = []
    
    var cameraNode = SCNNode()
    var lastGestureScale: Float = 1.0
    
    @IBOutlet var left_modelbutton: UIButton!
    @IBOutlet var right_modelbutton: UIButton!
    @IBOutlet var modelname_label: UILabel!
    
    let deleteObjectButton = UIButton()
    var deleteObjectName = ""
    
    @IBOutlet weak var makeArrowButton: UIButton!
    //nodeの向きをカメラ方向に
    let billboardConstraint = SCNBillboardConstraint()
    
    var calculate: CalculateRenderer!
    var texString: String = "calcu50"
    
    var axis: ObjectOrigin?
    var texmeshNode = SCNNode() {
        didSet {
            texmeshNode.name = "meshNode"
        }
    }
    
    //multipeer用の変数
    let serviceType = "ar-collab"
    @objc var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    @IBOutlet weak var browserButton: UIButton!
    @IBOutlet weak var colabStopButton: UIButton!
    @IBOutlet weak var colabInfoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        section_num = ViewManagement.sectionID!
        cell_num = ViewManagement.cellID!
        models = results[section_num].cells[cell_num].models[current_model_num]
        
        SVProgressHUD.show()
        SVProgressHUD.show(withStatus: "Loading･･･")
        
        sceneView.delegate = self
        sceneView.scene = scene
        //sceneView.allowsCameraControl = true
        sceneView.scene?.rootNode.addChildNode(LightNode())
        
        if results[section_num].cells[cell_num].models.count < 2 {
            right_modelbutton.isHidden = true
            left_modelbutton.isHidden = true
            modelname_label.isHidden = true
        }
        
        picCount = models.pic.count
        yoko = 17.0
        tate = ceil(Float(picCount)/yoko)
        
        //pinch gesuture
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        
        // deleteObjectButtonの設定（オブジェクト長押し時に表示する）
        deleteObjectButton.setTitle("削除", for:UIControl.State.normal)
        deleteObjectButton.setTitleColor(UIColor.white, for: .normal)
        deleteObjectButton.titleLabel?.font =  UIFont.systemFont(ofSize: 20)
        deleteObjectButton.backgroundColor = UIColor.init(red:0, green: 0, blue: 0, alpha: 1)
        deleteObjectButton.addTarget(self,action: #selector(deleteObject),for: .touchUpInside)
        self.view.addSubview(deleteObjectButton)
        deleteObjectButton.isHidden = true
        
        self.colabStopButton.isHidden = true
        self.makeArrowButton.isHidden = true
        
        //通信用設定
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self

        // create the browser viewcontroller with a unique service name
        self.browser = MCBrowserViewController(serviceType:serviceType,
                                               session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                               discoveryInfo:nil, session:self.session)
        self.assistant.start()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for s in models.obj {
            objectName_array.append(s.name_identify)
        }
        
        let num: CGFloat = 3.0 //画像のサイズの縮尺率
        
        for i in 0..<picCount {
            let uiimage = UIImage(data: models.pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        //16384以下にする必要あり
        new_uiimage = TextureImage(W: (2880 / num) * CGFloat(yoko), H: (3840 / num) * CGFloat(tate), array: uiimage_array, yoko: yoko, num: num).makeTexture()
        let uiImage = new_uiimage
        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
        let realm = try! Realm()
        try! realm.write {
            models.texture_pic = imageData
        }
        
        for i in 0..<models.mesh_anchor.count {
            let mesh_data = models.mesh_anchor[i].mesh
            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                anchors.append(meshAnchor)
            }
        }
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10), execute: { [self] in
            if models.texture_bool == 0 {
                let meshNode = BuildMeshNode(anchors: anchors)
                meshNode.name = "meshNode"
                sceneView.scene?.rootNode.addChildNode(meshNode)
                SVProgressHUD.dismiss()
            } else if models.texture_bool != 0 {
                texmeshNode = BuildTextureMeshNode(result: models.mesh_anchor, texImage: new_uiimage)
                sceneView.scene?.rootNode.addChildNode(texmeshNode)
                SVProgressHUD.dismiss()
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func tap_colorNode(_ sender: UIButton) {
        delete_mesh()
        texmeshNode = BuildTextureMeshNode(result: models.mesh_anchor, texImage: new_uiimage)
        sceneView.scene?.rootNode.addChildNode(texmeshNode)
    }
    
    @IBAction func tap_meshNode(_ sender: UIButton) {
        delete_mesh()
        let meshNode = BuildMeshNode(anchors: anchors)
        meshNode.name = "meshNode"
        sceneView.scene?.rootNode.addChildNode(meshNode)
    }
    
    @IBAction func tap_pointNode(_ sender: UIButton) {
        delete_mesh()
        load_pointCloud()
    }
    
    func load_pointCloud() {
        let modelname = models.modelname
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            if models.exit_point == 1 {
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                guard let datas = try? JSONDecoder().decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }

                let node = BuildPointCloud.buildNode(points: datas)//self.build_pointsNode(points: datas)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @IBAction func load_saveObject(_ sender: UIButton) {
        //tap_object_flag = true
        if models.obj.count > 0 {
            for obj in models.obj {
                if obj.type == "usdz" {
                    guard let url = Bundle.main.url(forResource: "art.scnassets/\(obj.name)", withExtension: "usdz") else { return }
                    let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                    let node = scene.rootNode.childNode(withName: obj.name, recursively: true)
                    let json_data = try? decoder.decode(ObjectInfo_data.self, from: obj.info_data)
                    let posi = json_data!.Position
                    let scale = json_data?.Scale
                    let euler = json_data?.EulerAngles
                    node!.position = SCNVector3(posi.x, posi.y, posi.z)
                    node!.scale = SCNVector3(scale!.x, scale!.y, scale!.z)
                    node!.eulerAngles = SCNVector3(euler!.x, euler!.y, euler!.z)
                    node!.name = obj.name_identify
                    sceneView.scene!.rootNode.addChildNode(node!)
                }
            }
        }
    }
    
    
    var item = ObjectItem(name: "", id: 0, kind: "")
    let ObjectdataSource = ObjectModel()
    var select_object_num = 0
    var tap_object_flag = false
    var tap_arrow_flag = false
    var arrowPoint_count = 0
    
    @IBAction func tap_objectMenu_button(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "PopOver", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "MarkerPopOverController") as! MarkerPopOverController
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 100, height: 300)
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (num: Int) -> Void in
            DispatchQueue.main.async {
                self.select_object_num = num
                self.item = self.ObjectdataSource.item(row: self.select_object_num)
                
//                if self.item.name == "arrow100" {
//                    self.Alert_arrow()
//                }
            }
        }
        
        tap_object_flag = true
        present(contentVC, animated: true, completion: nil)
    }
    
    @IBAction func tap_remoteSupport(_ sender: UIButton) {
        self.Alert_arrow()
    }
    
    
    @objc func Alert_arrow() {
        let title = "物体の移動支援"
        let message = "移動させたい物体と移動先を指定して作成ボタンを押して下さい。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            tap_arrow_flag = true
            tap_object_flag = true
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    //MARK: -オブジェクト処理
    
    var touchMove_flag = false
    var choiceNode_name: String = ""
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        let hitResults = sceneView.hitTest(location, options: [:])
        if !hitResults.isEmpty {
            print("0:\(String(describing: hitResults[0].node.name))")
            print("1:\(String(describing: hitResults[0].node.parent?.name))")
        }
        for result in hitResults {
            if result.node.parent?.name == "axis" {
                sceneView.allowsCameraControl = false
                axis?.startAxisDrag(result: result, screenPos: location)
            }
        }
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        axis?.updateAxisDrag(screenPos: location) { node in
            //操作したオブジェクト情報の一時保存
            self.operateObject(node: node)
        }
        touchMove_flag = true
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        axis?.endAxisDrag(screenPos: location) { node in
            //操作したオブジェクト情報の保存
            self.saveObject(node: node)
        }
        sceneView.allowsCameraControl = true
        deleteObjectButton.isHidden = true
        
//        print("---------------------------------------------------------")
        //print("touchMove_flag：\(touchMove_flag)")
        //print("tap_object_flag：\(tap_object_flag)")
        //print("tap_arrow_flag：\(tap_arrow_flag)")
        
        
        let hitResults = sceneView.hitTest(location, options: [:])
        if hitResults.count > 0 {
            if tap_object_flag == true && tap_arrow_flag == false {
                //タップした位置にオブジェクト配置
                if hitResults[0].node.parent?.name == "meshNode" {
                    let posi = hitResults[0].worldCoordinates
                    var node = SCNNode()
                    if item.kind == "usdz" {
                        guard let url = Bundle.main.url(forResource: "art.scnassets/\(item.name)", withExtension: "usdz") else { return }
                        let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                        node = scene.rootNode.childNode(withName: item.name, recursively: true)!
                        node.scale = SCNVector3(0.01, 0.01, 0.01)
                    } else if item.kind == "scn" {
                        let scene = SCNScene(named: "art.scnassets/arrow.scn")
                        node = (scene?.rootNode.childNode(withName: "arrow", recursively: false))!
                        node.scale = SCNVector3(0.1, 0.1, 0.1)
                        node.eulerAngles = SCNVector3(0, 0, 0)
                    }
                    node.position = posi
                    node.name = item.name + String(models.add_obj_count)
                    sceneView.scene!.rootNode.addChildNode(node)
                    
                    choiceNode_name = node.name!
                    objectName_array.append(node.name!)
                    
                    //配置したオブジェクト情報の保存
                    placeObject(node: node)
                    
                    axis = ObjectOrigin(sceneView: sceneView, choiceNode_name: choiceNode_name, posi: posi, euler: node.eulerAngles)
                    
                    tap_object_flag = false
                    touchMove_flag = false
                }
            } else if tap_object_flag == false && tap_arrow_flag == false {
                //配置したオブジェクトをタップした際に操作用座標軸を表示
                for (i, name) in objectName_array.enumerated() {
                    if (hitResults[0].node.name == name ||
                        hitResults[0].node.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                        hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name){

                        let json_data = try? decoder.decode(ObjectInfo_data.self, from: models.obj[i].info_data)
                        let posi = json_data!.Position
                        //let scale = json_data?.Scale
                        let euler = json_data!.EulerAngles
                        
                        choiceNode_name = name
                        axis = ObjectOrigin(sceneView: sceneView, choiceNode_name: choiceNode_name, posi: SCNVector3(posi.x, posi.y, posi.z), euler: SCNVector3(euler.x, euler.y, euler.z))
                        
                        break
                    }
                }
            }
            if hitResults[0].node.parent?.name == "meshNode" && tap_arrow_flag == true {
                if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                    node.removeFromParentNode()
                }
                let posi = hitResults[0].worldCoordinates
                billboardConstraint.freeAxes = SCNBillboardAxis.Y //Y軸の回転はこの制約を加えない様にします。
                if arrowPoint_count == 0 {
                    let scene = SCNScene(named: "art.scnassets/startPoint.scn")
                    let node = (scene?.rootNode.childNode(withName: "startPoint", recursively: false))!
                    node.position = posi
                    node.scale = SCNVector3(0.15, 0.15, 0.15)
                    node.position.y += 0.05
                    node.constraints = [billboardConstraint]
                    node.name = "startPoint"
                    //node.opacity = 0.7
                    sceneView.scene!.rootNode.addChildNode(node)
                    
                    arrowPoint_count += 1
                } else if arrowPoint_count == 1 {
                    let scene = SCNScene(named: "art.scnassets/endPoint.scn")
                    let node = (scene?.rootNode.childNode(withName: "endPoint", recursively: false))!
                    node.position = posi
                    node.scale = SCNVector3(0.15, 0.15, 0.15)
                    node.position.y += 0.05
                    node.constraints = [billboardConstraint]
                    node.name = "endPoint"
                    //node.opacity = 0.9
                    sceneView.scene!.rootNode.addChildNode(node)
                    
                    arrowPoint_count = 0
                    makeArrowButton.isHidden = false
                    tap_arrow_flag = false
                }
            }
        }
    }
    
    //配置した始点，終点に従って矢印オブジェクトを表示
    @IBAction func makeArrow(_ sender: UIButton) {
        let arrowNode = ArrowNode(sceneView: sceneView)
        arrowNode.name = "all_arrow"
        sceneView.scene?.rootNode.addChildNode(arrowNode)
        objectName_array.append(arrowNode.name!)
        makeArrowButton.isHidden = true
        
        send_remoteSupportObjectData(state: "遠隔サポート", name_identify: arrowNode.name!, info_data_array: arrowNode.data_array)
    }    
    
    @IBAction func long_touches(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: self.sceneView)
        let hitResults = sceneView.hitTest(location, options: [:])
        if hitResults.count > 0 {
            for name in objectName_array {
                if (hitResults[0].node.name == name ||
                    hitResults[0].node.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                    hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name){
                    
                    deleteObjectButton.frame = CGRect(x:location.x - 50, y:location.y - 100, width:70, height:40)
                    deleteObjectName = name
                    deleteObjectButton.isHidden = false
                }
            }
        }
    }
    
    @objc func deleteObject() {
        if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
            node.removeFromParentNode()
        }
        
        sceneView.scene?.rootNode.childNode(withName: deleteObjectName, recursively: false)!.removeFromParentNode()
        let index = objectName_array.firstIndex(of: deleteObjectName)
        if deleteObjectName != "all_arrow" {
            let realm = try! Realm()
            try! realm.write {
                models.obj.remove(at: index!)
            }
        }
        objectName_array.remove(at: index!)
            
        //削除
        send_deleteObjectData(state: "削除", name_identify: deleteObjectName)
        
        deleteObjectButton.isHidden = true
    }
    
    //拡大・縮小
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            lastGestureScale = 1
        }
    
        let newGestureScale: Float = Float(recognizer.scale)
        let diff = newGestureScale - lastGestureScale
    
        if !choiceNode_name.isEmpty {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                let currentScale = node.scale
                //diff分だけscaleを変化させる。1は1倍、1.2は1.2倍
                node.scale = SCNVector3Make(
                    currentScale.x * (1 + diff),
                    currentScale.y * (1 + diff),
                    currentScale.z * (1 + diff)
                )
                
                let num = objectName_array.firstIndex(of: choiceNode_name)!
                let json_data = makeNodeData(node: node)
                let realm = try! Realm()
                try! realm.write {
                    models.obj[num].info_data = json_data
                }
                    
                //移動，拡大，縮小，回転
                send_operateObjectData(state: "操作", name_identify: choiceNode_name, info_data: json_data)
            }
            lastGestureScale = newGestureScale
        }
    }
    
    //MARK: -メッシュ処理
    @IBAction func tap_texture_riset(_ sender: UIButton) {
        let realm = try! Realm()
        try! realm.write {
            models.texture_bool = 0
            models.mesh_anchor.removeAll()
        }
        
        for anchor in anchors {
            guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else{ return }
            try! realm.write {
                models.mesh_anchor.append(anchor_data(value: ["mesh": mesh_data]))
            }
        }
        
        delete_mesh()
        let meshNode = BuildMeshNode(anchors: anchors)
        meshNode.name = "meshNode"
        sceneView.scene?.rootNode.addChildNode(meshNode)
    }
    
    func delete_mesh() {
        if let node = sceneView.scene!.rootNode.childNode(withName: "meshNode", recursively: false) {
            print("delete mesh")
            node.removeFromParentNode()
        }
        if let node = sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
            node.removeFromParentNode()
        }
    }
    
    //テクスチャの表示状態を決めるための関数
    @IBAction func texture_switch(_ sender: UISwitch) {
        print(sender.isOn)
        if sender.isOn == true {
            texString = "calcu50"
        } else if sender.isOn == false {
            texString = "calcu5"
        }
    }
    
    //Metalを用いたテクスチャ割り当て
    @IBAction func tap_makeTexture_button(_ sender: UIButton) {
        SVProgressHUD.show()
        SVProgressHUD.show(withStatus: "Calculating")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10), execute: { [self] in
            let calculateParameta = calculateParameta(device: self.sceneView.device!,
                                                      W: Int(sceneView.bounds.width),
                                                      H: Int(sceneView.bounds.height),
                                                      tate: Int(tate), yoko: Int(yoko),
                                                      funcString: texString)
            let GPUCalculateTexture = GPUCalculateTexture(sceneView: sceneView, anchors: anchors, picCount: models.pic.count, models: models, calculateParameta: calculateParameta)
            GPUCalculateTexture.makeGPUTexture() { [self] in
                delete_mesh()
                texmeshNode = BuildTextureMeshNode(result: models.mesh_anchor, texImage: new_uiimage)
                sceneView.scene?.rootNode.addChildNode(texmeshNode)
                SVProgressHUD.dismiss()
            }
        })
    }
    
    //CPUでのテクスチャ割り当て
    @IBAction func tap_makeTexture3(_ sender: UIButton) {
        SVProgressHUD.show()
        SVProgressHUD.show(withStatus: "Calculating")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10), execute: { [self] in
            let calculateParameta = calculateParameta(device: self.sceneView.device!,
                                                      W: Int(sceneView.bounds.width),
                                                      H: Int(sceneView.bounds.height),
                                                      tate: Int(tate), yoko: Int(yoko),
                                                      funcString: texString)
            let CPUCalculateTexture = CPUCalculateTexture(anchors: anchors, models: models, picCount: picCount, calculateParameta: calculateParameta)
            CPUCalculateTexture.makeCPUTexture() { [self] in
                delete_mesh()
                texmeshNode = BuildTextureMeshNode(result: models.mesh_anchor, texImage: new_uiimage)
                sceneView.scene?.rootNode.addChildNode(texmeshNode)
                SVProgressHUD.dismiss()
            }
        })
    }
    
    //MARK: - コラボレーション用
    @IBAction func serchBrowser(_ sender: UIButton) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    @IBAction func colabStop(_ sender: UIButton) {
        self.session.disconnect()
    }
    
    //メッシュデータを送る
    @IBAction func send_colabData(_ sender: UIButton) {
        send_meshData()
    }
    
    //ARWorldMapを送る
    @IBAction func send_ARcolabData(_ sender: UIButton) {
        send_worldmapData()
    }
    
    //MARK: - その他
    @IBAction func right_Change(_ sender: UIButton) {
        if current_model_num < database_model_num - 1 {
            current_model_num += 1
            model_kirikae_hyouji()
        }
    }
    
    @IBAction func left_change(_ sender: UIButton) {
        if current_model_num > 0 {
            current_model_num -= 1
            model_kirikae_hyouji()
        }
    }
    
    func model_kirikae_hyouji() {
        delete_mesh()
        //load_anchor()
        let meshNode = BuildMeshNode(anchors: anchors)
        meshNode.name = "meshNode"
        sceneView.scene?.rootNode.addChildNode(meshNode)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
