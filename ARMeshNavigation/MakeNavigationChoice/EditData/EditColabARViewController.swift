//
//  EditColabARViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/02/18.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class EditColabARViewController: UIViewController, ARSCNViewDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate, ARSessionDelegate, ARCoachingOverlayViewDelegate {
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
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    colabInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    colabInfoLabel.text = "Not Connect"
                @unknown default:
                    colabInfoLabel.text = "Not Connect"
            }
        }
    }
    
    var state = "受信前"
    var dataCount = 0
    var DataArray = [Data]()
    var objectStringArray = [String]()
    var choiceObjectName = ""
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [self] in
            do {
                print("state:\(state)")
                if state == "受信前" {
                    if let stateData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                        state = stateData as String
                    }
                } else if state == "ワールドマップ送信開始" {
                    dataCount += 1
                    self.coachingOverlay.setActive(true, animated: true)
                    if dataCount == 1 {
                        let image = UIImage(data: data)!
                        imageView.image = image
                    } else if dataCount == 2 {
                        if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                            DispatchQueue.main.async {
                                let configuration = ARWorldTrackingConfiguration()
                                configuration.planeDetection = [.horizontal, .vertical]
                                configuration.initialWorldMap = worldMap
                                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                                self.coachingOverlay.setActive(false, animated: true)
                                imageView.isHidden = true
                            }
                        }
                        dataCount = 0
                        state = "送信待機中"
                    }
                } else if state == "送信待機中" {
                    DataArray = []
                    if let stateData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                        state = stateData as String
                    }
                } else if state == "オブジェクト配置情報送信開始" {
                    dataCount += 1
                    if dataCount == 1 {
                        if let StringData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                            objectStringArray = StringData.components(separatedBy: ":")
                        }
                    } else if dataCount == 2 {
                        dataCount = 0
                        ObjectPlacement(infoArray: objectStringArray, infoData: data)
                        state = "送信待機中"
                    }
                } else if state == "オブジェクト操作情報送信開始" {
                    dataCount += 1
                    if dataCount == 1 {
                        if let StringData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                            choiceObjectName = StringData as String
                        }
                    } else if dataCount == 2 {
                        dataCount = 0
                        print(choiceObjectName)
                        ObjectOperate(choiceObject: choiceObjectName, infoData: data)
                        state = "送信待機中"
                    }
                } else if state == "オブジェクト削除情報送信開始" {
                    dataCount += 1
                    if dataCount == 1 {
                        if let StringData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                            choiceObjectName = StringData as String
                            dataCount = 0
                            ObjectDelete(choiceObject: choiceObjectName)
                            state = "送信待機中"
                        }
                    }
                } else if state == "オブジェクト遠隔サポート情報送信開始" {
                    dataCount += 1
                    if dataCount == 1{
                        DataArray.append(data)
                    } else if dataCount == 2 {
                        DataArray.append(data)
                        dataCount = 0
                        remoteSupportObjectPlacement(infoData_array: DataArray)
                        state = "送信待機中"
                    }
                }
            } catch {
                print("can't decode data recieved from \(peerID.displayName)")
            }
        }
    }
    
    //遠隔サポート用の矢印，マーカ配置処理
    func remoteSupportObjectPlacement(infoData_array: [Data]) {
        let arrowNode = SCNNode()
        arrowNode.name = "all_arrow"
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        let startPoint_scene = SCNScene(named: "art.scnassets/startPoint.scn")
        let startPoint_node = (startPoint_scene?.rootNode.childNode(withName: "startPoint", recursively: false))!
        let info = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData_array[0])
        startPoint_node.scale = SCNVector3(info.Scale.x, info.Scale.y, info.Scale.z)
        startPoint_node.position = SCNVector3(info.Position.x, info.Position.y, info.Position.z)
        startPoint_node.eulerAngles = SCNVector3(info.EulerAngles.x, info.EulerAngles.y, info.EulerAngles.z)
        startPoint_node.constraints = [billboardConstraint]
        startPoint_node.name = "startPoint"
        arrowNode.addChildNode(startPoint_node)
        
        let endPoint_scene = SCNScene(named: "art.scnassets/endPoint.scn")
        let endPoint_node = (endPoint_scene?.rootNode.childNode(withName: "endPoint", recursively: false))!
        let info2 = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData_array[1])
        endPoint_node.scale = SCNVector3(info2.Scale.x, info2.Scale.y, info2.Scale.z)
        endPoint_node.position = SCNVector3(info2.Position.x, info2.Position.y, info2.Position.z)
        endPoint_node.eulerAngles = SCNVector3(info2.EulerAngles.x, info2.EulerAngles.y, info2.EulerAngles.z)
        endPoint_node.constraints = [billboardConstraint]
        endPoint_node.name = "startPoint"
        arrowNode.addChildNode(endPoint_node)
        
        var diffPointCoord: SCNVector3! //原点に対する終点の座標
        diffPointCoord = SCNVector3(endPoint_node.position.x - startPoint_node.position.x, endPoint_node.position.y - startPoint_node.position.y, endPoint_node.position.z - startPoint_node.position.z)
        
        let thita_xz: Float = atan(diffPointCoord.z / diffPointCoord.x)
        let thita_zy: Float = atan(diffPointCoord.y / diffPointCoord.z)
        let thita_xy: Float = atan(diffPointCoord.y / diffPointCoord.x)
         
        var arrow_y: Float = 0
        if diffPointCoord.x >= 0 {
            arrow_y = -1.57 - thita_xz
        } else if diffPointCoord.x < 0 {
            arrow_y = 1.57 - thita_xz
        }
        
        var arrow_x: Float = 0
        if diffPointCoord.y <= 0 && diffPointCoord.z >= 0 && diffPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_zy
        } else if diffPointCoord.y <= 0 && diffPointCoord.z < 0 && diffPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_xy
        } else if diffPointCoord.y <= 0 && diffPointCoord.z >= 0 && diffPointCoord.x < 0 {
            arrow_x = -1.57 - thita_xy
        } else if diffPointCoord.y <= 0 && diffPointCoord.z < 0 && diffPointCoord.x < 0 {
            arrow_x = -1.57 - thita_zy
        }
        else if diffPointCoord.y > 0 && diffPointCoord.z >= 0 && diffPointCoord.x < 0 {
            arrow_x = -1.57 - thita_xy
        } else if diffPointCoord.y > 0 && diffPointCoord.z < 0 && diffPointCoord.x < 0 {
            arrow_x = -1.57 - thita_zy
        } else if diffPointCoord.y > 0 && diffPointCoord.z >= 0 && diffPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_zy
        } else if diffPointCoord.y > 0 && diffPointCoord.z < 0 && diffPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_xy
        }
        
        let distance = sqrt(diffPointCoord.x * diffPointCoord.x + diffPointCoord.y * diffPointCoord.y + diffPointCoord.z * diffPointCoord.z)
        let num = Int((distance * 100 ) / 20)
        let s: Float = 1/3
        
        for i in 1..<num {
            let posi = SCNVector3((startPoint_node.position.x + Float(i) * diffPointCoord.x * s) - (diffPointCoord.x * 0.2),
                                  (startPoint_node.position.y + Float(i) * diffPointCoord.y * s) - (diffPointCoord.y * 0.2),
                                  (startPoint_node.position.z + Float(i) * diffPointCoord.z * s) - (diffPointCoord.z * 0.2))
            let scene = SCNScene(named: "art.scnassets/arrow.scn")
            let node = (scene?.rootNode.childNode(withName: "arrow", recursively: false))!
            node.position = posi
            node.scale = SCNVector3(0.1, 0.1, 0.1)
            node.eulerAngles.y = arrow_y
            node.eulerAngles.x = arrow_x
            node.name = "child_arrow"
            arrowNode.addChildNode(node)
            
            let now_dis = sqrt((Float(i+1) * diffPointCoord.x * s) * (Float(i+1) * diffPointCoord.x * s) +
                               (Float(i+1) * diffPointCoord.y * s) * (Float(i+1) * diffPointCoord.y * s) +
                               (Float(i+1) * diffPointCoord.z * s) * (Float(i+1) * diffPointCoord.z * s))
            if now_dis > distance {
                break
            }
        }
        
        sceneView.scene.rootNode.addChildNode(arrowNode)
    }
    
    //オブジェクト配置処理
    func ObjectPlacement(infoArray: [String], infoData: Data) {
        var node = SCNNode()
        if infoArray[2] == "usdz" {
            guard let url = Bundle.main.url(forResource: "art.scnassets/\(infoArray[0])", withExtension: "usdz") else { return }
            let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
            node = scene.rootNode.childNode(withName: infoArray[0], recursively: true)!
        } else if infoArray[2] == "scn" {
            let scene = SCNScene(named: "art.scnassets/arrow.scn")
            node = (scene?.rootNode.childNode(withName: "arrow", recursively: false))!
            node.scale = SCNVector3(0.1, 0.1, 0.1)
            node.eulerAngles = SCNVector3(0, 0, 0)
        }
        let info = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData)
        node.scale = SCNVector3(info.Scale.x, info.Scale.y, info.Scale.z)
        node.position = SCNVector3(info.Position.x, info.Position.y, info.Position.z)
        node.eulerAngles = SCNVector3(info.EulerAngles.x, info.EulerAngles.y, info.EulerAngles.z)
        node.name = infoArray[1]
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    //配置されたオブジェクトの操作処理
    func ObjectOperate(choiceObject: String, infoData: Data) {
        if let node = sceneView.scene.rootNode.childNode(withName: choiceObject, recursively: false) {
            let info = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData)
            node.scale = SCNVector3(info.Scale.x, info.Scale.y, info.Scale.z)
            node.position = SCNVector3(info.Position.x, info.Position.y, info.Position.z)
            node.eulerAngles = SCNVector3(info.EulerAngles.x, info.EulerAngles.y, info.EulerAngles.z)
        }
    }
    
    //配置したオブジェクトの削除処理
    func ObjectDelete(choiceObject: String) {
        if let node = sceneView.scene.rootNode.childNode(withName: choiceObject, recursively: false) {
            node.removeFromParentNode()
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var imageView: UIImageView!
    
    let coachingOverlay = ARCoachingOverlayView()
    
    let serviceType = "ar-collab"
    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    @IBOutlet weak var colabInfoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.debugOptions = [.showWorldOrigin]
        
        sceneView.autoenablesDefaultLighting = true
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        
        
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self

        self.browser = MCBrowserViewController(serviceType:serviceType,
                                               session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                               discoveryInfo:nil, session:self.session)

        self.assistant.start()
        
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
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func serchBrowser(_ sender: UIButton) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
