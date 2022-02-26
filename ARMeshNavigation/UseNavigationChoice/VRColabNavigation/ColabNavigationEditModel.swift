//
//  ColabNavigationEditModel.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2020/11/23.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class ColabNavigationEditModel: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    var lastGestureScale: Float = 0.0
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var left_arrowButton: UIButton!
    @IBOutlet weak var right_arrowButton: UIButton!
    
    @IBOutlet weak var gobutton: UIButton!
    @IBOutlet weak var backbutton: UIButton!
    @IBOutlet weak var leftbutton: UIButton!
    @IBOutlet weak var rightbutton: UIButton!
    @IBOutlet weak var upbutton: UIButton!
    @IBOutlet weak var downbutton: UIButton!
    @IBOutlet weak var rightroll: UIButton!
    @IBOutlet weak var leftroll: UIButton!
    
    @IBOutlet weak var movelabel1: UILabel!
    @IBOutlet weak var movelabel2: UILabel!
    @IBOutlet weak var movelabel3: UILabel!
    
    @IBOutlet weak var arrow_button: UIButton! //矢印オブジェクト配置用のボタン
    @IBOutlet weak var object_button: UIButton!
    
    @IBOutlet weak var browser_button: UIButton!
    @IBOutlet weak var reload_button: UIButton!
    @IBOutlet weak var sendworlddata_button: UIButton!
    
    @IBOutlet weak var connectInfo_label: UILabel!
    @IBOutlet weak var cameraImage_view: UIImageView!
    @IBOutlet weak var jusin_status: UILabel!
    
    var camera_sta = false
    
    //ナビゲーションエリア
    @IBOutlet weak var navi_view: UIVisualEffectView!
    @IBOutlet weak var navi_straightButton: UIButton!
    @IBOutlet weak var navi_leftButton: UIButton!
    @IBOutlet weak var navi_rightButton: UIButton!
    @IBOutlet weak var navi_goButton: UIButton!
    @IBOutlet weak var navi_stopButton: UIButton!
    @IBOutlet weak var navi_waitButoon: UIButton!
    
    
    var flash_button_count = 0
    var plus_flag = false
    var model_posi: SCNVector3!
    let url_name = [["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip","arrow"],
    ["arrow", "arrow2", "arrow3"]]
    var usdz_num: [Int] = [-100, -100]
    var usdzInfo: [(id_name: String,
                    usdz_name: String,
                    usdz_num: Int,
                    usdz_posi_x: Float,
                    usdz_posi_y: Float,
                    usdz_posi_z: Float)] = []
    
    var arrowInfo: [[(arrow_name: String,
                    arrow_posi_x: Float,
                    arrow_posi_y: Float,
                    arrow_posi_z: Float,
                    arrow_scale_x: Float,
                    arrow_scale_y: Float,
                    arrow_scale_z: Float,
                    arrow_euler_x: Float,
                    arrow_euler_y: Float,
                    arrow_euler_z: Float)]] = [[]]
    
    var moveNode_name = ""
    
    var all_pic = SCNNode()
    
    var button_flag = false
    var current_kakudo_y: Float = 0.0
    var current_kakudo_x: Float = 0.0
    var current_image: UIImage!
    
    let serviceType = "ar-collab"

    @objc var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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

        rightbutton.isHidden = true
        leftbutton.isHidden = true
        gobutton.isHidden = true
        backbutton.isHidden = true
        upbutton.isHidden = true
        downbutton.isHidden = true
        rightroll.isHidden = true
        leftroll.isHidden = true
        
        movelabel1.isHidden = true
        movelabel2.isHidden = true
        movelabel3.isHidden = true

        arrow_button.isHidden = true
        object_button.isHidden = true
        reload_button.isHidden = true
        sendworlddata_button.isHidden = true
        jusin_status.isHidden = true
        //browser_button.isHidden = true
        
        cameraImage_view.isHidden = true
        
        //ナビゲーション表示エリアを隠す
        navi_view.isHidden = true
        navi_straightButton.isHidden = true
        navi_leftButton.isHidden = true
        navi_rightButton.isHidden = true
        navi_goButton.isHidden = true
        navi_stopButton.isHidden = true
        navi_waitButoon.isHidden = true
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        let cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.5)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        //lightNode.position = SCNVector3(x: 0, y: 10, z: -10)
        scene.rootNode.addChildNode(lightNode)
        
        sceneView.delegate = self //delegateのセット
        
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self

        // create the browser viewcontroller with a unique service name
        self.browser = MCBrowserViewController(serviceType:serviceType,
                                               session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                               discoveryInfo:nil, session:self.session)

        // tell the assistant to start advertising our fabulous chat
        self.assistant.start()
        
    }
    
    //遷移時に指定したセル番号から.objファイルをロード
    override func viewDidAppear(_ animated: Bool) {
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname

        self.database_model_num = results[section_num].cells[cell_num].models.count
        for _ in 1..<database_model_num {
            arrowInfo.append([])
        }
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
    
//    @objc func re_haiti() {
//        let realm = try! Realm()
//        let results = realm.objects(Navi_SectionTitle.self)
//
//        for pic in results[section_num].cells[cell_num].models[current_model_num].pic {
//            let picturePlane = SCNPlane(width: 0.5, height: 0.5)
//            picturePlane.firstMaterial?.diffuse.contents = pic.picturedata.toImage()
//            //picturePlane.firstMaterial?.transparency = 0.5
//            let node = SCNNode(geometry: picturePlane)
//            node.position = SCNVector3(pic.posi_x, pic.posi_y, pic.posi_z)
//            node.eulerAngles = SCNVector3(pic.euler_x, pic.euler_y, pic.euler_z)
//            node.scale = SCNVector3(pic.scale_x, pic.scale_y, pic.scale_z)
//            node.opacity = 0.5
//            all_pic.addChildNode(node)
//        }
//
//        all_pic.name = "all_pic"
//        //all_pic.opacity = 0.5
//        scene.rootNode.addChildNode(all_pic)
//    }
    
    //MARK: -オブジェクト配置用
    //画面タップ時に呼び出し
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        //オブジェクト配置用の時
        //if current_mode_num == 1 {
        //DispatchQueue.main.async { [self] in
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
                        guard let url = Bundle.main.url(forResource: "art.scnassets/"+url_name[0][usdz_num[1]], withExtension: "usdz") else { return }
                        let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
                        let node = scene1.rootNode.childNode(withName: url_name[0][usdz_num[1]], recursively: true)
                        node?.scale = SCNVector3(0.01, 0.01, 0.01)
                        node?.position = posi
                        node!.name = "usdz2" + String(usdzInfo.count)
                        //sceneView.scene!.rootNode.addChildNode(node!)
                        scene.rootNode.addChildNode(node!)
                        
                        let tuple_youso = (node!.name!, url_name[usdz_num[0]][usdz_num[1]], usdz_num[1], posi.x, posi.y, posi.z)
                        usdzInfo.append(tuple_youso)
                        print(usdzInfo)
                        
                        //配置時に送信
                        let str = "usdzInfo2:\(node!.name!):\(usdz_num[1]):\(node!.position.x):\(node!.position.y):\(node!.position.z)"
                        
                        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
                        else{ return }
                        do {
                            try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                        } catch {
                            print(error)
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
                    
                    else if usdz_num[0] == 1 {
                        //２回目以降のオブジェクト配置時に配列に情報を格納しておく
                        if arrowInfo[current_model_num].last?.0 != moveNode_name {
                            if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
                                let scale = node.scale
                                let posi = node.position
                                let euler = node.eulerAngles
                                let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
                                arrowInfo[current_model_num].append(tuple_youso)
                                print(arrowInfo[current_model_num])
                            }
                        }
                        
                        let scene1 = SCNScene(named: "art.scnassets/try.scn")
                        let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
                        node.position = posi //SCNVector3(0, 0, 0)
                        node.scale = SCNVector3(0.3, 0.3, 0.3)
                        node.eulerAngles = .init(-Float.pi/2, 0, -Float.pi/2)
                        node.opacity = 0.9
                        node.name = "arrow" + String(arrowInfo[current_model_num].count)
                        //print(node.name)
                        moveNode_name = node.name!
                        scene.rootNode.addChildNode(node)
                        
                        //配置時に送信
                        let str = "arrowInfo:\(node.name!):\(node.scale.x):\(node.scale.y):\(node.scale.z):\(node.position.x):\(node.position.y):\(node.position.z):\(node.eulerAngles.x):\(node.eulerAngles.y):\(node.eulerAngles.z)"

                        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
                        else{ return }
                        do {
                            print("arrowInfo送信")
                            try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        //}
    }
    
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
            //self.object_hyouji_view.image = UIImage(named: self.url_name[sec_num][cell_num])
        }
        
        if plus_flag == false {
            self.plus_flag = true
        }
        
        present(contentVC, animated: true, completion: nil)
    }
    
    
    @IBAction func arrow_object_haiti(_ sender: UIButton) {
        self.usdz_num[0] = 1
        if plus_flag == false {
            self.plus_flag = true
        }
        
//        //２回目以降のオブジェクト配置時に配列に情報を格納しておく
//        if arrowInfo[current_model_num].last?.0 != moveNode_name {
//            if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
//                let scale = node.scale
//                let posi = node.position
//                let euler = node.eulerAngles
//                let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
//                arrowInfo[current_model_num].append(tuple_youso)
//                print(arrowInfo[current_model_num])
//            }
//        }
//
//        let scene1 = SCNScene(named: "art.scnassets/try.scn")
//        let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
//        node.position = SCNVector3(0, 0, 0)
//        node.scale = SCNVector3(0.3, 0.3, 0.3)
//        node.eulerAngles = .init(-Float.pi/2, 0, -Float.pi/2)
//        node.opacity = 0.9
//        node.name = "arrow" + String(arrowInfo[current_model_num].count)
//        //print(node.name)
//        moveNode_name = node.name!
//        scene.rootNode.addChildNode(node)
        
//        let now = Date()
//        let formatter: DateFormatter = DateFormatter()
//        formatter.calendar = Calendar(identifier: .gregorian)
//        formatter.dateFormat = "yyyy:MM:dd:HH:mm:ss.SSS:Z"
//        let dateString = formatter.string(from: now)
//        print(dateString)
//        guard let date = try? NSKeyedArchiver.archivedData(withRootObject: "date:1:"+dateString as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(date as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
        
//        //配置時に送信
//        let str = "arrowInfo:\(node.name!):\(node.scale.x):\(node.scale.y):\(node.scale.z):\(node.position.x):\(node.position.y):\(node.position.z):\(node.eulerAngles.x):\(node.eulerAngles.y):\(node.eulerAngles.z):date:1:\(dateString)"
//
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
//        else{ return }
//        do {
//            print("arrowInfo送信")
//            try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//        } catch {
//            print(error)
//        }
        
    }
    
    //配置したオブジェクトの場所を更新して送信
    @IBAction func reload_object_place(_ sender: Any) {
        if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
            let str = "arrowInfo:\(node.name!):\(node.scale.x):\(node.scale.y):\(node.scale.z):\(node.position.x):\(node.position.y):\(node.position.z):\(node.eulerAngles.x):\(node.eulerAngles.y):\(node.eulerAngles.z)"
            
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
            else{ return }
            do {
                //print("arrowInfo送信")
                try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
            } catch {
                print(error)
            }
        }
    }
    
    
//    @IBAction func send_navi_go(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:go" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
//
//    @IBAction func send_navi_stop(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:stop" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
//
//    @IBAction func send_navi_wait(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:wait" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
//
//
//    @IBAction func send_navi_straight(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:arrow" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
//
//    @IBAction func send_navi_left(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:arrow2" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
//
//    @IBAction func send_navi_right(_ sender: Any) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "ナビゲーション指示:arrow3" as NSString, requiringSecureCoding: true)
//        else{ return }
//        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//    }
    
    
    @IBAction func send_worlddata(_ sender: Any) {
        guard let data2 = try? NSKeyedArchiver.archivedData(withRootObject: "worldimage送信中:" as NSString, requiringSecureCoding: true)
        else{ return }
        try? self.session.send(data2 as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let worldimagedata = results[section_num].cells[cell_num].models[current_model_num].worldimage
        
        let worldImage_string: String = worldimagedata!.base64EncodedString(options: [])
        
        let send_world_image = "WorldImage送信:\(worldImage_string)"
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: send_world_image as NSString, requiringSecureCoding: true)
        else{ return }
        
        do {
            print("送信")
//            try self.session.send(worlddata! as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
            try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
        } catch {
            print(error)
        }
    }
    
    @IBAction func showBrowser(_ sender: Any) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
//        let responseString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
//        if let imageData = Data(base64Encoded: responseString, options: []) {
//            let image = UIImage(data: imageData) // --> これを表示する
//            DispatchQueue.main.async {
//                self.cameraImage_view.image = image
//            }
//        }
        
        do {
            if let str = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                if let node = sceneView.scene!.rootNode.childNode(withName: "camera_ball", recursively: false) {
                    node.removeFromParentNode()
                }
                let all_str = str as String
                let str_array = all_str.components(separatedBy: ":")
                //print(str_array)
                if str_array[0] == "worldimage受信" {
                    DispatchQueue.main.async {
                        self.jusin_status.text = "worldimage受信"
                    
                        let realm = try! Realm()
                        let results = realm.objects(Navi_SectionTitle.self)
                        let worlddata = results[self.section_num].cells[self.cell_num].models[self.current_model_num].worlddata
                        //worldmap送信
                        try? self.session.send(worlddata! as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                        
                    }
                }
                else if str_array[0] == "worldmap受信" {
                    DispatchQueue.main.async {
                        self.worldmap_sousin_alert()
                        self.jusin_status.text = "worldimap受信"
                    }
                }
                else if str_array[0] == "worldmap復元完了" {
                    DispatchQueue.main.async {
                        self.re_worldmap_jusin_alert()
                        
                        //startなどのオブジェクト情報を送信
                        let realm = try! Realm()
                        let results = realm.objects(Navi_SectionTitle.self)
//                        let usdzInfo = results[self.section_num].cells[self.cell_num].models[self.current_model_num].usdz
//                        for usdz in usdzInfo {
//                            if usdz.usdz_num == -50 {
//                                let str = "usdzInfo:\(usdz.usdz_name):\(usdz.usdz_posi_x):\(usdz.usdz_posi_y):\(usdz.usdz_posi_z)"
//
//                                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
//                                else{ return }
//                                try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//                            }
//                        }
                    }
                }
                
                else if str_array[0] == "cameraImage" {
                    let data = Data(base64Encoded: str_array[1], options: [])
                    DispatchQueue.main.async {
                        self.cameraImage_view.image = UIImage(data: data!)//data!.toImage()
                    }
                }
                
                else if str_array[0] == "camera_posi" {
                    if let node = sceneView.scene!.rootNode.childNode(withName: "iphone", recursively: false) {
                        node.position = SCNVector3(Float(str_array[1])!, Float(str_array[2])!, Float(str_array[3])!)
                    }
                }
                else if str_array[0] == "カウント" {
                    let scene1 = SCNScene(named: "art.scnassets/try.scn")
                    let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
                    node.position = SCNVector3(0, 0, 0)
                    node.scale = SCNVector3(0.3, 0.3, 0.3)
                    node.eulerAngles = .init(-Float.pi/2, 0, -Float.pi/2)
                    node.opacity = 0.9
                    node.name = "arrow" + String(arrowInfo[current_model_num].count)
                    //print(node.name)
                    moveNode_name = node.name!
                    scene.rootNode.addChildNode(node)
                    
                    let now = Date()
                    let formatter: DateFormatter = DateFormatter()
                    formatter.calendar = Calendar(identifier: .gregorian)
                    formatter.dateFormat = "yyyy:MM:dd:HH:mm:ss.SSS:Z"
                    let dateString = formatter.string(from: now)
                    print(dateString)
                    
                    let next_count = Int(str_array[1])!+1
                    print(next_count)
                    if next_count <= 10000 {
                        //配置時に送信
                        let str = "arrowInfo:\(node.name!):\(node.scale.x):\(node.scale.y):\(node.scale.z):\(node.position.x):\(node.position.y):\(node.position.z):\(node.eulerAngles.x):\(node.eulerAngles.y):\(node.eulerAngles.z):date:\(next_count):\(dateString)"

                        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: str as NSString, requiringSecureCoding: true)
                        else{ return }
                        do {
                            print("arrowInfo送信")
                            try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        } catch {
            print("can't decode data recieved from \(peerID.displayName)")
        }
        
    }
    
    func worldmap_sousin_alert() {
        let title = "WorldMap送信完了"
        let message = "相手端末がWorldMapを読み込むまでお待ちください。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) {_ in
            //code
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func re_worldmap_jusin_alert() {
        let title = "相手端末のWorldMap復元完了"
        let message = "ナビゲーションを行ってください。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) {_ in
            //code
            self.cameraImage_view.isHidden = false
            guard let url = Bundle.main.url(forResource: "art.scnassets/Apple", withExtension: "usdc") else { return }
            let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
            let node = scene1.rootNode.childNode(withName: "RootNode__gltf_orientation_matrix_", recursively: true)
            node!.position = SCNVector3(0,0,0)
            node!.eulerAngles.x = -90*Float.pi/180
            node!.scale = .init(0.001, 0.001, 0.001)
            node!.name = "iphone"
            self.scene.rootNode.addChildNode(node!)
        })
        self.present(alertController, animated: true, completion: nil)
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
    
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        //code
        DispatchQueue.main.async() { [self] in
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    self.connectInfo_label.text = "Connecting: \(peerID.displayName)"
                    
                    rightbutton.isHidden = false
                    leftbutton.isHidden = false
                    gobutton.isHidden = false
                    backbutton.isHidden = false
                    upbutton.isHidden = false
                    downbutton.isHidden = false
                    rightroll.isHidden = false
                    leftroll.isHidden = false
                    
                    movelabel1.isHidden = false
                    movelabel2.isHidden = false
                    movelabel3.isHidden = false

                    arrow_button.isHidden = false
                    object_button.isHidden = false
                    reload_button.isHidden = false
                    sendworlddata_button.isHidden = false
                    jusin_status.isHidden = false
                    browser_button.isHidden = true
                    
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    self.connectInfo_label.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    self.connectInfo_label.text = "Not Connect"
                @unknown default:
                    self.connectInfo_label.text = "Not Connect"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        //code
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        //code
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        //code
    }
    
    func object_re_haiti() {
        if arrowInfo[current_model_num].count > 0 {
            for info in arrowInfo[current_model_num] {
                print(info)
                let scene1 = SCNScene(named: "art.scnassets/try.scn")
                let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
                node.position = SCNVector3(info.arrow_posi_x, info.arrow_posi_y, info.arrow_posi_z)
                node.scale = SCNVector3(info.arrow_scale_x, info.arrow_scale_y, info.arrow_scale_z)
                node.eulerAngles = .init(info.arrow_euler_x, info.arrow_euler_y, info.arrow_euler_z)
                node.opacity = 0.9
                node.name = info.arrow_name
                scene.rootNode.addChildNode(node)
            }
        }
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
            if let node = sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
                node.removeFromParentNode()
                all_pic = SCNNode()
            }
            
            //print(arrowInfo[current_model_num].last?.0 as Any)
            
            //２回目以降のオブジェクト配置時に配列に情報を格納しておく
            if arrowInfo[current_model_num].last?.0 != moveNode_name {
                if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
                    let scale = node.scale
                    let posi = node.position
                    let euler = node.eulerAngles
                    let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
                    arrowInfo[current_model_num].append(tuple_youso)
                }
            }
            
            if arrowInfo[current_model_num].count > 0 {
                for info in arrowInfo[current_model_num] {
                    let name = info.arrow_name
                    if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                        node.removeFromParentNode()
                    }
                }
            }
            
            //print(arrowInfo)
            
            current_model_num += 1
            moveNode_name = ""
            model_kirikae_hyouji()
            object_re_haiti()
            //re_haiti()
        }
    }
    
    @IBAction func left_modelButton(_ sender: UIButton) {
        if current_model_num > 0 {
            if let node = sceneView.scene!.rootNode.childNode(withName: "all_pic", recursively: false) {
                node.removeFromParentNode()
                all_pic = SCNNode()
            }
            
            //print(arrowInfo[current_model_num])
            //２回目以降のオブジェクト配置時に配列に情報を格納しておく
            if arrowInfo[current_model_num].last?.0 != moveNode_name {
                if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
                    let scale = node.scale
                    let posi = node.position
                    let euler = node.eulerAngles
                    let tuple_youso = (node.name!, posi.x, posi.y, posi.z, scale.x, scale.y, scale.z, euler.x, euler.y, euler.z)
                    arrowInfo[current_model_num].append(tuple_youso)
                }
            }

            if arrowInfo[current_model_num].count > 0 {
                for info in arrowInfo[current_model_num] {
                    let name = info.arrow_name
                    if let node = sceneView.scene!.rootNode.childNode(withName: name, recursively: false) {
                        node.removeFromParentNode()
                    }
                }
            }

            current_model_num -= 1
            moveNode_name = ""
            model_kirikae_hyouji()
            object_re_haiti()
            //re_haiti()
        }
    }
    
    func model_kirikae_hyouji() {
        if let node = sceneView.scene!.rootNode.childNode(withName: "obj", recursively: false) {
            node.removeFromParentNode()
        }
        
        //print(current_model_num)
        
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
        
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.x += -sin(self.current_kakudo_x - (90*Float.pi)/180) / 10000
                    node.position.z += cos(self.current_kakudo_x - (90*Float.pi)/180) / 10000
                    self.goButton()
                }
            }
        }
    }
    @objc func backButton() {
        button_flag = true
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.x += -sin(self.current_kakudo_x + (90*Float.pi)/180) / 10000
                    node.position.z += cos(self.current_kakudo_x + (90*Float.pi)/180) / 10000
                    self.backButton()
                }
            }
        }
    }
    @objc func rightButton() {
        button_flag = true
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.x += -sin(self.current_kakudo_x) / 10000
                    node.position.z += cos(self.current_kakudo_x) / 10000
                    self.rightButton()
                }
            }
        }
    }
    @objc func leftButton() {
        button_flag = true
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.position.x -= -sin(self.current_kakudo_x) / 10000
                    node.position.z -= cos(self.current_kakudo_x) / 10000
                    self.leftButton()
                }
            }
        }
    }
    @objc func upButton() {
        button_flag = true
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
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.eulerAngles.x -= 0.008 * (Float.pi / 180)
                    self.rightRollButton()
                }
            }
        }
    }
    @objc func leftRollButton() {
        button_flag = true
        DispatchQueue.main.async {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: self.moveNode_name, recursively: false) {
                if self.button_flag == true {
                    node.eulerAngles.x += 0.008 * (Float.pi / 180)
                    self.leftRollButton()
                }
            }
        }
    }
    
    @objc func releaseButton() {
        button_flag = false
    }
    
    //フレーム更新毎に呼び出し
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if let node = sceneView.scene!.rootNode.childNode(withName: moveNode_name, recursively: false) {
            self.current_kakudo_x = node.eulerAngles.x
        }
        
        DispatchQueue.main.async {
            if self.current_model_num == 0 {
                self.left_arrowButton.isHidden = true
            }
            else {
                self.left_arrowButton.isHidden = false
            }
            
            if self.current_model_num == self.database_model_num-1 {
                self.right_arrowButton.isHidden = true
            }
            else {
                self.right_arrowButton.isHidden = false
            }
        }
        
    }
    
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        
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
