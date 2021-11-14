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

class MakeNavigationController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
//    //画面遷移した際のsectionとcellの番号を格納
//    var section_num = Int()
//    var cell_num = Int()
    
    @IBOutlet weak var sceneView: ARSCNView!
    let scene = SCNScene()
    @IBOutlet weak var status_label: UILabel!
    
    private var pointCloudRenderer: Renderer!
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
    
    //let marker_name = ["toy_drummer", "toy_robot_vintage", "chair_swan", "toy_biplane", "tv_retro", "flower_tulip", "start", "goal"]
    var select_marker_num = -100
    //var place_object_name: [String] = []
    var add_object_num: [Int] = []
    var goal_marker_flag = false
    
    let ObjectdataSource = ObjectModel()
    var item = ObjectItem(name: "", id: 0, kind: "")
    @IBOutlet weak var Add_ModelButton: UIButton!
    
    @IBOutlet weak var make_modelButton: UIButton!
    @IBOutlet weak var make_out_modelButton: UIButton!
    
    let configuration = ARWorldTrackingConfiguration()
    var make_modelButton_Tapped_count = 0 //マップ作成ボタンを押した数
    
    var isRecording = false
    var recording_count = -1 //何回スキャンを行なったか
    
    var current_imageData: Data!
    var current_worlddata: Data!
    var push_buttonCount = 0
    
    var knownAnchors = Dictionary<UUID, SCNNode>()
    var meshAnchors_array: [String] = []
    var texcoords2: [[SIMD2<Float>]] = []
    
    var jpeg_count = 0
    var parameta_flag = false
    
    private let orientation = UIInterfaceOrientation.portrait
    
    //metal用のRendererのインスタンス
    private var renderer: Renderer!
    private let session = ARSession()
    
    var timer: Timer!
    
    var depth_flag = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.session.delegate = self
        sceneView.scene = scene
        
        sceneView.debugOptions = .showWorldOrigin
        
        Add_ModelButton.isHidden = true
        
        //パラメータを一時的に保存する場所を初期化
        let realm = try! Realm()
        try! realm.write {
            realm.delete(realm.objects(Navityu.self))
            realm.delete(realm.objects(Data_parameta.self))
        }
        
        let viewModel = MenuViewModel()
        for _ in 1...viewModel.count {
            menu_array.append(false)
        }
        
        numGridPoints_slider.value = Float(numGridPoints / 100)
        numGridPoints_label.text = "\(numGridPoints)個/frame"
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
//        //AR使用のための設定
        let configuration = ARWorldTrackingConfiguration()
        //configuration.isLightEstimationEnabled = false
        configuration.environmentTexturing = .none
//        configuration.sceneReconstruction = .meshWithClassification
//        configuration.planeDetection = [.horizontal, .vertical] //平面検出の有効化
        sceneView.session.run(configuration) // Run the view's session
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
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (cell_num: Int, bool: Bool) -> Void in
            self.menu_array[cell_num] = bool
            if self.menu_array[2] == true {
                self.Add_ModelButton.isHidden = false
            } else {
                self.Add_ModelButton.isHidden = true
            }
        }
        present(contentVC, animated: true, completion: nil)
    }
    
    @IBAction func marker_plus(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "PopOver", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "MarkerPopOverController") as! MarkerPopOverController
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 200, height: 400)
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (num: Int) -> Void in
            self.select_marker_num = num
            self.item = self.ObjectdataSource.item(row: self.select_marker_num)
        }
        
        present(contentVC, animated: true, completion: nil)
    }
    
    //画面タップしたとき
    @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
        if menu_array[2] == true {
            let location = sender.location(in: sceneView)
            let hitResults = sceneView.hitTest(location, options: [:])
            if !hitResults.isEmpty {
                let posi = hitResults[0].worldCoordinates
                //if select_marker_num >= 6 {
                if item.kind == "scn" {
                    let scene1 = SCNScene(named: "art.scnassets/\(item.name).scn")
                    let node = (scene1?.rootNode.childNode(withName: item.name, recursively: false))!
                    if item.name == "goal" {
                        goal_marker_flag = true
                    }
                    node.position = posi
                    node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 2.5)))
                    node.name = item.name
                    //place_object_name.append(node.name!)
                    add_object_num.append(item.id)
                    sceneView.scene.rootNode.addChildNode(node)
                }
                //else if select_marker_num <= 5 {
                else if item.kind == "usdz" {
                    guard let url = Bundle.main.url(forResource: "art.scnassets/\(item.name)", withExtension: "usdz") else { return }
                    let scene1 = try! SCNScene(url: url, options: [.checkConsistency: true])
                    let node = scene1.rootNode.childNode(withName: item.name, recursively: true)
                    node?.scale = SCNVector3(0.01, 0.01, 0.01)
                    node?.position = posi
                    node!.name = item.name
                    //place_object_name.append(node!.name!)
                    add_object_num.append(item.id)
                    sceneView.scene.rootNode.addChildNode(node!)
                }
            }
        }
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
                
                let realm = try! Realm()
                let results = realm.objects(Data_parameta.self)
                print(results[0].pic.count)
            }
        //スキャン開始時
        } else {
            UIView.animate(withDuration: 0.2) {
                if self.make_modelButton_Tapped_count == 0 {
                    self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
                    self.sceneView.debugOptions.remove([.showWorldOrigin])
                }
                self.make_modelButton_Tapped_count += 1
                
                self.pointCloudRenderer = Renderer(
                    session: self.sceneView.session,
                    metalDevice: self.sceneView.device!,
                    sceneView: self.sceneView)
                self.pointCloudRenderer.drawRectResized(size: self.sceneView.bounds.size)
                self.pointCloudRenderer.numGridPoints = self.numGridPoints

                //配置したscnオブジェクトを削除
                //for name in self.place_object_name {
                for num in self.add_object_num {
                    let ite = self.ObjectdataSource.item(row: num)
                    if let node = self.sceneView.scene.rootNode.childNode(withName: ite.name, recursively: false) {
                        node.removeFromParentNode()
                    }
                }
                self.select_marker_num = -100
                //self.place_object_name = []
                self.add_object_num = []
                
                if self.menu_array[4] == false {
                    self.exit_point_num = 1
                    self.pointCloud_flag = true
                }
//                else if self.menu_array[4] == true {
//                    self.exit_point_num = 0
//                }

                self.status_label.text = "Mapping"
                self.recording_count += 1
                self.make_out_modelButton.layer.cornerRadius = 3.0
                self.make_modelButton.layer.cornerRadius = 3.0

                guard let frame = self.sceneView.session.currentFrame else {
                    fatalError("Couldn't get the current ARFrame")
                }
                let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
                let cgImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
                self.current_imageData = cgImage.jpegData(compressionQuality: 0.5)
                
                self.mesh_flag = true
                self.parameta_flag = true
                
                if self.menu_array[0] == true {
                    self.sceneView.debugOptions = .showWorldOrigin
                }
                
                if self.menu_array[3] == false {
                    self.exit_mesh_num = 1
                    if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                        self.configuration.sceneReconstruction = .meshWithClassification
                    }
                }
//                else if self.menu_array[3] == true {
//                    self.exit_mesh_num = 0
//                }
                self.configuration.environmentTexturing = .automatic
                self.configuration.planeDetection = [.horizontal, .vertical]
                self.configuration.frameSemantics = .smoothedSceneDepth //sceneDepth
                //configuration.isLightEstimationEnabled = false
                self.configuration.environmentTexturing = .none
                
                if self.menu_array[5] == false {
                    self.sceneView.session.run(self.configuration, options: [.removeExistingAnchors, .resetSceneReconstruction])
                }
                else if self.menu_array[5] == true {
                    self.sceneView.session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
                }
                
                //self.parameta_flag.toggle()
                
                //内部パラメータ保存用
                let realm = try! Realm()
                let results = realm.objects(Data_parameta.self)
                let objName = "NaviModel\(results.count)"
                try! realm.write {
                    realm.add(Data_parameta(value: ["modelname": objName]))
                }
                self.exit_parameta = 1
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
            self.Make_mesh_obj() //モデルを書き込み
            self.mesh_flag = false
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func tapped(_ sender: UIButton) {
        depth_flag = true
    }
    
    var vertice_data: [PointCloudVertex] = []
    
    var vertices: [SCNVector3] = []
    var indices: [Int32] = []
    
    @IBAction func kari_make_model(_ sender: UIButton) {
        guard let frame = self.sceneView.session.currentFrame else {
            fatalError("Couldn't get the current ARFrame")
        }
//        let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
//        let uiImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
//        let resizeScale = CGFloat(256) / CGFloat(2880)
//        let resizeScale_y = CGFloat(192) / CGFloat(3840)
//        let resizedColorImage = CIImage(cgImage: uiImage.cgImage!).transformed(by: CGAffineTransform(scaleX: resizeScale, y: resizeScale_y))
//        let pixelArray = resizedColorImage.createCGImage().pixelData()!
        
        let camera = frame.camera
        let IntrinsicsInversed = camera.intrinsics.inverse
        let flipYZ = simd_float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )
        let localToworld = camera.viewMatrix(for: orientation).inverse * flipYZ
        
        let aspectRatio = self.sceneView.bounds.height / self.sceneView.bounds.width
        var (depthArray, depthSize) = frame.cropPortraitCenterSquareDepth(aspectRatio: aspectRatio)
        let (depthConfidenceArray, _) = frame.cropPortraitCenterSquareDepthConfidence(aspectRatio: aspectRatio)
        print("depthConfidenceArray.count:\(depthConfidenceArray.count)")
        // 信頼度が高い深度情報のみ抽出
        if depthArray.count != depthConfidenceArray.count  {
            depthArray = depthConfidenceArray.enumerated().map {
                // 信頼度が high 未満は深度を -1 に書き換え
                return $0.element >= UInt8(ARConfidenceLevel.high.rawValue) ? depthArray[$0.offset] : -1
            }
        }
        
        let depthScreenScaleFactor = Float(self.sceneView.bounds.width * UIScreen.screens.first!.scale / CGFloat(depthSize))
        
        // 信頼度が高い深度情報のみ3Dモデル化
//        let isConfidentDepth: (Int, Int) -> Bool = { (x, y) in
//            guard x < depthSize && y < depthSize else { return false }
//            return depthArray[y * depthSize + x] >= 0.0
//        }
        
        for y in 0 ..< depthSize {
            for x in 0 ..< depthSize {
                // 頂点座標を作成（最終的に表示しないものも作る）
                let depth = depthArray[y * depthSize + x]
                if depth < 0 {
                    continue
                }
                let x_px = Float(x) * depthScreenScaleFactor
                let y_px = Float(y) * depthScreenScaleFactor
                // 2Dの深度情報を3Dに変換
                let localPoint = IntrinsicsInversed * simd_float3(x_px, y_px, 1) * depth
                //ワールド座標に合わせてローカルから変換
                let worldPoint = localToworld * simd_float4(localPoint, 1)
                //worldPoint = worldPoint / worldPoint.w
                //print(worldPoint.w) //1.0
                
//                let r = Float(pixelArray[((y+4) * 256 + (x+36)) * 4]) / Float(255)
//                let g = Float(pixelArray[((y+4) * 256 + (x+36)) * 4 + 1]) / Float(255)
//                let b = Float(pixelArray[((y+4) * 256 + (x+36)) * 4 + 2]) / Float(255)
                vertice_data.append(PointCloudVertex(x: worldPoint.x,
                                                        y: worldPoint.y,
                                                        z: worldPoint.z,
                                                        r: 255,
                                                        g: 255,
                                                        b: 255))
                
//                vertices.append(SCNVector3(worldPoint.x, worldPoint.y, worldPoint.z))
            }
        }
//        print(vertice_data.count)
        let node = buildNode(points: vertice_data)
//        // ジオメトリ作成
//        let vertexSource = SCNGeometrySource(vertices: vertices)
//        let geometryElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
//        let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
//
//        // ノード作成
//        let node = SCNNode(geometry: geometry)
//        node.position = .init(x: 0, y: 0, z: 0)
        self.scene.rootNode.addChildNode(node)
    }
    
    private func buildNode(points: [PointCloudVertex]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: points.count,
            bytesPerIndex: MemoryLayout<Int>.size
        )

        // for bigger dots
        element.pointSize = 1
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 7

        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        
        return SCNNode(geometry: pointsGeometry)
    }
    
    var pre_eulerAngles = SCNVector3(0,0,0)
    
    @objc func update() {
        //if depth_flag == true {
            if parameta_flag == true {
                guard let frame = self.sceneView.session.currentFrame else {
                    fatalError("Couldn't get the current ARFrame")
                }
                jpeg_count += 1
                
                //2D → 3D変換用の内部パラメータ
//                let camera = frame.camera
//
//                let cameraIntrinsics = camera.intrinsics.inverse
//                let flipYZ = simd_float4x4(
//                    [1, 0, 0, 0],
//                    [0, 1, 0, 0],
//                    [0, 0, -1, 0],
//                    [0, 0, 0, 1] )
//                let viewMatrix = camera.viewMatrix(for: orientation).inverse * flipYZ
                
                var json_data = Data()
                
                if let camera = self.sceneView.pointOfView {
                    let cameraPosition = camera.position
                    //let cameraEulerAngles = camera.eulerAngles
                    let cameraEulerAngles = SCNVector3(camera.eulerAngles.x-pre_eulerAngles.x, camera.eulerAngles.y-pre_eulerAngles.y, camera.eulerAngles.z-pre_eulerAngles.z)
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
                    print(inner * 180.0 / .pi )
                    //180の時にメッシュと並行
                    //90の時にメッシュと垂直
                    
                    //RGB画像
                    let ciImage = CIImage.init(cvImageBuffer: frame.capturedImage)
                    let uiImage = UIImage.init(ciImage: ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
                    let imageData = uiImage.jpegData(compressionQuality: 0.5) //toJPEGData()
                    
                    let entity = MakeMap_parameta(cameraPosition:
                                                    Vector3Entity(x: cameraPosition.x,
                                                                  y: cameraPosition.y,
                                                                  z: cameraPosition.z),
                                                  cameraEulerAngles:
                                                    Vector3Entity(x: cameraEulerAngles.x,
                                                                  y: cameraEulerAngles.y,
                                                                  z: cameraEulerAngles.z),
                                                  cameraVector: Vector3Entity(x: tani_out_vec.x,
                                                                              y: tani_out_vec.y,
                                                                              z: tani_out_vec.z))
                    
                    json_data = try! JSONEncoder().encode(entity)
                    
//                    //深度画像
//                    let aspectRatio = self.sceneView.bounds.height / self.sceneView.bounds.width
//                    var (depthArray, depthSize) = frame.cropPortraitCenterSquareDepth(aspectRatio: aspectRatio)
//                    print("depthSize:\(depthSize)")
//                    print("depthArray.count:\(depthArray.count)")

//                    // 深度の信頼度情報を取得
//                    let (depthConfidenceArray, _) = frame.cropPortraitCenterSquareDepthConfidence(aspectRatio: aspectRatio)
//                    print("depthConfidenceArray.count:\(depthConfidenceArray.count)")
//                    // 信頼度が高い深度情報のみ抽出
//                    if depthArray.count != depthConfidenceArray.count  {
//                        depthArray = depthConfidenceArray.enumerated().map {
//                            // 信頼度が high 未満は深度を -1 に書き換え
//                            return $0.element >= UInt8(ARConfidenceLevel.high.rawValue) ? depthArray[$0.offset] : -1
//                        }
//                    }
//                    var depthDataArray: [depthMap_data] = []
//                    for i in depthArray {
//                        depthDataArray.append(depthMap_data(depth: i))
//                    }
//                    //print("depthDataArray_count:\(depthDataArray.count)")
//                    let depthMapData: Data = try! JSONEncoder().encode(depthDataArray)
                    
                    save_jpeg(filename: "try_\(jpeg_count)", jpegData: imageData!, jsonData: json_data)
                }
            }
            
                            
            
//                            guard let depthMap = frame.smoothedSceneDepth?.depthMap else {
//                                fatalError("Couldn't get the depthMap")
//                            }
//                            let depth_ciImage = CIImage.init(cvPixelBuffer: depthMap)
//                            let depth_cgImage = UIImage.init(ciImage: depth_ciImage.oriented(CGImagePropertyOrientation(rawValue: 6)!))
//                            let depthData = depth_cgImage.jpegData(compressionQuality: 0.5)
            
//                            // depthMapのCPU配置(?)
//                            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
//                            let base = CVPixelBufferGetBaseAddress(depthMap) // 先頭ポインタの取得
//                            let width = CVPixelBufferGetWidth(depthMap) // 横幅の取得
//                            let height = CVPixelBufferGetHeight(depthMap) // 縦幅の取得
//                            print("width:\(width)")
//                            print("height:\(height)")
//                            let bindPtr = base?.bindMemory(to: Float32.self, capacity: width * height)
//                            let bufPtr = UnsafeBufferPointer(start: bindPtr, count: width * height)
//                            let depthArray = Array(bufPtr)
//                            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
//                            let fixedArray = depthArray.map({ $0.isNaN ? 0 : $0 })
            
                            
            
            //save_jpeg(filename: "try_\(jpeg_count)", jpegData: imageData!, jsonData: json_data)//, depthMapData: depthMapData)
        //}
    }
    
    //jpegデータ保存
    func save_jpeg(filename: String, jpegData: Data, jsonData: Data) {
        
        let realm = try! Realm()
        let results = realm.objects(Data_parameta.self)
        try! realm.write {
            results[self.recording_count].pic.append(pic_data(value: ["pic_name": "rgb_\(filename)",
                                                                      "pic_data": jpegData]))

            results[self.recording_count].json.append(json_data(value: ["json_name": "\(filename)",
                                                                      "json_data": jsonData]))
        }
        
//        // DocumentディレクトリのfileURLを取得
//        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
////            // ディレクトリのパスにファイル名をつなげてファイルのフルパスを作る
//            let targetTextFilePath_depthMap = documentDirectoryFileURL.appendingPathComponent("depth_\(filename).data")
//            do {
//                try depthMapData.write(to: targetTextFilePath_depthMap)
//            } catch {
//                print("エラー")
//            }
//        }
        
    }
    
    func Make_mesh_obj() {
        //現在のフレームを獲得
        //        guard let frame = sceneView.session.currentFrame else {
        //            fatalError("Couldn't get the current ARFrame")
        //        }
        if menu_array[1] == true {
            if goal_marker_flag == false {
                if let camera = sceneView.pointOfView { // カメラを取得
                    let camera_posi = camera.convertPosition(SCNVector3(0, 0, -0.2), to: nil)
                    let scene1 = SCNScene(named: "art.scnassets/kirikae.scn")
                    let node = (scene1?.rootNode.childNode(withName: "kirikae", recursively: false))!
                    node.position = camera_posi
                    node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 2.5)))
                    node.name = "kirikae"
                    //place_object_name.append(node.name!)
                    add_object_num.append(8)
                    sceneView.scene.rootNode.addChildNode(node)
                }
            }
        }
        
        let realm = try! Realm()
        let results = realm.objects(Navityu.self)
        
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm"
        let dayString = format.string(from: date)
        print( "現在時刻： ", format.string(from: date) )
        
        let objName = "NaviModel\(results.count)" //"Scan\(section_num)\(cell_num)-\(results[section_num].cells[cell_num].models.count)"
        
        // DocumentディレクトリのfileURLを取得
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            // ディレクトリのパスにファイル名をつなげてファイルのフルパスを作る
            let targetTextFilePath = documentDirectoryFileURL.appendingPathComponent(objName+".scn")
            
            //point cloudをtxtファイルで保存
            if menu_array[4] == false {
                self.pointCloudRenderer.savePointsToFile(failname: objName)
            }
            //sceneをscnファイルで保存
            if menu_array[3] == false {
                self.sceneView.scene.write(to: targetTextFilePath, options: nil, delegate: nil, progressHandler: nil)
                
                guard let anchors = sceneView.session.currentFrame?.anchors else { return }
                let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor}
                for (_, anchor) in meshAnchors.enumerated() {
//                    texcoords2.append([])
//                    let verticles = anchor.geometry.vertices
//                    for _ in 0..<verticles.count {
//                        texcoords2[i].append(SIMD2<Float>(0, 0))
//                    }
                    guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                    else{ return }
//                    let texcoords_data = try! JSONEncoder().encode(texcoords2[i])
                    
                    let realm = try! Realm()
                    let results = realm.objects(Data_parameta.self)
                    try! realm.write {
                        results[self.recording_count].mesh_anchor.append(anchor_data(value: ["mesh": mesh_data]))
                        //,"texcoords": texcoords_data]))
                    }
                }
            }
            
            sceneView.session.getCurrentWorldMap { [self]worldMap, error in
                if let map = worldMap {
                    if let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
                        //UserDefaults.standard.set(data, forKey: "worlddata") //上書きされるから注意
                        try! realm.write {
                            realm.add(Navityu(value: ["modelname": objName,
                                                      "dayString": dayString,
                                                      "worlddata": data, //current_worlddata!,
                                                      "worldimage": self.current_imageData!,
                                                      "exit_mesh": self.exit_mesh_num,
                                                      "exit_point": self.exit_point_num,
                                                      "exit_parameta": self.exit_parameta]))
                        }
                        
                        self.exit_parameta = 0
                        self.exit_mesh_num = 0
                        self.exit_point_num = 0
                        
                        //for name in self.place_object_name {
                        for num in self.add_object_num {
                            let ite = self.ObjectdataSource.item(row: num)
                            let node = self.sceneView.scene.rootNode.childNode(withName: ite.name, recursively: false)
//                            var usdz_num = -1000
//                            if let num = marker_name.firstIndex(of: name) {
//                                if num >= 6 {
//                                    usdz_num = -50
//                                }
//                                else {
//                                    usdz_num = num
//                                }
//                            }
                            try! realm.write {
                                results[self.recording_count].usdz.append(Navi_Usdz_ModelInfo(value:
                                                                                                ["usdz_name": ite.name,
                                                                                                 "usdz_num": ite.id,
                                                                                                 "usdz_posi_x": node!.position.x,
                                                                                                 "usdz_posi_y": node!.position.y,
                                                                                                 "usdz_posi_z": node!.position.z]))
                            }
                        }
                    } else {
                        //fatalError("can't encode map")
                        let alertController = UIAlertController(title: "Failed to save the model1", message: "Try again", preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
                } else {
                    print("Error: \(error!.localizedDescription)")
                    let alertController = UIAlertController(title: "Failed to save the model2", message: "Try again", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil)) //{ [self] _ in //okが押されたら //})
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            
            //配置したmeshオブジェクトを削除
            for name in self.meshAnchors_array {
                if let node = self.sceneView.scene.rootNode.childNode(withName: name, recursively: false) {
                    node.removeFromParentNode()
                }
            }
            meshAnchors_array = []
            
        }
        print(realm.objects(Navi_SectionTitle.self))
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if pointCloud_flag == true {
            pointCloudRenderer.draw()
        }
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
                    meshAnchors_array.append(node.name!)
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
                // knownAnchors からも削除
                knownAnchors.removeValue(forKey: anchor.identifier)
            }
        }
    }
    
    @IBAction func Check_navidata(_ sender: Any) {
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        print(results)
        
        let storyboard = UIStoryboard(name: "CheckDataCell", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckDataCellController") as! CheckDataCellController
//        vc.section_num = section_num
//        vc.cell_num = cell_num
        //vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func Finish_navigate(_ sender: Any) {
        timer.invalidate()
        
        let realm = try! Realm()
        let results = realm.objects(Data_parameta.self)
        print(results[self.recording_count].pic)
        
        let storyboard = UIStoryboard(name: "AddDataCellChoice", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddDataCellChoiceController") as! AddDataCellChoiceController
        //vc.view.backgroundColor = UIColor.white
        //vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        timer.invalidate()
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension  SCNGeometry {
    public static func fromAnchor(meshAnchor: ARMeshAnchor) -> SCNGeometry {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        // use the MTL buffer that ARKit gives us
        let vertexSource = SCNGeometrySource(buffer: vertices.buffer, vertexFormat: vertices.format, semantic: .vertex, vertexCount: vertices.count, dataOffset: vertices.offset, dataStride: vertices.stride)
        
        // but we need to create our own copy of the faces..
        let faceData = Data(bytesNoCopy: faces.buffer.contents(), count: faces.buffer.length, deallocator: .none)
        
        // create the geometry element
        let geometryElement = SCNGeometryElement(data: faceData, primitiveType: .triangles, primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
        
        // assign a material suitable for default visualization
        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = UIColor.green //UIColor(displayP3Red:1, green:1, blue:1, alpha:0.7)
        geometry.materials = [defaultMaterial]
        
        return geometry;
      }
}

extension  SCNGeometryPrimitiveType {
    static  func  of(_ type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
       switch type {
       case .line:
            return .line
       case .triangle:
            return .triangles
       @unknown default:
            return .line
       }
    }
}

extension ARMeshGeometry {
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar, "Expected one unsigned char (one byte) per classification")
        let classificationPointer = classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
}

extension ARMeshClassification {
    var description: String {
        switch self {
        case .ceiling: return "Ceiling"
        case .door: return "Door"
        case .floor: return "Floor"
        case .seat: return "Seat"
        case .table: return "Table"
        case .wall: return "Wall"
        case .window: return "Window"
        case .none: return "None"
        @unknown default: return "Unknown"
        }
    }
    
    var color: UIColor {
        switch self {
        case .ceiling: return .cyan
        case .door: return .brown
        case .floor: return .red
        case .seat: return .purple
        case .table: return .yellow
        case .wall: return .green
        case .window: return .blue
        case .none: return .lightGray
        @unknown default: return .gray
        }
    }
}
