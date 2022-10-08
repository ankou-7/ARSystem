//
//  MakeNavigationController.swift
//  ARMesh
//
//  Created by 安江洸希 on 2020/11/15.
//

import UIKit
import SceneKit
import RealityKit
import ARKit
import RealmSwift
import AVFoundation
import Photos
import AssetsLibrary
import SVProgressHUD

class MakeNavigationController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ARCoachingOverlayViewDelegate {
    
    //    //画面遷移した際のsectionとcellの番号を格納
    //    var section_num = Int()
    //    var cell_num = Int()
    
    var url: URL!
    
    var restart_flag = false
    let coachingOverlay = ARCoachingOverlayView()
    var restartCalucuMatrix: [float4x4] = []
    
    @IBOutlet weak var sceneView: ARSCNView!
    let scene = SCNScene()
    var configuration = ARWorldTrackingConfiguration()
    
    @IBOutlet weak var modelView: SCNView!
    
    private var pointCloudRenderer: Renderer!
    private var depth_pointCloudRenderer: depth_Renderer!
    var pointCloud_flag = false
    var numGridPoints = 1000
    @IBOutlet weak var numGridPoints_label: UILabel!
    @IBOutlet weak var numGridPoints_slider: UISlider!
    
    var mesh_flag = false
    
    var menu_array: [Bool] = [] //メニューの設定
    //メッシュや点群を表示するときは1を入れる
    var exit_mesh_num = 0
    var exit_point_num = 0
    var exit_parameta = 0
    
    @IBOutlet weak var make_modelButton: UIButton!
    @IBOutlet weak var make_out_modelButton: UIButton!
    
    var isRecording = false
    var recording_count = -1 //何回スキャンを行なったか(マップ作成ボタンを押した数)
    
    var current_imageData: Data?
    var current_worlddata: Data!
    var push_buttonCount = 0
    
    var knownAnchors = Dictionary<UUID, SCNNode>()
    var meshAnchors_array: [String] = []
    var texcoords2: [[SIMD2<Float>]] = []
    
    var jpeg_count = 0
    var parameta_flag = false
    
    private let orientation = UIInterfaceOrientation.portrait
    @IBOutlet weak var depthImage: UIImageView!
    
    //metal用のRendererのインスタンス
    private var renderer: Renderer!
    private let session = ARSession()
    
    var timer: Timer!
    
    var depth_flag = false
    
    //マッピング支援機構の動作設定
    @IBOutlet weak var mapping_label: UILabel!
    var mapping_flag = true
    
    var mappingSupportFlag = false
    @IBOutlet weak var takeParametaCountLabel: UILabel!
    var parametaCount = 0
    var meshCount = 0
    
    var saveFilename = "保存前"
    
    var remap_flag = false
    var remapAnchors = [ARMeshAnchor]()
    
    var mapping_mesh_flag = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.scene = scene
        sceneView.debugOptions = .showWorldOrigin
        
        modelView.scene = scene
        
//        //realm初期化
//        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            let realm = try! Realm(fileURL: url.appendingPathComponent("try.realm"))
//        }
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        //パラメータを一時的に保存する場所を初期化
        let realm = try! Realm()
        try! realm.write {
            realm.delete(realm.objects(Navityu.self))
            realm.delete(realm.objects(Data_parameta.self))
        }
        
        removeDirectory()
        
        let viewModel = MenuViewModel()
        for _ in 1...viewModel.count {
            menu_array.append(false)
        }
        
        numGridPoints_slider.value = Float(numGridPoints / 100)
        numGridPoints_label.text = "\(numGridPoints)個/frame"
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //AR使用のための設定
        //configuration.isLightEstimationEnabled = false
        //configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .none
        //        configuration.sceneReconstruction = .meshWithClassification
        //        configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
        sceneView.session.run(configuration)
        
        //深度情報，マッピング支援
        self.depth_pointCloudRenderer = depth_Renderer(
            session: self.sceneView.session,
            metalDevice: self.sceneView.device!,
            sceneView: self.sceneView,
            modelView: self.modelView)
        self.depth_pointCloudRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        //点群
//        self.pointCloudRenderer = Renderer(
//            session: self.sceneView.session,
//            metalDevice: self.sceneView.device!,
//            sceneView: self.sceneView)
//        self.pointCloudRenderer.drawRectResized(size: self.sceneView.bounds.size)
//        self.pointCloudRenderer.numGridPoints = self.numGridPoints
        
//        self.pointCloudRenderer = Renderer(
//            session: self.sceneView.session,
//            metalDevice: self.sceneView.device!,
//            sceneView: self.modelView)
//        self.pointCloudRenderer.drawRectResized(size: self.modelView.bounds.size)
//        self.pointCloudRenderer.numGridPoints = self.numGridPoints

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func numGridPoints_slider(_ sender: UISlider) {
        let value = round(sender.value)
        numGridPoints_label.text = "\(Int(value * 100))個/frame"
        numGridPoints = Int(value * 100)
    }
    
    @IBAction func Menu_PopOver_tapped(_ sender: UIButton) {
        
        let storyboard = UIStoryboard(name: "PopOver", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "SwitchPopOver") as! SwitchPopOver
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 300, height: 400)
        contentVC.menu_array = menu_array
        print(menu_array)
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        //menuの更新
        contentVC.closure = { (cell_num: Int, bool: Bool) -> Void in
            self.menu_array[cell_num] = bool
        }
        
        present(contentVC, animated: true, completion: nil)
    }
    
    @IBAction func make_modelButton_Tapped(_ sender: UIButton) {
        //スキャン終了時
        if isRecording {
            UIView.animate(withDuration: 0.2) {
                self.make_out_modelButton.layer.cornerRadius = 27.5
                self.make_modelButton.layer.cornerRadius = 25
                
                self.pointCloud_flag = false
                self.parameta_flag = false
                self.depth_flag = false
                
                self.Alert() //モデル作成部分
            }
            //スキャン開始時
        } else {
            UIView.animate(withDuration: 0.2) {
                
                if self.remap_flag == false {
                    self.recording_count += 1
                    self.mesh_flag = true //メッシュの取得，更新
                    
                    //データ保存用のディレクトリ作成
                    self.makeDirectory(num: self.recording_count)
                    
                    if self.recording_count == 0 {
                        self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
                        self.sceneView.debugOptions.remove([.showWorldOrigin])
                    }
                    
                    //点群の表示
                    if self.menu_array[2] == true {
                        self.exit_point_num = 1
                        self.pointCloud_flag = true
                    }
                    
                    
                    guard let frame = self.sceneView.session.currentFrame else {
                        fatalError("Couldn't get the current ARFrame")
                    }
                    let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
                    let cgImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
                    self.current_imageData = cgImage.jpegData(compressionQuality: 0.1)
                    
                    if self.menu_array[0] == true {
                        self.sceneView.debugOptions = .showWorldOrigin
                    }
                    
                    //メッシュの表示
                    if self.menu_array[1] == false {
                        self.exit_mesh_num = 1
                        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                            self.configuration.sceneReconstruction = .meshWithClassification
                        }
                    }
                    
                    if self.menu_array[5] == true {
                        self.mapping_mesh_flag = true
                    }
                    
                    //self.configuration.environmentTexturing = .automatic
                    self.configuration.planeDetection = [.horizontal, .vertical]
                    self.configuration.frameSemantics =  .sceneDepth //.smoothedSceneDepth
                    //configuration.isLightEstimationEnabled = false
                    self.configuration.environmentTexturing = .none
                    
                    //原点の更新
                    if self.menu_array[3] == false {
                        self.sceneView.session.run(self.configuration, options: [.removeExistingAnchors, .resetSceneReconstruction])
                    }
                    else if self.menu_array[3] == true {
                        self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
                    }
                
                    //内部パラメータ保存用
                    let realm = try! Realm()
                    let results = realm.objects(Data_parameta.self)
                    let objName = "NaviModel\(results.count)"
                    try! realm.write {
                        realm.add(Data_parameta(value: ["modelname": objName]))
                    }
                    self.exit_parameta = 1
                    
                } else {
                    self.sceneView.debugOptions.remove([.showWorldOrigin])
                }

                self.make_out_modelButton.layer.cornerRadius = 3.0
                self.make_modelButton.layer.cornerRadius = 3.0
                
                self.parameta_flag = true
                self.parametaCount = 0
                self.meshCount = 0
                
                
                self.lastCameraTransform = self.sceneView.session.currentFrame?.camera.transform
                
                //マッピング支援の停止
                if self.menu_array[4] == true {
                    self.mappingSupportFlag = true
                } else {
                    self.mappingSupportFlag = false
                }
                
            }
        }
        isRecording = !isRecording
    }
    
    //マップの新規作成時にデータ保存用のディレクトリを作成する関数
    func makeDirectory(num: Int) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let pic_directory = url.appendingPathComponent("\(saveFilename)/\(num)/pic", isDirectory: true)
            let json_directory = url.appendingPathComponent("\(saveFilename)/\(num)/json", isDirectory: true)
            let depth_directory = url.appendingPathComponent("\(saveFilename)/\(num)/depth", isDirectory: true)
            let mesh_directory = url.appendingPathComponent("\(saveFilename)/\(num)/mesh", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: pic_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: json_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: depth_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: mesh_directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
    }
    
    @objc func Alert() {
        let title = "マッピング完了"
        let message = """
                      終了する場合は終了して保存先の指定を
                      続行する場合は続行を選択して下さい。
                      """
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if remap_flag == false {
            alertController.addAction(UIAlertAction(title: "続行", style: .default) { [self] _ in
                self.Make_mesh_obj() //モデルを一時保存
                self.mesh_flag = false
            })
            
            alertController.addAction(UIAlertAction(title: "終了", style: .default) { [self] _ in
                self.Make_mesh_obj() //モデルを一時保存
                self.mesh_flag = false
                
                finish_mapping()
            })
        } else if remap_flag {
            alertController.addAction(UIAlertAction(title: "ReMap終了", style: .default) { [self] _ in
                self.remap_flag = false
                finish_reMap()
            })
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func to_CheckDataViewController(_ sender: UIButton) {

        //self.mesh_flag = false
        self.mapping_flag = false
        self.parameta_flag = false
        sceneView.session.pause()

        self.to_CheckDataViewController()
    }

    //メッシュはそのままで画像や深度情報を新しく取得
    @IBAction func Tapped_to_ReMap(_ sender: UIButton) {
        self.remap_flag = true
        
        let storyboard = UIStoryboard(name: "ChoiceData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ChoiceData") as! ChoiceData
        vc.presentationController?.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func setup_ReMap() {
        let choice_section = (ReMapManagement.sectionID)!
        let choice_cell = (ReMapManagement.cellID)!
        let modelNum = 0
        
        //データベースからcell削除
        let results = try! Realm().objects(Navi_SectionTitle.self)
//        print(results[choice_section].cells[choice_cell].models[0])
//        try! Realm().write {
//            results[choice_section].cells[choice_cell].models[0].json.removeAll()
//            results[choice_section].cells[choice_cell].models[0].pic.removeAll()
//            results[choice_section].cells[choice_cell].models[0].depth.removeAll()
//        }
//        print(results[choice_section].cells[choice_cell].models[0]
        
        //ディレクトリ削除
        let picPath = url!.appendingPathComponent("\(results[choice_section].cells[choice_cell].dayString)/\(modelNum)/pic")
        let jsonPath = url!.appendingPathComponent("\(results[choice_section].cells[choice_cell].dayString)/\(modelNum)/json")
        let depthPath = url!.appendingPathComponent("\(results[choice_section].cells[choice_cell].dayString)/\(modelNum)/depth")
        do {
            try FileManager.default.removeItem(at: picPath)
            try FileManager.default.removeItem(at: jsonPath)
            try FileManager.default.removeItem(at: depthPath)
        } catch {
            print("ファイル削除失敗")
        }
        
        //データ保存用のディレクトリ作成
        saveFilename = "\(results[choice_section].cells[choice_cell].dayString)"
        makeDirectory(num: modelNum)
        
        //modelNumに合わせて変更
        recording_count = modelNum
        
        //保存したアンカーを読み込み
        for i in 0..<results[choice_section].cells[choice_cell].models[modelNum].meshNum {
            let per_meshPath = url.appendingPathComponent("\(results[choice_section].cells[choice_cell].dayString)/\(modelNum)/mesh/mesh\(i).data")
            let mesh_data = try! Data(contentsOf: per_meshPath)
            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data) {
                remapAnchors.append(meshAnchor)
            }
        }
        
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

        //ARWorldMapの復元
        self.coachingOverlay.setActive(true, animated: true)
        let worldDataPath =  url.appendingPathComponent("\(results[choice_section].cells[choice_cell].dayString)/\(modelNum)/worldMap.data")
        let data = try! Data(contentsOf: worldDataPath)
        //let data = results[choice_section].cells[choice_cell].models[0].worlddata
        let worldMap = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
        DispatchQueue.main.async {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.initialWorldMap = worldMap
            configuration.sceneReconstruction = .meshWithClassification
            configuration.frameSemantics =  .sceneDepth //.smoothedSceneDepth
            configuration.environmentTexturing = .none
            self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            self.coachingOverlay.setActive(false, animated: true)
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
    }
    
    var vertice_data: [PointCloudVertex] = []
    var vertices: [SCNVector3] = []
    var indices: [Int32] = []
    
    var pre_eulerAngles = SCNVector3(0,0,0)
    
    @IBAction func mappingSwitch(_ sender: UISwitch) {
        if sender.isOn == false {
            mapping_label.text = "動作停止"
            mapping_flag = false
        } else {
            mapping_label.text = "動作中"
            mapping_flag = true
        }
    }
    
    
    @objc func update() {
        
        if parameta_flag == true {
            //print("update")
            guard let frame = self.sceneView.session.currentFrame else {
                fatalError("Couldn't get the current ARFrame")
            }
            if shouldAccumulate(frame: frame) {
                
                jpeg_count += 1
                
                //2D → 3D変換用の内部パラメータ
                let camera = frame.camera
                
                let cameraIntrinsics = camera.intrinsics.inverse
                let flipYZ = simd_float4x4(
                    [1, 0, 0, 0],
                    [0, 1, 0, 0],
                    [0, 0, -1, 0],
                    [0, 0, 0, 1] )
                let viewMatrix = camera.viewMatrix(for: orientation)
                let viewMatrixInverse = viewMatrix.inverse * flipYZ
                
                let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: self.sceneView.bounds.size, zNear: 0.001, zFar: 1000.0)
                //print(camera.imageResolution)
                //print(self.sceneView.bounds.size)
                
                var json_data = Data()
                
                if let camera = self.sceneView.pointOfView {
                    let cameraPosition = camera.position
                    let cameraEulerAngles = camera.eulerAngles
                    //let cameraEulerAngles = SCNVector3(camera.eulerAngles.x-pre_eulerAngles.x, camera.eulerAngles.y-pre_eulerAngles.y, camera.eulerAngles.z-pre_eulerAngles.z)
                    pre_eulerAngles = camera.eulerAngles
                    
                    let worldPosi1 = sceneView.unprojectPoint(SCNVector3(0, 0, 0.996)) //左上
                    let worldPosi2 = sceneView.unprojectPoint(SCNVector3(834, 0, 0.996)) //右上
                    let worldPosi3 = sceneView.unprojectPoint(SCNVector3(0, 1150, 0.996)) //左下
                    
                    let vec_a = SCNVector3(worldPosi2.x - worldPosi1.x, worldPosi2.y - worldPosi1.y, worldPosi2.z - worldPosi1.z)
                    let vec_b = SCNVector3(worldPosi3.x - worldPosi1.x, worldPosi3.y - worldPosi1.y, worldPosi3.z - worldPosi1.z)
                    
                    let mesh_vec = SCNVector3(0.0, 0.0, 1.0)
                    
                    let a = vec_a.y * vec_b.z - vec_a.z * vec_b.y
                    let b = vec_a.z * vec_b.x - vec_a.x * vec_b.z
                    let c = vec_a.x * vec_b.y - vec_a.y * vec_b.x
                    let out_vec_size: Float = sqrt(a * a + b * b + c * c)
                    
                    let tani_out_vec = SCNVector3(a/out_vec_size, b/out_vec_size, c/out_vec_size)
                    
                    let inner = acos(tani_out_vec.x * mesh_vec.x + tani_out_vec.y * mesh_vec.y + tani_out_vec.z * mesh_vec.z)
                    //print(inner * 180.0 / .pi )
                    //180の時にメッシュと並行
                    //90の時にメッシュと垂直
                    
                    //RGB画像
//                    let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
//                    let uiImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!)) //(1440.0, 1920.0)
                    let uiImage = sceneView.snapshot() //(1668.0, 2300.0)
                    //print(uiImage.size)
                    
                    let imageData = uiImage.jpegData(compressionQuality: 0.5)//0.25) //toJPEGData()
                    
                    let entity = MakeMap_parameta(cameraPosition:
                                                    Vector3Entity(x: cameraPosition.x,
                                                                  y: cameraPosition.y,
                                                                  z: cameraPosition.z),
                                                  cameraEulerAngles:
                                                    Vector3Entity(x: cameraEulerAngles.x,
                                                                  y: cameraEulerAngles.y,
                                                                  z: cameraEulerAngles.z),
                                                  cameraVector:
                                                    Vector3Entity(x: tani_out_vec.x,
                                                                  y: tani_out_vec.y,
                                                                  z: tani_out_vec.z),
                                                  Intrinsics:
                                                    Vector33Entity(x: cameraIntrinsics.columns.0,
                                                                   y: cameraIntrinsics.columns.1,
                                                                   z: cameraIntrinsics.columns.2),
                                                  ViewMatrixInverse:
                                                    Vector44Entity(x: viewMatrixInverse.columns.0,
                                                                   y: viewMatrixInverse.columns.1,
                                                                   z: viewMatrixInverse.columns.2,
                                                                   w: viewMatrixInverse.columns.3),
                                                  viewMatrix:
                                                    Vector44Entity(x: viewMatrix.columns.0,
                                                                   y: viewMatrix.columns.1,
                                                                   z: viewMatrix.columns.2,
                                                                   w: viewMatrix.columns.3),
                                                  projectionMatrix:
                                                    Vector44Entity(x: projectionMatrix.columns.0,
                                                                   y: projectionMatrix.columns.1,
                                                                   z: projectionMatrix.columns.2,
                                                                   w: projectionMatrix.columns.3))
                    
                    json_data = try! JSONEncoder().encode(entity)
                    
                    //深度情報のデータを取得（データがない時はfalseを返す）
                    let (depthData, bool) = depth_pointCloudRenderer.depthData()
                    
                    if mapping_flag == true && bool == true {
                        depth_pointCloudRenderer.imgPlaceMatrix.append(projectionMatrix * viewMatrix)
                        
                        DispatchQueue.global().async { [self] in
                            save_jpeg(filename: "保存前", jpegData: imageData!, jsonData: json_data, depthData: depthData)
                            
                            DispatchQueue.main.async {
                                self.parametaCount += 1
                                self.takeParametaCountLabel.text = "取得パラメータ数：\(self.parametaCount)"
                            }
                        }
                    }
                }
            }
        }
    }
    
    private let cameraRotationThreshold = cos(2 * .degreesToRadian)
    private let cameraTranslationThreshold: Float = pow(0.02, 2)
    var lastCameraTransform: simd_float4x4!
    
    private func shouldAccumulate(frame: ARFrame) -> Bool {
        //return true
        let cameraTransform = frame.camera.transform
        let shouldAccum = dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
        || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3) >= cameraTranslationThreshold
        
        return shouldAccum
    }
    
    //jpegデータ保存
    func save_jpeg(filename: String, jpegData: Data, jsonData: Data, depthData: Data) {
//        let realm = try! Realm()
//            let results = realm.objects(Data_parameta.self)
//            try! realm.write {
//                results[self.recording_count].pic.append(pic_data(value: ["pic_name": "rgb_\(filename)",
//                                                                          "pic_data": jpegData]))
//
//                results[self.recording_count].json.append(json_data(value: ["json_name": "\(filename)",
//                                                                            "json_data": jsonData]))
//
//                results[self.recording_count].depth.append(depth_data(value: ["depth_name": "\(filename)",
//                                                                              "depth_data": depthData]))
//            }
                
        //ディレクトリ内にデータを保存
        //let picPath = url.appendingPathComponent("\(saveFilename)/\(recording_count)/pic/pic\(parametaCount).data")
        let picPath = url.appendingPathComponent("\(saveFilename)/\(recording_count)/pic/pic\(parametaCount).jpg")
        let jsonPath = url.appendingPathComponent("\(saveFilename)/\(recording_count)/json/json\(parametaCount).data")
        let depthPath = url.appendingPathComponent("\(saveFilename)/\(recording_count)/depth/depth\(parametaCount).data")
        do {
            try jpegData.write(to: picPath)
            try jsonData.write(to: jsonPath)
            try depthData.write(to: depthPath)
        } catch {
            print("データ保存失敗", error)
        }
        
        lastCameraTransform = sceneView.session.currentFrame?.camera.transform
    }
    
    func Make_mesh_obj() {
        
        let realm = try! Realm()
        let results = realm.objects(Navityu.self)
        
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dayString = format.string(from: date)
        print( "現在時刻： ", format.string(from: date) )
        
        let objName = "NaviModel\(results.count)"
        
        if menu_array[1] == false {
//            let realm = try! Realm()
//            let results = realm.objects(Data_parameta.self)
//            try! Realm().write {
//                results[self.recording_count].mesh_anchor.removeAll()
//            }
            
            guard let anchors = sceneView.session.currentFrame?.anchors else { return }
            let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor}
            meshCount = meshAnchors.count
            for (i, anchor) in meshAnchors.enumerated() {
                
                guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                else{ return }
                
//                    let results = realm.objects(Data_parameta.self)
//                    try! realm.write {
//                        results[self.recording_count].mesh_anchor.append(anchor_data(value: ["mesh": mesh_data]))
//                    }
                    
                //ディレクトリにメッシュデータを保存
                let meshPath = url.appendingPathComponent("\(saveFilename)/\(recording_count)/mesh/mesh\(i).data")
                do {
                    try mesh_data.write(to: meshPath)
                } catch {
                    print("メッシュデータ保存失敗", error)
                }
                    
            }
        }
        
        sceneView.session.getCurrentWorldMap { [self]worldMap, error in
            if let map = worldMap {
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
                    
                    //データをドキュメント内に保存
                    let worldmapPath = url.appendingPathComponent("保存前/\(recording_count)/worldMap.data")
                    let worldimagePath = url.appendingPathComponent("保存前/\(recording_count)/worldImage.jpg")
                    do {
                        try data.write(to: worldmapPath) //ARWorldMap
                        try current_imageData!.write(to: worldimagePath)
                    } catch {
                        print("Failed to save the image:", error)
                    }
                    
                    
                    try! realm.write {
                        realm.add(Navityu(value: ["modelname": objName,
                                                  "dayString": dayString,
                                                  //"worlddata": data,
                                                  //"worldimage": self.current_imageData!,
                                                  "exit_mesh": self.exit_mesh_num,
                                                  "exit_point": self.exit_point_num,
                                                  "exit_parameta": self.exit_parameta,
                                                  "parametaNum": self.parametaCount,
                                                  "meshNum": self.meshCount]))
                    }
                    
                    self.exit_parameta = 0
                    self.exit_mesh_num = 0
                    self.exit_point_num = 0
                    
                } else {
                    let alertController = UIAlertController(title: "Failed to save the model1", message: "Try again", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                print("Error: \(error!.localizedDescription)")
                let alertController = UIAlertController(title: "Failed to save the model2", message: "Try again", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            
            //配置したmeshオブジェクトを削除
            for name in self.meshAnchors_array {
                if let node = self.sceneView.scene.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            meshAnchors_array = []
            
            print(realm.objects(Navi_SectionTitle.self))
        }
    }
    
    func finish_reMap() {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let choice_section = (ReMapManagement.sectionID)!
        let choice_cell = (ReMapManagement.cellID)!
        let modelNum = 0
        
        try! realm.write {
            results[choice_section].cells[choice_cell].models[modelNum].parametaNum = parametaCount
            results[choice_section].cells[choice_cell].models[modelNum].texBool = false
            results[choice_section].cells[choice_cell].models[modelNum].texture_bool = 0
        }
        
        self.dismiss(animated: false, completion: nil)
    }
    
    //ディレクトリ削除
    func removeDirectory() {
        do {
            try FileManager.default.removeItem(at: url.appendingPathComponent("保存前"))
            print("ディレクトリ削除成功")
        } catch _ {
            print("ディレクトリ削除失敗（存在しない）")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        if parameta_flag == true {
            self.depth_pointCloudRenderer.draw100() //深度情報

            if mappingSupportFlag == false {
                self.depth_pointCloudRenderer.mapping100() //マッピング支援

                if remap_flag {
                    depth_pointCloudRenderer.meshAnchors = remapAnchors
                }
            }
            
//            if pointCloud_flag == true {
//                //pointCloudRenderer.draw() //点群
//                self.depth_pointCloudRenderer.draw()
//                //self.depth_pointCloudRenderer.point_draw()
//            }
        }
        
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if mesh_flag {
            for anchor in anchors {
                var sceneNode : SCNNode?
                if let meshAnchor = anchor as? ARMeshAnchor {
                    let meshGeo = SCNGeometry.fromAnchor(meshAnchor:meshAnchor)
                    sceneNode = SCNNode(geometry: meshGeo)
                }
                if let node = sceneNode {
                    node.simdTransform = anchor.transform
                    knownAnchors[anchor.identifier] = node
                    node.name = "mesh"
                    meshAnchors_array.append(node.name!)
                    
                    if mapping_mesh_flag == true {
                        print("メッシュ追加")
                        sceneView.scene.rootNode.addChildNode(node)
                    }
                    
                    //modelView.scene?.rootNode.addChildNode(node)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if mesh_flag {
            var meshAnchors = [ARMeshAnchor]()
            for anchor in anchors {
                if let node = knownAnchors[anchor.identifier] {
                    if let meshAnchor = anchor as? ARMeshAnchor {
                        
                        meshAnchors.append(meshAnchor) //updateされたメッシュ情報
                        
                        node.geometry = SCNGeometry.fromAnchor(meshAnchor: meshAnchor)
                    }
                    node.simdTransform = anchor.transform
                }
            }
            depth_pointCloudRenderer.meshAnchors = meshAnchors
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
                // knownAnchors からも削除
                knownAnchors.removeValue(forKey: anchor.identifier)
            }
        }
    }
    
    var check_flag = false
    
    func snapshot() -> UIImage {
        //コンテキスト開始
        UIGraphicsBeginImageContextWithOptions(UIScreen.main.bounds.size, false, 0.0)
        //viewを書き出す
        self.view.drawHierarchy(in: self.view.bounds, afterScreenUpdates: true)
        // imageにコンテキストの内容を書き出す
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        //コンテキストを閉じる
        UIGraphicsEndImageContext()
        // imageをカメラロールに保存
        //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        return image
    }
    
    func to_CheckDataViewController() {
        check_flag = true
        timer.invalidate()
        
//        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            let archivePath = url.appendingPathComponent("現実.jpg")
//            let imageData = snapshot().jpegData(compressionQuality: 1.0)
//            do {
//                try imageData!.write(to: archivePath)
//            } catch {
//                print("Failed to save the image:", error)
//            }
//        }
        
        let storyboard = UIStoryboard(name: "CheckData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckDataViewController") as! CheckDataViewController
        guard let anchors = sceneView.session.currentFrame?.anchors else { return }
        vc.anchors = anchors.compactMap { $0 as? ARMeshAnchor}
        let num = 2.0
        let picPath = url.appendingPathComponent("保存前/\(recording_count)/pic/pic0.jpg")
        let width = (UIImage(data: try! Data(contentsOf: picPath))?.size.width)! / num
        let yoko = Float(floor(16384.0 / width)) //17.0
        let tate = ceil(Float(parametaCount)/yoko)
        vc.calculateParameta = calculateParameta(device: self.sceneView.device!,
                                                 W: Int(sceneView.bounds.width),
                                                 H: Int(sceneView.bounds.height),
                                                 tate: Int(tate), yoko: Int(yoko),
                                                 funcString: "calcu5")
        vc.picCount = parametaCount
        vc.recording_count = recording_count
        vc.presentationController?.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
    
    func finish_mapping() {
        timer.invalidate()
        let storyboard = UIStoryboard(name: "AddDataCellChoice", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddDataCellChoiceController") as! AddDataCellChoiceController
        self.present(vc, animated: true, completion: nil)
        //self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func back(_ sender: Any) {
        timer.invalidate()
        
//        let transition = CATransition()
//        transition.duration = 0.25
//        transition.type = CATransitionType.push
//        transition.subtype = CATransitionSubtype.fromLeft
//        view.window!.layer.add(transition, forKey: kCATransition)
        
        self.dismiss(animated: true, completion: nil)
    }
    
}

//dismissをを検知
extension MakeNavigationController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
      print("dismiss")
      
      if check_flag == true {
          sceneView.session.run(configuration, options: [])
          
          self.mapping_flag = true
          self.parameta_flag = true
          timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
          self.check_flag = false
      }
      
      if remap_flag {
          print("remap")
          setup_ReMap()
      }
      
  }
}