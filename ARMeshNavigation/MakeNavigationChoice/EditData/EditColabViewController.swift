//
//  EditColabViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/02/18.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class EditColabViewController: UIViewController, ARSCNViewDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {
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
    var meshCount = 0
    var dataCount = -1
    var vertexCount = 0
    var DataArray = [Data]()
    let tex_node = SCNNode()
    
    var objectStringArray = [String]()
    var choiceObjectName = ""
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        //print("受信")
        DispatchQueue.main.async { [self] in
            do {
                print("state:\(state)")
                if state == "受信前" {
                    if let stateData = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                        let strArray = stateData.components(separatedBy: ":")
                        state = strArray[0] as String
                        meshCount = Int(strArray[1])!
                        print("state:\(state)")
                        print("meshCount:\(meshCount)")
                    }
                } else if state == "メッシュ送信開始" {
                    dataCount += 1
        
                    if dataCount == 0 {
                        texImage = UIImage(data: data)!
                        //imageView.image = texImage
                    } else if dataCount == 1 {
                        vertexCount = 0
                        DataArray = []
                        if let count = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                            vertexCount = Int(count as String)!
                        }
                    } else {
                        DataArray.append(data)
                        if dataCount == 5 {
                            tex_node.addChildNode(build(count: vertexCount, DataArray: DataArray))
                            dataCount = 0
                            meshCount -= 1
                            print("meshCount:\(meshCount)")
                            if meshCount == 0 {
                                sceneView.scene?.rootNode.addChildNode(tex_node)
                                state = "送信待機中"
                            }
                        }
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
    
    func build(count: Int, DataArray: [Data]) -> SCNNode {
        let verticeSource = SCNGeometrySource(
            data: DataArray[0],
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        let normalSource = SCNGeometrySource(
            data: DataArray[1],
            semantic: SCNGeometrySource.Semantic.normal,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        let faceSource = SCNGeometryElement(indices: (try? JSONDecoder().decode([Int32].self, from: DataArray[2]))!, primitiveType: .triangles)
        let textureCoordinates = SCNGeometrySource(textureCoordinates: (try? JSONDecoder().decode([SIMD2<Float>].self, from: DataArray[3]))!)
        
        let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
        nodeGeometry.firstMaterial?.diffuse.contents = texImage
        
        let node = SCNNode(geometry: nodeGeometry)
        
        return node
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
        sceneView.scene!.rootNode.addChildNode(node!)
    }
    
    //配置されたオブジェクトの操作処理
    func ObjectOperate(choiceObject: String, infoData: Data) {
        if let node = sceneView.scene?.rootNode.childNode(withName: choiceObject, recursively: false) {
            let info = try! JSONDecoder().decode(ObjectInfo_data.self, from: infoData)
            node.scale = SCNVector3(info.Scale.x, info.Scale.y, info.Scale.z)
            node.position = SCNVector3(info.Position.x, info.Position.y, info.Position.z)
            node.eulerAngles = SCNVector3(info.EulerAngles.x, info.EulerAngles.y, info.EulerAngles.z)
        }
    }
    
    //配置したオブジェクトの削除処理
    func ObjectDelete(choiceObject: String) {
        if let node = sceneView.scene?.rootNode.childNode(withName: choiceObject, recursively: false) {
            node.removeFromParentNode()
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    @IBOutlet weak var imageView: UIImageView!
    var texImage = UIImage()
    
    let serviceType = "ar-collab"

    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    @IBOutlet weak var colabInfoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        scene.rootNode.addChildNode(lightNode)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self

        self.browser = MCBrowserViewController(serviceType:serviceType,
                                               session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                               discoveryInfo:nil, session:self.session)

        self.assistant.start()

    }
    
    @IBAction func serchBrowser(_ sender: UIButton) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    @IBAction func to_ARView(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "EditColabARViewController") as! EditColabARViewController
//        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
