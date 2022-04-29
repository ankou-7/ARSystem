//
//  MapExpansionTransmitController.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class MapExpansionTransmitController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, MCBrowserViewControllerDelegate, MCSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var connectInfoLabel: UILabel! //通信状態を表示するラベル
    @IBOutlet weak var browserButton: UIButton!
    @IBOutlet weak var stop_button: UIButton!
    
    private var pointCloudRenderer: Renderer!
    var pointCloud_flag = false
    
    let serviceType = "ar-collab"

    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    
    var knownAnchors = Dictionary<UUID, SCNNode>()
    var identifier: UUID!
    var meshAnchors_array: [String] = []
    
    var data_array: [PointCloudVertex] = []
    var currentPointCount: Int = 0
    var data_String: String!
    var points_data: Data!
    
    var numGridPoints = 1000
    var maxPoints = 10_000_000
    @IBOutlet weak var numGridPoints_label: UILabel!
    @IBOutlet weak var numGridPoints_slider: UISlider!
    
    
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
        
//        let configuration = ARWorldTrackingConfiguration()
//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
//            configuration.sceneReconstruction = .meshWithClassification
//        }
//        configuration.environmentTexturing = .none
//        configuration.planeDetection = [.horizontal, .vertical]
//        configuration.frameSemantics = .smoothedSceneDepth
//        //self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
//
//        //AR使用のための設定
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        self.stop_button.isHidden = true
        
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
        
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func numGridPoints_slider(_ sender: UISlider) {
        let value = round(sender.value)
        numGridPoints_label.text = "\(Int(value * 100))個/frame"
        numGridPoints = Int(value * 100)
    }
    
    
    @objc func update() {
        if pointCloud_flag == true {
            
//            //点群をData型に変換
//            (currentPointCount, points_data) = pointCloudRenderer.send_Data(num: currentPointCount)
//            guard let d_data = try? NSKeyedArchiver.archivedData(withRootObject: points_data as NSData, requiringSecureCoding: true)
//            else{ return }
//            print("Data点群")
//            print(points_data.count)
//            print(d_data)

            
            //点群をString型に変換
            //print("String点群")
            (currentPointCount, data_String) = pointCloudRenderer.send_Data_String(num: currentPointCount)
//            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: data_String as NSString, requiringSecureCoding: true)
//            else{ return }
            guard let data: Data = data_String.data(using: .utf8) else {
                fatalError("Fail to Decode Text")
            }
            //print("data:\(data)")
            let nsData: NSData = NSData(data: data)
            //print("nsData:\(nsData)")
            guard let compressedData: Data = try? nsData.compressed(using: .zlib) as Data else {
                fatalError("Fail to Compress Data")
            }
            //print("compressedData:\(compressedData)")
            
            guard let t_data = try? NSKeyedArchiver.archivedData(withRootObject: compressedData as NSData, requiringSecureCoding: true)
            else{ return }
            
            try? self.session.send(t_data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if pointCloud_flag == true {
            pointCloudRenderer.draw()
        }
    }
    
    //フレーム更新毎に呼び出し
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    }
    
    @IBAction func showBrowser(_ sender: UIButton) {
        // Show the browser view controller
        self.present(self.browser, animated: true, completion: nil)
    }
    
    @IBAction func stop_button(_ sender: UIButton) {
        self.session.disconnect()
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        //code
        DispatchQueue.main.async() {
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Connecting: \(peerID.displayName)"
                    self.browserButton.isHidden = true
                    self.stop_button.isHidden = false
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    self.connectInfoLabel.text = "Not Connect"
                    self.browserButton.isHidden = false
                    self.stop_button.isHidden = true
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
    
    //メッシュを構築して送信開始
    @IBAction func Start_Transmit(_ sender: UIButton) {
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        configuration.environmentTexturing = .none
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.frameSemantics = .smoothedSceneDepth
        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        
        self.pointCloudRenderer = Renderer(
            session: self.sceneView.session,
            metalDevice: self.sceneView.device!,
            sceneView: self.sceneView)
        self.pointCloudRenderer.drawRectResized(size: self.sceneView.bounds.size)
        self.pointCloudRenderer.numGridPoints = self.numGridPoints
        //self.pointCloudRenderer.maxPoints = self.numGridPoints
        pointCloud_flag = true
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//            for anchor in anchors {
//                var sceneNode : SCNNode?
//
//                if let meshAnchor = anchor as? ARMeshAnchor {
//                    let meshGeo = SCNGeometry.fromAnchor(meshAnchor:meshAnchor)
//                    sceneNode = SCNNode(geometry:meshGeo)
//                }
//
//                if let node = sceneNode {
//                    node.simdTransform = anchor.transform
//                    identifier = anchor.identifier
//                    knownAnchors[anchor.identifier] = node
//                    node.name = "mesh\(meshAnchors_array.count)"
//                    meshAnchors_array.append(node.name!)
//                    sceneView.scene.rootNode.addChildNode(node)
//                }
//            }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let node = knownAnchors[anchor.identifier] {
                    if let meshAnchor = anchor as? ARMeshAnchor {
                        node.geometry = SCNGeometry.fromAnchor(meshAnchor: meshAnchor)
                        
                        //meshAnchorの送信
                        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: meshAnchor, requiringSecureCoding: true)
                        else{ return }
//                        print("mesh")
//                        print(data)
//                        print(data.count)
//                        print(Double(data.count)/1000.0)
                        //try? self.session.send(data as Data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
    
                    }
                    node.simdTransform = anchor.transform
                }
            }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
    }
    
    //backボタンタップ時に呼び出し
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
