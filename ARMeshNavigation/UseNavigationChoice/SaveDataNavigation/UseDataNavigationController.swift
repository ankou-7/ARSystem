//
//  UseNavigationController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/17.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class UseDataNavigationController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, ARCoachingOverlayViewDelegate, UIGestureRecognizerDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = -1 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var worldImageview: UIImageView!
    //保存したマッピング時の開始画像を表示
    @IBOutlet weak var worldmapping_status: UILabel!
    @IBOutlet weak var load_Button: UIButton!
    
    
    let coachingOverlay = ARCoachingOverlayView()
    var coachi_flag = false
    
    var navi_pictureview: UIImageView! //ナビゲーション画像を表示するエリア
    
    var model_name_array: [String] = []
    var reworld_flag = false
    
    let url_name = [["toy_drummer", "toy_drummer"],
                    ["toy_robot_vintage", "toy_robot_vintage"],
                    ["chair_swan", "chair_swan"],
                    ["toy_biplane", "toy_biplane"],
                    ["tv_retro", "tv_retro"],
                    ["flower_tulip", "flower_tulip"]]
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin] // 検出した3D空間の特徴点を表示する
        //self.view.addSubview(self.sceneView)
        
        //全体を均一な明るさで照らすライトの設定
//        let LightNode = SCNNode()
//        LightNode.light = SCNLight()
//        LightNode.light!.type = .ambient //.omni
//        //LightNode.light?.intensity = 1000
//        LightNode.name = "light"
//        sceneView.scene.rootNode.addChildNode(LightNode)
        
        //特徴点を取るためのコーチングの追加
        coachingOverlay.session = sceneView.session
        coachingOverlay.delegate = self
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal =  .tracking //horizontalPlane,verticalPlane,anyPlane,tracking
        self.view.addSubview(coachingOverlay)
        //ARCoachingOverlayViewを画面の中心に表示させる
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
//        //AR使用のための設定
        let configuration = ARWorldTrackingConfiguration() //Create a session configuration
        configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
        sceneView.session.run(configuration) // Run the view's session
        
//        let realm = try! Realm()
//        let results = realm.objects(Navi_SectionTitle.self)
//        let worlddata = results[section_num].cells[cell_num].models[current_model_num].worlddata
//        let worldimage = results[section_num].cells[cell_num].models[current_model_num].worldimage
//
//        worldImageview.image = worldimage?.toImage()
//
//        DispatchQueue.main.async() {
//            //WoeldMap復元
//            if let worldMap = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worlddata!) {
//                let configuration = ARWorldTrackingConfiguration()
//                configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
//                //sceneView.session.run(configuration) // Run the view's session
//                configuration.initialWorldMap = worldMap //保存したWorldMapで再開する
//                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
//
//                self.reworld_flag = true
//                //self.worldImageview.image = worldimage?.toImage()
//
//            }
//        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func next_load(_ sender: UIButton) {
        DispatchQueue.main.async() {
            print("next_load")
            
            self.coachingOverlay.setActive(true, animated: true)
            
            self.coachi_flag = false
            self.reworld_flag = false
            self.worldImageview.isHidden = false
            self.current_model_num += 1
            self.delete_usdzmodel()
            
            let realm = try! Realm()
            let results = realm.objects(Navi_SectionTitle.self)
            let worlddata = results[self.section_num].cells[self.cell_num].models[self.current_model_num].worlddata
            //let worlddata = UserDefaults.standard.data(forKey: results[self.section_num].cells[self.cell_num].models[self.current_model_num].modelname)
            let worldimage_data = results[self.section_num].cells[self.cell_num].models[self.current_model_num].worldimage
            
            self.worldImageview.image = UIImage(data: worldimage_data!)//worldimage?.toImage()
        
            //WoeldMap復元
            if let worldMap = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worlddata!) {
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
                //sceneView.session.run(configuration) // Run the view's session
                configuration.initialWorldMap = worldMap //保存したWorldMapで再開する
                self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                self.reworld_flag = true
                //self.worldImageview.image = worldimage?.toImage()
                
            }
        }
    }
    
    func coachingOverlayViewWillActivate(_: ARCoachingOverlayView) {
        print("アクティブ前")
    }
    
    //coachingセッションが非アクティブになったとき(WorldMap読み込み完了時)
    func coachingOverlayViewDidDeactivate(_: ARCoachingOverlayView) {
        print("非アクティブ")
        coachi_flag = true //読み込み完了
    }
    
    func delete_usdzmodel() {
        for n in model_name_array {
            let name = n
            if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: false) {
                node.removeFromParentNode()
            }
        }
        model_name_array = []
    }
    
    //フレーム更新毎に呼び出し
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if current_model_num == 1 {
            load_Button.setTitle("Next Load", for: .normal)
        }
        
        
        worldmapping_status.text = "Tracking: \(frame.camera.trackingState.description)"
        
        if coachi_flag == true {
            if reworld_flag == true {
                if frame.camera.trackingState.description == "Normal" {
                    
                    DispatchQueue.main.async() {
                        self.reworld_flag = false
                        self.worldImageview.isHidden = true
                        
                        let realm = try! Realm()
                        let usdz_results = realm.objects(Navi_SectionTitle.self)[self.section_num].cells[self.cell_num].models[self.current_model_num].usdz
                        for usdz in usdz_results {
                            if usdz.usdz_num >= 0 {
                                guard let url = Bundle.main.url(forResource: "art.scnassets/"+self.url_name[usdz.usdz_num][0], withExtension: "usdz") else { return }
                                let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
                                let node = scene1.rootNode.childNode(withName: self.url_name[usdz.usdz_num][1], recursively: true)
                                node?.scale = SCNVector3(0.01, 0.01, 0.01)
                                node?.position = SCNVector3(usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
                                node?.name = usdz.usdz_name
                                self.model_name_array.append((node?.name)!)
                                self.sceneView.scene.rootNode.addChildNode(node!)
                            }
                            else if usdz.usdz_num == -100 {
                                let scene1 = SCNScene(named: "art.scnassets/try.scn")
                                let node = (scene1?.rootNode.childNode(withName: "arrow", recursively: false))!
                                node.position = SCNVector3(usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
                                node.scale = SCNVector3(usdz.usdz_scale_x, usdz.usdz_scale_y, usdz.usdz_scale_z)
                                node.eulerAngles = .init(usdz.usdz_euler_x, usdz.usdz_euler_y, usdz.usdz_euler_z)
                                node.opacity = 0.9
                                node.name = usdz.usdz_name
                                self.model_name_array.append((node.name)!)
                                self.sceneView.scene.rootNode.addChildNode(node)
                            }
                            else if usdz.usdz_num == -50 {
                                let scene1 = SCNScene(named: "art.scnassets/\(usdz.usdz_name).scn")
                                let node = (scene1?.rootNode.childNode(withName: usdz.usdz_name, recursively: false))!
                                node.position = SCNVector3(usdz.usdz_posi_x, usdz.usdz_posi_y, usdz.usdz_posi_z)
                                node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 2.5)))
                                node.opacity = 0.9
                                node.name = usdz.usdz_name
                                self.model_name_array.append((node.name)!)
                                self.sceneView.scene.rootNode.addChildNode(node)

                            }
                        }
                    }
                }
            }
        }
        
//        if let node = sceneView.scene.rootNode.childNode(withName: "light", recursively: false) {
//            node.position = (sceneView.pointOfView?.convertPosition(SCNVector3(0,0,0), to: nil))!
//        }
    }
    //backボタンタップ時に呼び出し
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension ARCamera.TrackingState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Not Available"
        case .limited(.initializing):
            return "Initializing"
        case .limited(.excessiveMotion):
            return "Excessive Motion"
        case .limited(.insufficientFeatures):
            return "Insufficient Features"
        case .limited(.relocalizing):
            return "Relocalizing"
        }
    }
}

