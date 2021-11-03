//
//  ColabNavigationController.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2020/11/22.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class ARColabNavigationController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate, ARCoachingOverlayViewDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var connectInfoLabel: UILabel! //通信状態を表示するラベル
    @IBOutlet weak var worldmapping_status: UILabel!
    @IBOutlet weak var browserButton: UIButton!
    
    @IBOutlet weak var navi_pictureview: UIImageView! //ナビゲーション画像を表示するエリア
    @IBOutlet weak var worldImageview: UIImageView!
    
    let coachingOverlay = ARCoachingOverlayView()
    
    var current_section_num = Int()
    var current_cell_num = Int()
    var current_model_num = Int()
    var model_name_array: [String] = []
    
    var kakudo: Float = 1000.0 //ModelOperationControllerで指定した位置の角度を格納する変数
    var left: Float = 0.0
    var right: Float = 0.0
    var hantai: Float = 0.0
    
    var reworld_flag = false
    
//    let url_name = [["toy_drummer", "toy_drummer"],
//                    ["toy_robot_vintage", "toy_robot_vintage"],
//                    ["chair_swan", "chair_swan"],
//                    ["toy_biplane", "toy_biplane"],
//                    ["tv_retro", "tv_retro"],
//                    ["flower_tulip", "flower_tulip"]]
    let url_name = [["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip"],
    ["arrow", "arrow2", "arrow3"]]
    
    let serviceType = "ar-collab"

    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        //sceneViewを定義
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.showsStatistics = true // 画面したにfpsなどの情報の表示
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin] // 検出した3D空間の特徴点を表示する
        //self.view.addSubview(self.sceneView)
        
        //AR使用のための設定
        let configuration = ARWorldTrackingConfiguration() //Create a session configuration
        configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
        sceneView.session.run(configuration) // Run the view's session
        
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
        
//        // 作成するテキストファイルの名前
//        let textFileName = "date.txt"
//        let initialText = "date"
//
//        // DocumentディレクトリのfileURLを取得
//        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
//            // ディレクトリのパスにファイル名をつなげてファイルのフルパスを作る
//            let targetTextFilePath = documentDirectoryFileURL.appendingPathComponent(textFileName)
//            UserDefaults.standard.set(targetTextFilePath, forKey: "datePath")
//            do {
//                try initialText.write(to: targetTextFilePath, atomically: true, encoding: String.Encoding.utf8)
//            } catch let error as NSError {
//                print("failed to write: \(error)")
//            }
//        }
        
        //特徴点を取るためのコーチングの追加
        coachingOverlay.session = sceneView.session
        coachingOverlay.delegate = self
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlay.activatesAutomatically = false
        coachingOverlay.goal =  .tracking //horizontalPlane,verticalPlane,anyPlane,tracking
        self.view.addSubview(coachingOverlay)
        //ARCoachingOverlayViewを画面の中心に表示させる
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func update() {
        guard let frame = sceneView.session.currentFrame else {
            //fatalError("Couldn't get the current ARFrame")
            return
        }

        let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
        let cgImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
        if let imageData = cgImage.jpegData(compressionQuality: 0.25) {
            let encodeString:String = imageData.base64EncodedString(options: [])
            let camera_image_string = "cameraImage:\(encodeString)"
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: camera_image_string as NSString, requiringSecureCoding: true)
            else{ return }
            do {
                try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
            } catch {
                print(error)
            }
        }
    }
    
    //フレーム更新毎に呼び出し
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        worldmapping_status.text = "Tracking: \(frame.camera.trackingState.description)"
        if reworld_flag == true {
            if frame.camera.trackingState.description == "Normal" {
                DispatchQueue.main.async {
                    self.coachingOverlay.setActive(false, animated: true)
                    
                    self.re_worldmap_complete_alert()
                    self.reworld_flag = false
                    self.worldImageview.isHidden = true
                    self.browserButton.isHidden = true
                
                    guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "worldmap復元完了:" as NSString, requiringSecureCoding: true)
                    else{ return }
                    try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                }
            }
        }
        
        if frame.camera.trackingState.description != "Normal" {
            browserButton.isHidden = false
        }
        
        if let camera = sceneView.pointOfView { // カメラを取得
            let camera_posi_str = "camera_posi:\(String(camera.position.x)):\(String(camera.position.y)):\(String(camera.position.z))"
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: camera_posi_str as NSString, requiringSecureCoding: true)
            else{ return }
            do {
                //print("camera_posi送信")
                try self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
            } catch {
                print(error)
            }
        }
        
        
//        let currentTransform = frame.camera.eulerAngles
//        var nipi: Float = 0.0 //0~360に変換した端末の角度を格納
//        if (currentTransform.y*180)/Float.pi > 0 {
//            nipi = (currentTransform.y*180)/Float.pi
//        }
//        else {
//            nipi = 180 + (180 + (currentTransform.y*180)/Float.pi)
//        }
        //let re_kakudo = (currentTransform.y*180)/Float.pi - self.kakudo //指定された角度を基準にした位置からの角度
        
//        if self.kakudo != 1000.0 {
//            self.navi_pictureview.isHidden = false
//
//            if (left > 0 && left < 90) && (right < 360 && right > 270) {
//                if nipi > left && nipi < hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if nipi < right && nipi > hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > 0) || (nipi < 360 && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 0 && left < 90) && (right > 0 && right < 90) {
//                if nipi > left && nipi < hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if (nipi < right && nipi > 0) || (nipi < 360 && nipi > hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 90 && left < 180) && (right < 90 && right > 0) {
//                if nipi > left && nipi < hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if (nipi < right && nipi > 0) || (nipi < 360 && nipi > hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 90 && left < 180) && (right > 90 && right < 180) {
//                if nipi > left && nipi < hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if (nipi < right && nipi > 0) || (nipi < 360 && nipi > hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 180 && left < 270) && (right > 90 && right < 180) && (hantai < 360 && hantai > 270) {
//                if nipi > left && nipi < hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if (nipi < right && nipi > 0) || (nipi < 360 && nipi > hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 180 && left < 270) && (right > 90 && right < 180) && (hantai > 0 && hantai < 90) {
//                if (nipi > left && nipi < 360) || (nipi > 0 && nipi < hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if (nipi < right && nipi > hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 180 && left < 270) && (right > 180 && right < 270) {
//                if (nipi > left && nipi < 360) || (nipi > 0 && nipi < hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if nipi < right && nipi > hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 270 && left < 360) && (right > 180 && right < 270) {
//                if (nipi > left && nipi < 360) || (nipi > 0 && nipi < hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if nipi < right && nipi > hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
//            else if (left > 270 && left < 360) && (right > 270 && right < 360) {
//                if (nipi > left && nipi < 360) || (nipi > 0 && nipi < hantai) {
//                    self.navi_pictureview.image = UIImage(named: "arrow3") //右
//                }
//                else if nipi < right && nipi > hantai {
//                    self.navi_pictureview.image = UIImage(named: "arrow2") //左
//                }
//                else if (nipi < left && nipi > right) {
//                    self.navi_pictureview.image = UIImage(named: "arrow") //正面
//                }
//            }
            
//        }

    }
    
    @IBAction func showBrowser(_ sender: UIButton) {
            // Show the browser view controller
            self.present(self.browser, animated: true, completion: nil)
        }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //start,change,goalオブジェクトを切り替えるさいに、前の部分を消す
    func delete_usdzmodel() {
        if model_name_array.count > 0 {
            for n in model_name_array {
                let name = n
                if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            model_name_array = []
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        //code
//        if let image = UIImage(data: data){
//            print("worldimage受信")
//            DispatchQueue.main.async {
//                self.worldImageview.image = image
//            }
//        }
        
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                DispatchQueue.main.async {
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = [.horizontal, .vertical]
                    configuration.initialWorldMap = worldMap //保存したWorldMapで再開する
                    self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                    print("worldmap受信")
                    guard let data2 = try? NSKeyedArchiver.archivedData(withRootObject: "worldmap受信:" as NSString, requiringSecureCoding: true)
                    else{ return }
                    try? self.session.send(data2 as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                    
                    self.worldmap_jusin_alert()
                    
                }
            }
            else if let str = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                
                print("str受信")
                //print(str as String)
                let all_str = str as String
                let str_array = all_str.components(separatedBy: ":")
                
                if str_array[0] == "worldimage送信中" {
                    DispatchQueue.main.async {
                        self.wait_worldmap_jusin_alert()
                        //表示したオブジェクトを削除
                        self.delete_usdzmodel()
                    }
                }
                else if str_array[0] == "WorldImage送信" {
                    let data = Data(base64Encoded: str_array[1], options: [])
                    DispatchQueue.main.async {
                        self.worldImageview.isHidden = false
                        self.worldImageview.image = UIImage(data: data!)//data!.toImage()
                        
                        guard let data2 = try? NSKeyedArchiver.archivedData(withRootObject: "worldimage受信:" as NSString, requiringSecureCoding: true)
                        else{ return }
                        try? self.session.send(data2 as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
                    }
                }
//                else if str_array[0] == "date" {
//                    let dateString = "\(str_array[1])/\(str_array[2])/\(str_array[3]) \(str_array[4]):\(str_array[5]):\(str_array[6]).\(str_array[7]) \(str_array[8])"
//                    let formatter: DateFormatter = DateFormatter()
//                    formatter.calendar = Calendar(identifier: .gregorian)
//                    formatter.dateFormat = "yyyy/MM/dd HH:mm:ss.SSS Z"
//                    let date = formatter.date(from: dateString)!
//                    print("送信：\(dateString)")
                    
//                }
                
                else if str_array[0] == "usdzInfo2" {
                    print(str_array)
                    DispatchQueue.main.async { [self] in
                        guard let url = Bundle.main.url(forResource: "art.scnassets/"+url_name[0][Int(str_array[2])!], withExtension: "usdz") else { return }
                        let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
                        let node = (scene1.rootNode.childNode(withName: url_name[0][Int(str_array[2])!], recursively: false))!
                        node.scale = SCNVector3(0.01, 0.01, 0.01)
                        node.position = SCNVector3(Float(str_array[3])!, Float(str_array[4])!, Float(str_array[5])!)
                        node.name = str_array[1]
                        self.model_name_array.append((node.name)!)
                        self.sceneView.scene.rootNode.addChildNode(node)
                    }
                }
                else if str_array[0] == "arrowInfo" {
                    if let node = sceneView.scene.rootNode.childNode(withName: str_array[1], recursively: false) {
                        node.removeFromParentNode()
                    }
                    let scene1 = SCNScene(named: "art.scnassets/try.scn")
                    let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
                    node.scale = SCNVector3(Float(str_array[2])!, Float(str_array[3])!, Float(str_array[4])!)
                    node.position = SCNVector3(Float(str_array[5])!, Float(str_array[6])!, Float(str_array[7])!)
                    node.eulerAngles = .init(Float(str_array[8])!, Float(str_array[9])!, Float(str_array[10])!)
                    node.opacity = 0.9
                    node.name = str_array[1]
                    self.model_name_array.append((node.name)!)
                    sceneView.scene.rootNode.addChildNode(node)
                    
//                    let now = Date()
//                    let formatter2: DateFormatter = DateFormatter()
//                    formatter2.calendar = Calendar(identifier: .gregorian)
//                    formatter2.dateFormat = "yyyy:MM:dd:HH:mm:ss.SSS:Z"
//                    let dateString_now = formatter2.string(from: now)
//
//                    print("カウント\(str_array[12])")
//                    print("送信時：\(str_array[11...19])")
//                    print("現在：\(dateString_now)")
//
//                    let array = dateString_now.components(separatedBy: ":")
//                    let sa = String(Double(array[5])! - Double(str_array[18])!)
//                    print("差：\(sa)")
//
//                    let path = UserDefaults.standard.url(forKey: "datePath")
//                    do {
//                        let fileHandle = try FileHandle(forWritingTo: path!)
//                        let stringToWrite = "\n" + sa // 改行を入れる
//                        fileHandle.seekToEndOfFile() // ファイルの最後に追記
//                        fileHandle.write(stringToWrite.data(using: String.Encoding.utf8)!)
//
//                        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: "カウント:\(str_array[12])" as NSString, requiringSecureCoding: true)
//                        else{ return }
//                        try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
//                    } catch let error as NSError {
//                        print("failed to append: \(error)")
//                    }
                }
//                else if str_array[0] == "ナビゲーション指示" {
//                    print(str_array)
//                    if str_array[1] == "go" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "Go")
//                        }
//                    }
//                    else if str_array[1] == "stop" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "Stop")
//                        }
//                    }
//                    else if str_array[1] == "wait" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "Wait")
//                        }
//                    }
//                    else if str_array[1] == "arrow" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "w_arrow")
//                        }
//                    }
//                    else if str_array[1] == "arrow2" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "w_arrow2")
//                        }
//                    }
//                    else if str_array[1] == "arrow3" {
//                        DispatchQueue.main.async {
//                            self.navi_pictureview.image = UIImage(named: "w_arrow3")
//                        }
//                    }
//                }
                else if str_array[0] == "usdzInfo" {
//                    guard let url = Bundle.main.url(forResource: "art.scnassets/"+url_name[Int(str_array[3])!][0], withExtension: "usdz") else { return }
//                    let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
//                    let node = scene1.rootNode.childNode(withName: url_name[Int(str_array[3])!][1], recursively: true)
//                    node?.scale = SCNVector3(0.01, 0.01, 0.01)
//                    node?.position = SCNVector3(Float(str_array[4])!, Float(str_array[5])!, Float(str_array[6])!)
//                    node!.name = str_array[1]
//                    sceneView.scene.rootNode.addChildNode(node!)
                    DispatchQueue.main.async {
                        let scene1 = SCNScene(named: "art.scnassets/\(str_array[1]).scn")
                        let node = (scene1?.rootNode.childNode(withName: str_array[1], recursively: false))!
                        node.position = SCNVector3(Float(str_array[2])!, Float(str_array[3])!, Float(str_array[4])!)
                        node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 2.5)))
                        node.opacity = 0.9
                        node.name = str_array[1]
                        self.model_name_array.append((node.name)!)
                        self.sceneView.scene.rootNode.addChildNode(node)
                    }
                }
                else if str_array[0] == "navi_info" {
                    kakudo = Float(str_array[1])!
                    
                    left = kakudo + 50.0
                    if left > 360.0 {
                        left = left - 360.0
                    }
                    
                    right = kakudo - 50.0
                    if right < 0.0 {
                        right = 360.0 + right
                    }
                    
                    hantai = kakudo + 180.0
                    if hantai > 360.0 {
                        hantai = hantai - 360.0
                    }
                    
                }
            }
            else {
                print("unknown data recieved from \(peerID.displayName)")
            }
        } catch {
            print("can't decode data recieved from \(peerID.displayName)")
        }
    }
    
    func wait_worldmap_jusin_alert() {
        let title = "WorldMap受信中"
        let message = "WorldMapの受信が完了するまで待機してください。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) {_ in
            //code
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func worldmap_jusin_alert() {
        let title = "WorldMap受信完了"
        let message = "左上の画像を元にマッピングを行いWorldMapの復元を行ってください。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) {_ in
            self.reworld_flag = true
            self.coachingOverlay.setActive(true, animated: true)
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func re_worldmap_complete_alert() {
        let title = "WorldMap復元完了"
        let message = "表示されるナビゲーションにしたがって進んでください。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) {_ in
            //code
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        //code
        DispatchQueue.main.async() {
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Not Connect"
                @unknown default:
                    self.connectInfoLabel.text = "Not Connect"
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
    
    //backボタンタップ時に呼び出し
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
