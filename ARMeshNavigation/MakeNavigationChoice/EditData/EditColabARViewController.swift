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
                }
            } catch {
                print("can't decode data recieved from \(peerID.displayName)")
            }
        }
    }
    
    //オブジェクト配置処理
    func ObjectPlacement(infoArray: [String], infoData: Data) {
        guard let url = Bundle.main.url(forResource: "art.scnassets/\(infoArray[0])", withExtension: "usdz") else { return }
        let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
        let node = scene.rootNode.childNode(withName: infoArray[0], recursively: true)
        let info = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData)
        node?.scale = SCNVector3(info.Scale.x, info.Scale.y, info.Scale.z)
        node?.position = SCNVector3(info.Position.x, info.Position.y, info.Position.z)
        node?.eulerAngles = SCNVector3(info.EulerAngles.x, info.EulerAngles.y, info.EulerAngles.z)
        node!.name = infoArray[1]
        sceneView.scene.rootNode.addChildNode(node!)
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
