//
//  MakeMapViewController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/30.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class MakeMapViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    let scene = SCNScene()
    
    @IBOutlet weak var make_modelButton: UIButton!
    @IBOutlet weak var make_out_modelButton: UIButton!
    var isRecording = false
    var mesh_flag = false
    var parameta_flag = false
    var knownAnchors = Dictionary<UUID, SCNNode>()
    
    let realm = try! Realm()
    var timer: Timer!
    private let orientation = UIInterfaceOrientation.portrait
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.showsStatistics = true // 画面したにfpsなどの情報の表示
        sceneView.debugOptions = [.showWorldOrigin]
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
        
        //パラメータを一時的に保存する場所を初期化
        try! realm.write {
            realm.delete(realm.objects(Data_parameta.self))
        }
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func start_scan(_ sender: UIButton) {
        //スキャン終了時
        if isRecording {
            UIView.animate(withDuration: 0.2) {
                self.make_out_modelButton.layer.cornerRadius = 27.5
                self.make_modelButton.layer.cornerRadius = 25

                self.Alert() //モデル作成部分
            }
        //スキャン開始時
        } else {
            UIView.animate(withDuration: 0.2) {
                self.make_out_modelButton.layer.cornerRadius = 3.0
                self.make_modelButton.layer.cornerRadius = 3.0
                
                let configuration = ARWorldTrackingConfiguration()
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    configuration.sceneReconstruction = .meshWithClassification
                }
                configuration.environmentTexturing = .none
                configuration.planeDetection = [.horizontal, .vertical]
                configuration.frameSemantics = .smoothedSceneDepth
                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
                
                //メッシュ構築開始
                self.mesh_flag = true
                self.parameta_flag = true
                
                //内部パラメータ保存用
                let results = self.realm.objects(Data_parameta.self)
                let objName = "Model\(results.count)"
                try! self.realm.write {
                    self.realm.add(Data_parameta(value: ["modelname": objName]))
                }
            }
        }
        isRecording = !isRecording
    }
    
    @objc func Alert() {
        //var alertTextField: UITextField?
        let title = "マッピング完了"
        let message = "終了する場合は終了ボタンを押して下さい。"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            //self.Make_mesh_obj() //モデルを書き込み
            self.delete_mesh()
            
            let results = realm.objects(Data_parameta.self)
            //print(results)
            //print(results[results.count-1].pic)
            
            self.mesh_flag = false
            self.parameta_flag = false
            
            to_AddTextureModelController()
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    func delete_mesh() {
        guard let anchors = sceneView.session.currentFrame?.anchors else { return }
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
    }
    
    func to_AddTextureModelController() {
        let storyboard = UIStoryboard(name: "MakeMap", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddTextureModelController") as! AddTextureModelController
        vc.view.backgroundColor = UIColor.white
        vc.modalPresentationStyle = .fullScreen
        
        guard let anchors = sceneView.session.currentFrame?.anchors else { return }
        vc.anchors = anchors
        
        self.present(vc, animated: true, completion: nil)
    }
    
    @objc func update() {
        if parameta_flag == true {
            guard let frame = self.sceneView.session.currentFrame else {
                fatalError("Couldn't get the current ARFrame")
            }
            //2D → 3D変換用の内部パラメータ
            let camera = frame.camera
            
            let cameraIntrinsics = camera.intrinsics.inverse
            let flipYZ = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, -1, 0],
                [0, 0, 0, 1] )
            let viewMatrix = camera.viewMatrix(for: orientation).inverse * flipYZ
            
            if let camera = self.sceneView.pointOfView {
                let cameraPosition = camera.position
                let cameraEulerAngles = camera.eulerAngles
                let T = camera.transform
                
                //RGB画像
                let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
                let uiImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
                let imageData = uiImage.jpegData(compressionQuality: 0.5) //toJPEGData()
                
                let entity = json_parameta(Intrinsics:
                                            Vector33Entity(x: cameraIntrinsics.columns.0,
                                                           y: cameraIntrinsics.columns.1,
                                                           z: cameraIntrinsics.columns.2),
                                           ViewMatrix:
                                            Vector44Entity(x: viewMatrix.columns.0,
                                                           y: viewMatrix.columns.1,
                                                           z: viewMatrix.columns.2,
                                                           w: viewMatrix.columns.3),
                                           cameraPosition:
                                            Vector3Entity(x: cameraPosition.x,
                                                          y: cameraPosition.y,
                                                          z: cameraPosition.z),
                                           cameraEulerAngles:
                                            Vector3Entity(x: cameraEulerAngles.x,
                                                          y: cameraEulerAngles.y,
                                                          z: cameraEulerAngles.z),
                                           cameraTransform:
                                            Vector44Entity(x: SIMD4<Float>(T.m11, T.m12, T.m13, T.m14),
                                                           y: SIMD4<Float>(T.m21, T.m22, T.m23, T.m24),
                                                           z: SIMD4<Float>(T.m31, T.m32, T.m33, T.m34),
                                                           w: SIMD4<Float>(T.m41, T.m42, T.m43, T.m44)))
                
                let json_data = try! JSONEncoder().encode(entity)
                
                let results = realm.objects(Data_parameta.self)
                save_jpeg(filename: "try_\(results[results.count-1].pic.count)", jpegData: imageData!, jsonData: json_data)
            }
        }
    }
    
    //パラメータ保存
    func save_jpeg(filename: String, jpegData: Data, jsonData: Data) {
        let realm = try! Realm()
        let results = realm.objects(Data_parameta.self)
        try! realm.write {
            results[results.count-1].pic.append(pic_data(value: ["pic_name": "rgb_\(filename)",
                                                                      "pic_data": jpegData]))
            results[results.count-1].json.append(json_data(value: ["json_name": "\(filename)",
                                                                      "json_data": jsonData]))
        }
    }
    
    //フレーム更新毎に呼び出し
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if mesh_flag == true {
            for anchor in anchors {
                var sceneNode : SCNNode?
                
                if let meshAnchor = anchor as? ARMeshAnchor {
                    let meshGeo = SCNGeometry.fromAnchor(meshAnchor:meshAnchor)
                    sceneNode = SCNNode(geometry:meshGeo)
                }
                
                if let node = sceneNode {
                    node.simdTransform = anchor.transform
                    knownAnchors[anchor.identifier] = node
                    node.name = "mesh" //"mesh\(meshAnchors_array.count)"
                    sceneView.scene.rootNode.addChildNode(node)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if mesh_flag == true {
            for anchor in anchors {
                if let node = knownAnchors[anchor.identifier] {
                    if let meshAnchor = anchor as? ARMeshAnchor {
                        node.geometry = SCNGeometry.fromAnchor(meshAnchor: meshAnchor)
                    }
                    node.simdTransform = anchor.transform
                }
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
    
    @IBAction func back(_ sender: UIButton) {
        //timer.invalidate()
        self.dismiss(animated: true, completion: nil)
    }
}


struct json_parameta: Codable {
    var Intrinsics: Vector33Entity
    var ViewMatrix: Vector44Entity
    
    var cameraPosition: Vector3Entity
    var cameraEulerAngles: Vector3Entity
    var cameraTransform: Vector44Entity
}
