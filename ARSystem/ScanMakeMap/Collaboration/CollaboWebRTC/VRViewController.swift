//
//  VRViewController.swift
//  ARSystem
//
//  Created by yasue kouki on 2022/04/30.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import WebRTC

class VRViewController: UIViewController {
    
    private let config = Config.default
    private var signalClient: SignalingClient!
    private var webRTCClient: WebRTCClient!
    
    @IBOutlet weak var signalingStatusLabel: UILabel!
    @IBOutlet weak var localSdpStatusLabel: UILabel!
    @IBOutlet weak var localCandidatesLabel: UILabel!
    @IBOutlet weak var remoteSdpStatusLabel: UILabel!
    @IBOutlet weak var remoteCandidatesLabel: UILabel!
    @IBOutlet weak var webRTCStatusLabel: UILabel!
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var audioButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    let results = try! Realm().objects(Navi_SectionTitle.self)
    var anchors = [ARMeshAnchor]()
    
    var state = "受信前"
    var meshCount = 0
    var dataCount = 0
    var vertexCount = 0
    var DataArray = [Data]()
    let tex_node = SCNNode()
    var texImage: UIImage!
    @IBOutlet weak var imageView: UIImageView!
    
    private var videoStatus: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.videoStatus {
                    self.videoButton.setImage(UIImage(systemName: "video.fill"), for: .normal)
                    self.videoButton.tintColor = UIColor.blue
                    self.videoView.isHidden = false
                }
                else {
                    self.videoButton.setImage(UIImage(systemName: "video.slash.fill"), for: .normal)
                    self.videoButton.tintColor = UIColor.red
                    self.videoView.isHidden = true
                }
            }
        }
    }
    
    private var audioStatus: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.audioStatus {
                    self.audioButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
                    self.audioButton.tintColor = UIColor.blue
                    self.webRTCClient.unmuteAudio()
                }
                else {
                    self.audioButton.setImage(UIImage(systemName: "mic.slash.circle.fill"), for: .normal)
                    self.audioButton.tintColor = UIColor.red
                    self.webRTCClient.muteAudio()
                }
            }
        }
    }
    
    private var speakerStatus: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.speakerStatus {
                    self.speakerButton.setImage(UIImage(systemName: "speaker.circle.fill"), for: .normal)
                    self.speakerButton.tintColor = UIColor.blue
                    self.webRTCClient.speakerOn()
                }
                else {
                    self.speakerButton.setImage(UIImage(systemName: "speaker.slash.circle.fill"), for: .normal)
                    self.speakerButton.tintColor = UIColor.red
                    self.webRTCClient.speakerOff()
                }
            }
        }
    }
    
    private var signalingConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.signalingConnected {
                    self.signalingStatusLabel?.text = "Connected"
                    self.signalingStatusLabel?.textColor = UIColor.green
                }
                else {
                    self.signalingStatusLabel?.text = "Not connected"
                    self.signalingStatusLabel?.textColor = UIColor.red
                }
            }
        }
    }
    
    private var hasLocalSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.localSdpStatusLabel?.text = self.hasLocalSdp ? "✅" : "❌"
            }
        }
    }
    
    private var localCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.localCandidatesLabel?.text = "\(self.localCandidateCount)"
            }
        }
    }
    
    private var hasRemoteSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.remoteSdpStatusLabel?.text = self.hasRemoteSdp ? "✅" : "❌"
            }
        }
    }
    
    private var remoteCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.remoteCandidatesLabel?.text = "\(self.remoteCandidateCount)"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.signalingConnected = false
        self.hasLocalSdp = false
        self.hasRemoteSdp = false
        self.localCandidateCount = 0
        self.remoteCandidateCount = 0
        self.webRTCStatusLabel?.text = "New"
        self.videoView.isHidden = true
        self.videoStatus = false
        self.audioStatus = false
        self.speakerStatus = false
        
        webRTCClient = WebRTCClient(iceServers: self.config.webRTCIceServers)
        signalClient = SignalingClient(webSocket: NativeWebSocket(url: self.config.signalingServerUrl))
        
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
        self.signalClient.connect()
        
        //ビデオ設定
        let localRenderer = RTCMTLVideoView(frame: self.videoView?.frame ?? CGRect.zero)
        let remoteRenderer = RTCMTLVideoView(frame: self.videoView!.frame)//self.view.frame)
        localRenderer.videoContentMode = .scaleAspectFill
        remoteRenderer.videoContentMode = .scaleAspectFill

        self.webRTCClient.startCaptureLocalVideo(renderer: localRenderer)
        self.webRTCClient.renderRemoteVideo(to: remoteRenderer)
        
//        if let localVideoView = self.videoView {
//            self.embedView(localRenderer, into: localVideoView)
//        }
        self.embedView(remoteRenderer, into: self.videoView)
//        self.view.sendSubviewToBack(remoteRenderer)
        
        
        //メッシュ表示
        sceneView.scene = scene
        
        if results.count > 0 {
            let models = results[0].cells[1].models[0]
            for i in 0..<models.mesh_anchor.count {
                let mesh_data = models.mesh_anchor[i].mesh
                if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                    anchors.append(meshAnchor)
                }
            }
            let meshNode = BuildMeshNode(anchors: anchors)
            meshNode.name = "meshNode"
            sceneView.scene?.rootNode.addChildNode(meshNode)
        }
    }
    
    @IBAction func sendDidTap(_ sender: UIButton) {
        print("sendDidTap")
        let models = results[0].cells[1].models[0]
        
        guard let typeData = try? NSKeyedArchiver.archivedData(withRootObject: "メッシュ送信開始:\(anchors.count)" as NSString, requiringSecureCoding: true) else {
            return
        }
        self.webRTCClient.sendData(typeData)
        
//        print(models.texture_pic)
//        if models.texture_pic != nil {
//            print("pic送信")
//            self.webRTCClient.sendData(models.texture_pic!)
//        }
        
        //メッシュData
        for i in 0..<anchors.count {
            let vertexData = models.mesh_anchor[i].vertices!
            let normalData = models.mesh_anchor[i].normals!
            //let counts = models.mesh_anchor[i].vertice_count
            let facesData = models.mesh_anchor[i].faces!
            let texcoordsData = models.mesh_anchor[i].texcoords!
            
            guard let countData = try? NSKeyedArchiver.archivedData(withRootObject: "頂点数:\(models.mesh_anchor[i].vertice_count)" as NSString, requiringSecureCoding: true)
            else { return }
//            guard let countData = "\(count)".data(using: .utf8) else {
//                return
//            }
            print("/////////////////////")
            print(models.mesh_anchor[i].vertice_count)
            print(vertexData)
            print(normalData)
            print(facesData)
            print(texcoordsData)
            
            self.webRTCClient.sendData(countData)
            self.webRTCClient.sendData(vertexData)
            self.webRTCClient.sendData(normalData)
            self.webRTCClient.sendData(facesData)
            self.webRTCClient.sendData(texcoordsData)
        }
        
        guard let finishData = try? NSKeyedArchiver.archivedData(withRootObject: "送信終了)" as NSString, requiringSecureCoding: true) else {
            return
        }
        self.webRTCClient.sendData(finishData)
    }
    
    @IBAction func offerDidTap(_ sender: UIButton) {
        self.webRTCClient.offer { (sdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: sdp)
        }
    }
    
    @IBAction func answerDidTap(_ sender: UIButton) {
        self.webRTCClient.answer { (localSdp) in
            self.hasLocalSdp = true
            self.signalClient.send(sdp: localSdp)
        }
    }
    
    @IBAction func videoDidTap(_ sender: UIButton) {
        self.videoStatus.toggle()
        
        //to_VIdeoView(sender)
    }
    
    @IBAction func audioDidTap(_ sender: UIButton) {
        self.audioStatus.toggle()
    }
    
    @IBAction func speakerDidTap(_ sender: UIButton) {
        self.speakerStatus.toggle()
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension VRViewController: SignalClientDelegate {
    
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.signalingConnected = false
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("Received remote sdp")
        self.webRTCClient.set(remoteSdp: sdp) { (error) in
            self.hasRemoteSdp = true
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            print("Received remote candidate")
            self.remoteCandidateCount += 1
        }
    }
}

extension VRViewController: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("discovered local candidate")
        self.localCandidateCount += 1
        self.signalClient.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        let textColor: UIColor
        switch state {
        case .connected, .completed:
            textColor = .green
        case .disconnected:
            textColor = .orange
        case .failed, .closed:
            textColor = .red
        case .new, .checking, .count:
            textColor = .black
        @unknown default:
            textColor = .black
        }
        DispatchQueue.main.async {
            self.webRTCStatusLabel?.text = state.description.capitalized
            self.webRTCStatusLabel?.textColor = textColor
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        DispatchQueue.main.async { [self] in
            print("送信データ:\(data)")
            do {
                //print("state:\(state)")
                if state == "受信前" {
                    let typeString = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data)
                    print(typeString!)
                    let strArray = typeString!.components(separatedBy: ":")
                    state = strArray[0] as String
                    meshCount = Int(strArray[1])!
                    print("state:\(state)")
                    print("meshCount:\(meshCount)")
                }
                else if state == "メッシュ送信開始" {
                    dataCount += 1
                    print(dataCount)
                    
                    if dataCount == 0 {
                        print("pic")
                        texImage = UIImage(data: data)!
                        imageView.image = texImage
                    } else if dataCount == 1 {
                        vertexCount = 0
                        DataArray = []
                        do {
                            let countString = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data)
                            let strArray = countString!.components(separatedBy: ":")
                            vertexCount = Int(strArray[1])!
                            print(strArray[0])
                            print(vertexCount)
                        } catch {
                            print(error.localizedDescription)
                            print("error2")
                        }
//                        let count = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
//                        print(count)
//                        vertexCount = Int(count as String)!
                        
                    } else {
                        DataArray.append(data)
                        print(DataArray)
                        if dataCount == 5 {
                            sceneView.scene?.rootNode.addChildNode(build(count: vertexCount, DataArray: DataArray))
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
                }
            } catch {
                print("error")
            }
        }
            
//            let message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
//            let alert = UIAlertController(title: "Message from WebRTC", message: message, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
//            self.present(alert, animated: true, completion: nil)
        
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
}
