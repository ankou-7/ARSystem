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

class EditDataController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {
    
    //MARK: - コラボレーション用
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async() { [self] in
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    colabInfoLabel.text = "Connecting: \(peerID.displayName)"
                    browserButton.isHidden = true
                    colabStopButton.isHidden = false
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    colabInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    colabInfoLabel.text = "Not Connect"
                    browserButton.isHidden = false
                    colabStopButton.isHidden = true
                @unknown default:
                    colabInfoLabel.text = "Not Connect"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    @IBAction func serchBrowser(_ sender: UIButton) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    @IBAction func colabStop(_ sender: UIButton) {
        self.session.disconnect()
    }
    
    //メッシュデータを送る
    @IBAction func send_colabData(_ sender: UIButton) {
        print("送信")
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "メッシュ送信開始:\(anchors.count)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //テクスチャData
        try? self.session.send(results[section_num].cells[cell_num].models[current_model_num].texture_pic!, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        //メッシュData
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices!
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals!
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            let facesData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces!
            let texcoordsData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords!
            
            guard let countData = try? NSKeyedArchiver.archivedData(withRootObject: "\(count)" as NSString, requiringSecureCoding: true)
            else { return }
            try? self.session.send(countData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
            try? self.session.send(vertexData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(normalData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(facesData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
            try? self.session.send(texcoordsData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable) //
        }
        
//        guard let finishData = try? NSKeyedArchiver.archivedData(withRootObject: "メッシュ送信終了" as NSString, requiringSecureCoding: true)
//        else { return }
//        try? self.session.send(finishData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    //ARWorldMapを送る
    @IBAction func send_ARcolabData(_ sender: UIButton) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "ワールドマップ送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //スキャンのヒントになる画像
        try? self.session.send(results[section_num].cells[cell_num].models[current_model_num].worldimage!, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        //worldmap
        try? self.session.send(results[self.section_num].cells[self.cell_num].models[self.current_model_num].worlddata! as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
    }
    
    
    func send_ObjectData(state: String, name: String, name_identify: String, type: String, info_data: Data) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name):\(name_identify):\(type)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        try? self.session.send(info_data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
//        guard let finishData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト情報送信終了" as NSString, requiringSecureCoding: true)
//        else { return }
//        try? self.session.send(finishData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    func send_operateObjectData(state: String, name_identify: String, info_data: Data) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name_identify)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        try? self.session.send(info_data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    func send_deleteObjectData(state: String, name_identify: String) {
        guard let startData = try? NSKeyedArchiver.archivedData(withRootObject: "オブジェクト\(state)情報送信開始" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(startData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
        
        guard let StringData = try? NSKeyedArchiver.archivedData(withRootObject: "\(name_identify)" as NSString, requiringSecureCoding: true)
        else { return }
        try? self.session.send(StringData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
    }
    
    //MARK: - 変数の設定
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    let decoder = JSONDecoder()
    let results = try! Realm().objects(Navi_SectionTitle.self)
    var knownAnchors = Dictionary<UUID, SCNNode>()
    
    var anchors: [ARMeshAnchor] = []
    var texcoords2: [[SIMD2<Float>]] = []
    var tex_bool: [[Bool]] = []
    var vertex_array: [[SCNVector3]] = []
    var normal_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var face_bool: [[Int]] = []
    
    var new_face_array: [[Int32]] = []
    var new_vertex_array: [[SCNVector3]] = []
    var new_normal_array: [[SCNVector3]] = []
    var new_texcoords2: [[SIMD2<Float>]] = []
    
    var new_uiimage: UIImage!
    var uiimage_array: [UIImage] = []
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var ActivityView: UIActivityIndicatorView!
    
    var pixelData: [UInt8] = []
    var new_pixelData: [UInt8] = [UInt8](repeating: 0, count: 44236800)
    
    var objectName_array: [String] = []
    @IBOutlet weak var delete_finish_button: UIButton!
    
    var cameraNode = SCNNode()
    var lastGestureScale: Float = 1.0
    
    @IBOutlet var left_modelbutton: UIButton!
    @IBOutlet var right_modelbutton: UIButton!
    @IBOutlet var modelname_label: UILabel!
    
    private var calculate: CalculateRenderer!
    
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
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.0
        cameraNode.opacity = 0 //透明化
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.0)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        scene.rootNode.addChildNode(lightNode)
        
        delete_finish_button.isHidden = true
        ActivityView.stopAnimating()
        //ActivityView.isHidden = true
        
        if results[section_num].cells[cell_num].models.count < 2 {
            right_modelbutton.isHidden = true
            left_modelbutton.isHidden = true
            modelname_label.isHidden = true
        }
        
        //pinch gesuture
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        
        self.colabStopButton.isHidden = true
        
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
        
//        let image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[0].pic_data!)
//        imageView.image = image
//        pixelData = (image?.cgImage!.pixelData())!
//        //print(pixel_image)
//        print(pixelData.count)
//        print(pixelData[0..<20])


        for s in results[section_num].cells[cell_num].models[current_model_num].obj {
            objectName_array.append(s.name_identify)
        }
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        let num: CGFloat = 3.0 //画像のサイズの縮尺率
        print("pic_count：\(count)")
        
        for i in 0..<count {
            let uiimage = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        //16384以下にする必要あり
        new_uiimage = ComposeUIImage(UIImageArray: uiimage_array, width: (2880 / num) * CGFloat(yoko), height: (3840 / num) * CGFloat(tate), yoko: yoko, num: num)
        //print(new_uiimage.size)
        //imageView.image = new_uiimage
        let uiImage = new_uiimage
        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].texture_pic = imageData
        }
        
        //メッシュ情報初期化
        for i in 0..<results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.count {
            let mesh_data = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].mesh
            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                anchors.append(meshAnchor)
            }
            texcoords2.append([])
            normal_array.append([])
            tex_bool.append([])
            vertex_array.append([])
            face_array.append([])
            face_bool.append([])
            
            new_face_array.append([])
            new_vertex_array.append([])
            new_normal_array.append([])
            new_face_array.append([])
            new_texcoords2.append([])
        }
        
//        let realm = try! Realm()
//        try! realm.write {
//            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 0
//        }
        
        print(results[section_num].cells[cell_num].models[current_model_num].texture_bool)
        
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 0 {
            load_anchor(tex_bool: false)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 2 {
            load_anchor2()
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 3 {
            let node =   build2(image: new_uiimage)
            sceneView.scene?.rootNode.addChildNode(node)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func tap_colorNode(_ sender: UIButton) {
        delete_mesh()
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 2 {
            load_anchor2()
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 3 {
            //delete_mesh()
            let node =   build2(image: new_uiimage)
            sceneView.scene?.rootNode.addChildNode(node)
        }
    }
    
    @IBAction func tap_meshNode(_ sender: UIButton) {
        delete_mesh()
        load_anchor(tex_bool: false)
    }
    
    @IBAction func tap_pointNode(_ sender: UIButton) {
        delete_mesh()
        load_pointCloud()
    }
    
    func load_pointCloud() {
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                guard let datas = try? JSONDecoder().decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }

                let node = self.build_pointsNode(points: datas)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @IBAction func load_saveObject(_ sender: UIButton) {
        tap_object_flag = true
        if results[section_num].cells[cell_num].models[current_model_num].obj.count > 0 {
            for obj in results[section_num].cells[cell_num].models[current_model_num].obj {
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
            self.select_object_num = num
            self.item = self.ObjectdataSource.item(row: self.select_object_num)
        }
        
        tap_object_flag = true
        present(contentVC, animated: true, completion: nil)
    }
    
    var delete_flag = false
    
    @IBAction func delete_object(_ sender: UIButton) {
            let title = "配置オブジェクトの削除"
            let message = "削除したいオブジェクトをタップして下さい．"
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
                delete_finish_button.isHidden = false
                delete_flag = true
                if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                    node.removeFromParentNode()
                }
            })
                
            self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func tap_delete_finish_button(_ sender: UIButton) {
        delete_finish_button.isHidden = true
        delete_flag = false
    }
    
    //MARK: -オブジェクト処理
    
    var touchMove_flag = false
    var choiceNode_name: String = ""
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        let hitResults = sceneView.hitTest(location, options: [:])
        for result in hitResults {
            if result.node.parent?.name == "axis" {
                sceneView.allowsCameraControl = false
            }
        }
        startAxisDrag(screenPos: location)
        touchMove_flag = false
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        updateAxisDrag(screenPos: location)
        touchMove_flag = true
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        endAxisDrag(screenPos: location)
        sceneView.allowsCameraControl = true
        
        if touchMove_flag == false {
            if tap_object_flag == true {
                if delete_flag == false {
                    let hitResults = sceneView.hitTest(location, options: [:])
                    if hitResults.count > 0 {
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
                                if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                                    node.removeFromParentNode()
                                }
                                let axis = ObjectOrigin().makeAxisNode()
                                let json_data = try? decoder.decode(ObjectInfo_data.self, from:results[section_num].cells[cell_num].models[current_model_num].obj[i].info_data)
                                let posi = json_data!.Position
                                //let scale = json_data?.Scale
                                let euler = json_data?.EulerAngles
                                
                                axis.position = SCNVector3(posi.x, posi.y, posi.z)
                                axis.scale = SCNVector3(2.0, 2.0, 2.0)
                                axis.eulerAngles = SCNVector3(euler!.x, euler!.y, euler!.z)
                                sceneView.scene!.rootNode.addChildNode(axis)
                                choiceNode_name = name
                            }
                        }
                        
                        if hitResults[0].node.name == "child_tex_node" {
                            let posi = hitResults[0].worldCoordinates
                            guard let url = Bundle.main.url(forResource: "art.scnassets/\(item.name)", withExtension: "usdz") else { return }
                            let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                            let node = scene.rootNode.childNode(withName: item.name, recursively: true)
                            node?.scale = SCNVector3(0.01, 0.01, 0.01)
                            node?.position = posi
                            node!.name = item.name + String(results[section_num].cells[cell_num].models[current_model_num].add_obj_count)
                            sceneView.scene!.rootNode.addChildNode(node!)
                            
                            choiceNode_name = node!.name!
                            objectName_array.append(node!.name!)
                            
                            let entity = ObjectInfo_data(Position: Vector3Entity(x: posi.x,
                                                                                 y: posi.y,
                                                                                 z: posi.z),
                                                         Scale: Vector3Entity(x: (node?.scale.x)!,
                                                                              y: (node?.scale.y)!,
                                                                              z: (node?.scale.z)!),
                                                         EulerAngles: Vector3Entity(x: (node?.eulerAngles.x)!,
                                                                                    y: (node?.eulerAngles.y)!,
                                                                                    z: (node?.eulerAngles.z)!))
                            let json_data = try! JSONEncoder().encode(entity)
                            let realm = try! Realm()
                            try! realm.write {
                                results[section_num].cells[cell_num].models[current_model_num].add_obj_count += 1
                                results[section_num].cells[cell_num].models[current_model_num].obj.append(ObjectInfo(
                                    value: ["name": item.name,
                                            "name_identify": node!.name!,
                                            "type": item.kind,
                                            "info_data": json_data]))
                            }
                            
                            //配置
                            send_ObjectData(state: "配置", name: item.name, name_identify: node!.name!, type: item.kind, info_data: json_data)
                            
                            if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                                node.removeFromParentNode()
                            }
                            let axis = ObjectOrigin().makeAxisNode()
                            axis.position = posi
                            axis.scale = SCNVector3(2.0, 2.0, 2.0)
                            sceneView.scene!.rootNode.addChildNode(axis)
                            
                            //tap_object_flag = false
                            touchMove_flag = false
                        }
                    }
                }
                else if delete_flag == true {
                    let hitResults = sceneView.hitTest(location, options: [:])
                    if hitResults.count > 0 {
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
                                
                                sceneView.scene?.rootNode.childNode(withName: name, recursively: false)!.removeFromParentNode()
                                let realm = try! Realm()
                                try! realm.write {
                                    results[section_num].cells[cell_num].models[current_model_num].obj.remove(at: i)
                                }
                                objectName_array.remove(at: i)
                                    
                                //削除
                                send_deleteObjectData(state: "削除", name_identify: choiceNode_name)
                            }
                        }
                    }
                }
                
            }
        }
    }
    
    var origin_posi = CGPoint(x: 0, y: 0)
    var distance: Float = 0.0
    var pre_screenPos = CGPoint(x: 0, y: 0)
    var select_node: SCNNode!
    var start_flag = false
    
    func startAxisDrag(screenPos: CGPoint) {
        let hitResults = sceneView.hitTest(screenPos, options: [:])
        for result in hitResults {
            
            if result.node.parent?.name == "axis" {
                let posi = sceneView.projectPoint(result.node.parent!.position)
                origin_posi = CGPoint(x: CGFloat(posi.x), y: CGFloat(posi.y))
                distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
                pre_screenPos = screenPos
                select_node = result.node
                start_flag = true
                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            }
        }
    }
    
    func updateAxisDrag(screenPos: CGPoint) {
        if start_flag == true {
            let posi = sceneView.projectPoint(select_node.parent!.position)
            let now_distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
            let diff = now_distance - distance
            let translation = screenPos.y - pre_screenPos.y
            if select_node.name == "XAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
            }
            else if select_node.name == "YAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
            }
            else if select_node.name == "ZAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
            }
            else if select_node.name == "XCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
            }
            else if select_node.name == "YCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
            }
            else if select_node.name == "ZCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
            }
            let now_posi = sceneView.projectPoint(select_node.parent!.position)
            origin_posi = CGPoint(x: CGFloat(now_posi.x), y: CGFloat(now_posi.y))
            distance = sqrt((now_posi.x - Float(screenPos.x)) * (now_posi.x - Float(screenPos.x)) + (now_posi.y - Float(screenPos.y)) * (now_posi.y - Float(screenPos.y)))
            pre_screenPos = screenPos
            
            
            if let node = sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                                     y: node.position.y,
                                                                     z: node.position.z),
                                             Scale: Vector3Entity(x: node.scale.x,
                                                                  y: node.scale.y,
                                                                  z: node.scale.z),
                                             EulerAngles: Vector3Entity(x: node.eulerAngles.x,
                                                                        y: node.eulerAngles.y,
                                                                        z: node.eulerAngles.z))
                let json_data = try! JSONEncoder().encode(entity)
                //移動，拡大，縮小，回転
                send_operateObjectData(state: "操作", name_identify: choiceNode_name, info_data: json_data)
            }
        }
    }
    
    func endAxisDrag(screenPos: CGPoint) {
        if start_flag == true {
            start_flag = false
            
            if let node = sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                let num = objectName_array.firstIndex(of: choiceNode_name)!
                let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                                     y: node.position.y,
                                                                     z: node.position.z),
                                             Scale: Vector3Entity(x: node.scale.x,
                                                                  y: node.scale.y,
                                                                  z: node.scale.z),
                                             EulerAngles: Vector3Entity(x: node.eulerAngles.x,
                                                                        y: node.eulerAngles.y,
                                                                        z: node.eulerAngles.z))
                let json_data = try! JSONEncoder().encode(entity)
                let realm = try! Realm()
                try! realm.write {
                    results[section_num].cells[cell_num].models[current_model_num].obj[num].info_data = json_data
                }
                
                //移動，拡大，縮小，回転
                send_operateObjectData(state: "操作", name_identify: choiceNode_name, info_data: json_data)
            }
            
            if select_node.name == "XAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
            else if select_node.name == "XCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
        }
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
                let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                                     y: node.position.y,
                                                                     z: node.position.z),
                                             Scale: Vector3Entity(x: node.scale.x,
                                                                  y: node.scale.y,
                                                                  z: node.scale.z),
                                             EulerAngles: Vector3Entity(x: node.eulerAngles.x,
                                                                        y: node.eulerAngles.y,
                                                                        z: node.eulerAngles.z))
                let json_data = try! JSONEncoder().encode(entity)
                let realm = try! Realm()
                try! realm.write {
                    results[section_num].cells[cell_num].models[current_model_num].obj[num].info_data = json_data
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
            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 0
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.removeAll()
        }
        print(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor)
        
        for anchor in anchors {
            guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else{ return }
            try! realm.write {
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.append(anchor_data(value: ["mesh": mesh_data]))
            }
        }
        
        
//        for i in 0..<texcoords2.count {
//            for j in 0..<texcoords2[i].count {
//                texcoords2[i][j] = SIMD2<Float>(0, 0)
//            }
//        }
//        save_model()
        delete_mesh()
        load_anchor(tex_bool: false)
    }
    
    func load_anchor(tex_bool: Bool) {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for (i, mesh_anchor) in anchors.enumerated() {
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            
            let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
            let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
            let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
            let facesElement = SCNGeometryElement(data: data, primitiveType: convertType(type: faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
            var sources = [verticesSource, normalsSource]
            
            if tex_bool == true {
                let texcoords = try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords as Data)
                let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords!)
                sources.append(textureCoordinates)
            }
            
            let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
            nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage
            
            if tex_bool == false {
                let defaultMaterial = SCNMaterial()
                defaultMaterial.fillMode = .lines
                defaultMaterial.diffuse.contents = UIColor.green
                nodeGeometry.materials = [defaultMaterial]
            }
            
            let node = SCNNode(geometry: nodeGeometry)
            node.simdTransform = mesh_anchor.transform
            knownAnchors[mesh_anchor.identifier] = node
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
            //scene.rootNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(tex_node)
        print("load完了")
    }
    
    func load_anchor2() {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            
            let faces = try? decoder.decode([Int32].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces as Data)
            let texcoords = try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords as Data)
            
            let verticeSource = SCNGeometrySource(
                data: vertexData! as Data,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SCNVector3>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData! as Data,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SCNVector3>.size
            )
            let faceSource = SCNGeometryElement(indices: faces!, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords!)

            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage
            
//            let defaultMaterial = SCNMaterial()
//            defaultMaterial.fillMode = .lines
//            defaultMaterial.diffuse.contents = UIColor.blue
//            nodeGeometry.materials = [defaultMaterial]
            
            let node = SCNNode(geometry: nodeGeometry)
            
            knownAnchors[anchors[i].identifier] = node
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
            //scene.rootNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(tex_node)
        print("load完了")
    }
    
    func build2(image: UIImage) -> SCNNode {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices!
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals!
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            
            let faces = (try? decoder.decode([Int32].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces))!
            let texcoords = (try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords))!
            
            let verticeSource = SCNGeometrySource(
                data: vertexData,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)
            
            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = image
            
//            let defaultMaterial = SCNMaterial()
//            defaultMaterial.fillMode = .lines
//            defaultMaterial.diffuse.contents = UIColor.blue
//            nodeGeometry.materials = [defaultMaterial]
            
            let node = SCNNode(geometry: nodeGeometry)
            knownAnchors[anchors[i].identifier] = node
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
        }
        return tex_node
    }
    
    func save_model(num: Int) {
        for (i, _) in anchors.enumerated() {
            var texcoords_data = Data()
            var vertices_data = Data()
            var normals_data = Data()
            var faces_data = Data()
            
            if num != 2 {
                texcoords_data = try! JSONEncoder().encode(texcoords2[i])
                vertices_data = Data(bytes: vertex_array[i], count: MemoryLayout<SCNVector3>.size * vertex_array[i].count)
                normals_data = Data(bytes: normal_array[i], count: MemoryLayout<SCNVector3>.size * normal_array[i].count)
                if num == 1 {
                    faces_data = try! JSONEncoder().encode(new_face_array[i])
                } else {
                    faces_data = try! JSONEncoder().encode(face_array[i])
                }
            } else if num == 2 {
                texcoords_data = try! JSONEncoder().encode(new_texcoords2[i])
                vertices_data = Data(bytes: new_vertex_array[i], count: MemoryLayout<SCNVector3>.size * new_vertex_array[i].count)
                normals_data = Data(bytes: new_normal_array[i], count: MemoryLayout<SCNVector3>.size * new_normal_array[i].count)
                faces_data = try! JSONEncoder().encode(new_face_array[i])
            }
            
            let realm = try! Realm()
            try! realm.write {
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords = texcoords_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices = vertices_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals = normals_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces = faces_data
                if num != 2 {
                    results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count = vertex_array[i].count
                } else if num == 2 {
                    results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count = new_vertex_array[i].count
                }
            }
        }
        let realm = try! Realm()
        try! realm.write {
            if num == 0 {
                results[section_num].cells[cell_num].models[current_model_num].texture_bool = 1
            } else {
                results[section_num].cells[cell_num].models[current_model_num].texture_bool = 2
            }
        }
        print("save完了")
        //print(results[section_num].cells[cell_num].models[current_model_num])
    }
    
    func delete_mesh() {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
        knownAnchors = Dictionary<UUID, SCNNode>()
        
        if let node = sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
            node.removeFromParentNode()
        }
    }
    
    func convertType(type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
        switch type {
        case .line:
            return .line
        case .triangle:
            return .triangles
        @unknown default:
            fatalError("unknown type")
        }
    }
    
    
    func make_calcuParameta() -> ([float4x4], [depthPosition]) {
        var calcuMatrix: [float4x4] = []
        var depth: [depthPosition] = []
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        for i in 0..<count {
            let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
            
            let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                           json_data!.viewMatrix.y,
                                           json_data!.viewMatrix.z,
                                           json_data!.viewMatrix.w)
            let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                 json_data!.projectionMatrix.y,
                                                 json_data!.projectionMatrix.z,
                                                 json_data!.projectionMatrix.w)
            let matrix = projectionMatrix * viewMatrix
            calcuMatrix.append(matrix)
            
            let depth_array = (try? decoder.decode([depthPosition].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!))!
            depth.append(contentsOf: depth_array)
        }
        return (calcuMatrix, depth)
    }
    
    //Metalを用いたテクスチャ割り当て
    @IBAction func tap_makeTexture_button(_ sender: UIButton) {
        //ActivityView.isHidden = false
//        ActivityView.startAnimating()
        //make_texture(num: 0)
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        let (calcuUnifoms, depth) = make_calcuParameta()
        //self.calculate.matrix = calcuMatrix
        
        var flag = 0
        
        DispatchQueue.global().sync {
            
            let start = Date()
            print("calcu開始")
            //DispatchQueue.main.async { [self] in
            
            self.calculate = CalculateRenderer(section_num: section_num, cell_num: cell_num, model_num: current_model_num, anchor: anchors, metalDevice: self.sceneView.device!, calcuUniforms: calcuUnifoms, depth: depth, tate: Int(tate), yoko: Int(yoko))
            self.calculate.drawRectResized(size: self.sceneView.bounds.size)
            
            
            DispatchQueue.main.async { [self] in
                ActivityView.startAnimating()
                for i in 0..<anchors.count {
                    flag += self.calculate.calcu5(num: i)
                    //let node = calculate.calcu4(num: 1)
                    //sceneView.scene?.rootNode.addChildNode(node)
                    print("\(flag)回目")
                    print("配列中身：\(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i])")
                    print("----------------------------------------------------------------------------------------")
                    if flag == anchors.count {
                        print("calcu終了")
                        let elapsed = Date().timeIntervalSince(start)
                        print("処理時間：\(elapsed)")
                        //print("配列全て中身：\(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor)")
//                        print("load")
                        delete_mesh()
                        let node =   build2(image: new_uiimage)
                        sceneView.scene?.rootNode.addChildNode(node)
                        //load_anchor2()
                        ActivityView.stopAnimating()
                    }
                }
            }
            
        }
        
    }
    
    //CPUでのテクスチャ割り当て
    @IBAction func tap_makeTexture3(_ sender: UIButton) {
//        DispatchQueue.global().sync {
//            self.ActivityView.startAnimating()
            make_texture1000(num: 2)
//            self.ActivityView.stopAnimating()
//        }
    }
    
    @IBAction func tap_saveButton(_ sender: UIButton) {
        //save_model()
    }
    
    func Make_meshInfo_Array() {
        for (i, meshAnchor) in anchors.enumerated() {
            texcoords2[i] = []
            tex_bool[i] = []
            vertex_array[i] = []
            face_array[i] = []
            face_bool[i] = []
            normal_array[i] = []
            
            let verticles = meshAnchor.geometry.vertices
            let normals = meshAnchor.geometry.normals
            for j in 0..<verticles.count {
                texcoords2[i].append(SIMD2<Float>(0, 0))
                tex_bool[i].append(false)
                
                let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                let world_vertex4 = simd_mul(meshAnchor.transform, vertex4)
                let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                vertex_array[i].append(world_vector3)
                
                let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * j))
                let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                normal_array[i].append(normal)
            }
            
            let faces = meshAnchor.geometry.faces
            for j in 0..<faces.count {
                let indicesPerFace = faces.indexCountPerPrimitive
                for offset in 0..<indicesPerFace {
                    let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                    let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                    face_array[i].append(per_face)
                }
                face_bool[i].append(-1)
            }
        }
    }
    
    func remake_mesh() {
        var num_array: [[Int]] = []
        
        for index in 0..<vertex_array.count {
            //new_face_array.append([])
            num_array = []
            for _ in 0..<(face_array[index].count) { // / 10)+1 {
                num_array.append([])
            }
            for i in 0..<face_array[index].count {
                let n = Int(face_array[index][i])
                if num_array[n].count == 0 {
                    num_array[n].append(Int(face_array[index][i]))
                    new_face_array[index].append(face_array[index][i])
                }
                else {
                    vertex_array[index].append(vertex_array[index][Int(face_array[index][i])])
                    normal_array[index].append(normal_array[index][Int(face_array[index][i])])
                    texcoords2[index].append(SIMD2<Float>(0, 0))
                    tex_bool[index].append(false)
                    new_face_array[index].append(Int32(vertex_array[index].count - 1))
                }
            }
        }
    }
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat, yoko: Float, num: CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        var tate_count = -1
        for (i,image) in UIImageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func make_texture1000(num: Int) {
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        
//        //RGB画像
//        let uiImage = new_uiimage
//        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
//
//        //内部パラメータ保存用
//        let realm = try! Realm()
//        try! realm.write {
//            results[section_num].cells[cell_num].models[current_model_num].texture_pic = imageData
//        }
        
        let start = Date()
        for i in 0..<count {
            let depth_array = try? decoder.decode([depthPosition].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!)
            let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
            let cameraVector = SCNVector3(json_data!.cameraVector.x,
                                          json_data!.cameraVector.y,
                                          json_data!.cameraVector.z)
            let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                           json_data!.viewMatrix.y,
                                           json_data!.viewMatrix.z,
                                           json_data!.viewMatrix.w)
            let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                 json_data!.projectionMatrix.y,
                                                 json_data!.projectionMatrix.z,
                                                 json_data!.projectionMatrix.w)
            let matrix = projectionMatrix * viewMatrix
            calcTextureCoordinates2000(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector, depthArray: depth_array!, matrix: matrix)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        print("処理時間：\(elapsed)")
        save_model(num: num)
        delete_mesh()
        load_anchor2()
        
        //print(new_texcoords2)
    }
    
    @objc func Alert() {
        let title = "テクスチャ座標計算完了"
        let message = "モデルを表示しますか"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            //save_anchor()
            delete_mesh()
            load_anchor(tex_bool: true)
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    func calcTextureCoordinates2000(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3, depthArray: [depthPosition], matrix: simd_float4x4){
        for (i, mesh_anchor) in anchors.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var perVerticles: [SCNVector3] = []
            var perNormals: [SCNVector3] = []
            var face_count = new_face_array[i].count - 1
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            for j in 0..<faces.count {
                if num == 0 {
                    face_bool[i].append(-1)
                }
                if face_bool[i][j] == -1 {
                    for offset in 0..<faces.indexCountPerPrimitive {
                        let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                        let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                        
                        let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * Int(per_face_index)))
                        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                        let world_vertex4 = simd_mul(mesh_anchor.transform, vertex4)
                        let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                        let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(per_face_index)))
                        let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                        //let inner = normal.x * cameraVector.x + normal.y * cameraVector.y + normal.z * cameraVector.z
                        //let thita = acos(inner) * 180.0 / .pi
                        
                        let clipSpacePosition = matrix * world_vertex4
                        let normalizedDeviceCoordinate = clipSpacePosition / clipSpacePosition.w
                        let pt = SCNVector3((CGFloat(normalizedDeviceCoordinate.x) + 1) * CGFloat(834 / 2),
                                            (-CGFloat(normalizedDeviceCoordinate.y) + 1) * CGFloat(1150 / 2),
                                            1 - (-CGFloat(normalizedDeviceCoordinate.z) + 1))
                        
                        //var pt = sceneView.projectPoint(world_vector3)
                        //print("projectPoint = \(pt), projection = \(projection)")
                        
                        //if thita <= 135 {
                        if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                            let du = Int(round((1 - pt.x / 834) * 95))
                            let dv = Int(round((pt.y / 1150) * 127))
                            let depthPosi = depthArray[du * 128 + dv]
                            let diff = sqrt((world_vector3.x - depthPosi.x)*(world_vector3.x - depthPosi.x) + (world_vector3.y - depthPosi.y)*(world_vector3.y - depthPosi.y) + (world_vector3.z - depthPosi.z)*(world_vector3.z - depthPosi.z))
                            if diff < 0.2 {
                                points.append(pt)
                                points_index.append(Int(per_face_index))
                                perVerticles.append(world_vector3)
                                perNormals.append(normal)
                            }
                        }
                    }
                    
                    if points_index.count == 3 {
                        //face_bool[i][j] = i
                        //print("----------------------------")
                        for (k, p) in points.enumerated() {
                            //print(perNormals[k])
                            face_count += 1
                            let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            new_texcoords2[i].append(SIMD2<Float>(u, v))
                            new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                            new_vertex_array[i].append(perVerticles[k])
                            new_normal_array[i].append(perNormals[k])
                        }
                    }
                    points = []
                    points_index = []
                    perVerticles = []
                    perNormals = []
                }
            }
            
        }
        print("calculate\(num)完了")
    }
    
    //MARK: - その他
    private func build_pointsNode(points: [PointCloudVertex]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: points.count,
            bytesPerIndex: MemoryLayout<Int>.size
        )
        // for bigger dots
        element.pointSize = 1
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 7
        
        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        
        return SCNNode(geometry: pointsGeometry)
    }
        
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
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else {
            load_anchor(tex_bool: false)
        }
    }
    
    @IBAction func to_ARView(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckARViewController") as! CheckARViewController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
