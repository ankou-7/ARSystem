//
//  NavigationEditModel2.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2021/03/04.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class EditDataController: UIViewController, ARSCNViewDelegate,  UIGestureRecognizerDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    let cameraNode = SCNNode()
    var lastGestureRotation: Float = 0.0
    var lastGestureScale: Float = 1.0
    
    var ui_view = UIView()
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    
    
    @IBOutlet weak var mesh_slider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        
//        // UIView生成
//        ui_view.frame = CGRect(x: 0,
//                               y: 0,
//                               width: 500,
//                               height: 500)
        print("\(self.sceneView.bounds.width) pt")
        print("\(self.sceneView.bounds.height) pt")
//        ui_view.backgroundColor = UIColor.blue
////        view.layer.borderColor = UIColor.yellow.cgColor //枠線の色
////        view.layer.borderWidth = 1 //枠線の太さ
//        ui_view.layer.opacity = 0.1
//        self.sceneView.addSubview(ui_view)
        
//        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
//            let file_name = documentDirectoryFileURL.appendingPathComponent("rgb_try_102.jpeg")
//            let image = UIImage(contentsOfFile: file_name.path)
//            imageView.image = image
//            imageView.alpha = 0.3
//            // 画像の幅・高さの取得
//            let width = image!.size.width //2880
//            let height = image!.size.height //3840
//            print(width)
//            print(height)
//
//            let clipRect = CGRect(x: ((2880-((2*834*1920)/1194))/2), y: 0, width: ((2*834*1920)/1194), height: 3840)
//            let cripImageRef = image?.cgImage!.cropping(to: clipRect)
//            let crippedImage = UIImage(cgImage: cripImageRef!, scale: image!.scale, orientation: image!.imageOrientation)
//            print(crippedImage.size)
//            imageView.image = crippedImage
//            imageView2.image = crippedImage
//        }
//
//
//        let json_data = read_json(name: "try_102")
//        let cameraPosition = SCNVector3(json_data.cameraPosition.x,
//                                        json_data.cameraPosition.y,
//                                        json_data.cameraPosition.z)
//        let cameraEulerAngles = SCNVector3(json_data.cameraEulerAngles.x,
//                                           json_data.cameraEulerAngles.y,
//                                           json_data.cameraEulerAngles.z)
        
//        let geometry = SCNPlane(width: 0.294217, height: 0.4141611)
//        let planeMaterial = SCNMaterial()
//        planeMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
//        geometry.materials = [planeMaterial]
//        let plane_node = SCNNode(geometry: geometry)
//        plane_node.position = cameraPosition
//        plane_node.eulerAngles = cameraEulerAngles
//        //plane_node.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
//        self.scene.rootNode.addChildNode(plane_node)
//
//        print()
        
//        let sphereCamera:SCNGeometry = SCNPlane(width: 0.294217, height: 0.3922889)
//        sphereCamera.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.0)
//        let cameraNode = SCNNode(geometry: sphereCamera)
//        cameraNode.camera = SCNCamera()
//        print(cameraNode.camera?.zFar) //100.0
//        print(cameraNode.camera?.zNear) //1.0
//        cameraNode.camera?.zNear = 0.0
//        cameraNode.position = cameraPosition
////        cameraNode.position.z = cameraPosition.z + 1.0
////        cameraNode.position.x = cameraPosition.x + 0.7
//        cameraNode.eulerAngles = cameraEulerAngles
//        self.scene.rootNode.addChildNode(cameraNode)
        
        let sphere:SCNGeometry = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.3)
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.camera?.zNear = 0.0
        sphereNode.position = SCNVector3(0, 0, 0.3)
        self.scene.rootNode.addChildNode(sphereNode)
        
        
//        //psn gesuture
//        let pan = UIPanGestureRecognizer(
//            target: self,
//            action: #selector(type(of: self).scenePanGesture(_:))
//        )
//        pan.delegate = self
//        sceneView.addGestureRecognizer(pan)
        
//        //pinch gesuture
//        let pinch = UIPinchGestureRecognizer(
//            target: self,
//            action: #selector(type(of: self).scenePinchGesture(_:))
//        )
//        pinch.delegate = self
//        sceneView.addGestureRecognizer(pinch)

//        // rotate gesture
//        let rotaion = UIRotationGestureRecognizer(
//            target: self,
//            action: #selector(type(of: self).sceneRotateGesture(_:))
//        )
//        rotaion.delegate = self
//        sceneView.addGestureRecognizer(rotaion)

//        cameraNode.camera = SCNCamera()
//        cameraNode.name = "camera"
//        cameraNode.scale = SCNVector3(x: 0.1, y: 0.1, z: 0.1)
//        cameraNode.eulerAngles.x = -Float.pi/2
//        cameraNode.position = .init(0, 0.5, 0)
//        scene.rootNode.addChildNode(cameraNode)
//        print(cameraNode.transform)
//        print(cameraNode.eulerAngles)
//        print(cameraNode.orientation)
        
//        let quat = cameraNode.orientation
//        //エンティティの回転角を取得
//        let argue = make_oirar(w: quat.w, x: quat.x, y: quat.y, z: quat.z)
//        //回転角から動く方向を決定
//        let dis_x = -sin(argue)
//        let dis_z = cos(argue)
//        let dis_yoko_x = -sin(argue + (Float.pi/2.0))
//        let dis_yoko_z = cos(argue + (Float.pi/2.0))
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            
        }
    }
    
//    func read_json(name: String) -> json_pointcloudUniforms {
//        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
//            fatalError("ファイルが見つからない")
//        }
//        guard let data = try? Data(contentsOf: url) else {
//            fatalError("ファイル読み込みエラー")
//        }
//        let decoder = JSONDecoder()
//        guard let datas = try? decoder.decode(json_pointcloudUniforms.self, from: data) else {
//            fatalError("JSON読み込みエラー")
//        }
//
//        return datas
//    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        self.database_model_num = results[section_num].cells[cell_num].models.count
        //let modelname = "NaviModel01-0"

        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            
            if results[section_num].cells[cell_num].models[current_model_num].exit_mesh == 1 {
                let mesh_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
                if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
                    referenceNode.load()
                    referenceNode.name = "mesh"
                    self.scene.rootNode.addChildNode(referenceNode)
                }
            }
            
            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
                let txt_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).txt")
                guard let fileContents = try? String(contentsOf: txt_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                let row = fileContents.components(separatedBy: "\n")
                let vertice_count = Int(row[0])!
                
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                
                //let points_data = try NSData(contentsOf: data_model_name)
                
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                print(data.count)
                print(data)
                let decoder = JSONDecoder()
                guard let datas = try? decoder.decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }
                let points_data = NSData(bytes: datas, length: MemoryLayout<PointCloudVertex>.size * vertice_count)
                
                let node = self.buildNode2(vertexData: points_data, count: vertice_count)
                node.position = SCNVector3(x: 0, y: 0, z: 0)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func mesh_valueChanged(_ sender: UISlider) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "mesh", recursively: false) {
            node.opacity =  CGFloat(sender.value)
        }
    }
    
    
    @IBAction func Tapped_hukan(_ sender: UIButton) {
        //let location = CGPoint(x: self.view.bounds.width/2, y: 1050/2)
        let locate = [CGPoint(x: 0, y: 0),
                      CGPoint(x: self.view.bounds.width, y: 0),
                      CGPoint(x: 0, y: self.view.bounds.height),
                      CGPoint(x: self.view.bounds.width, y: self.view.bounds.height),
                      CGPoint(x: self.view.bounds.width/2, y: self.view.bounds.height/2)]
        
        for (i,points) in locate.enumerated() {
            let hitResults = sceneView.hitTest(points, options: [:])
            if !hitResults.isEmpty {
                let posi = hitResults[0].worldCoordinates
                print("\(i) : \(posi)")
            }
        }
        
//        let hitResults = sceneView.hitTest(location, options: [:])
//        print(hitResults)
//        if !hitResults.isEmpty {
//            let posi = hitResults[0].worldCoordinates
//            print(posi)
//        }
        
        
        
        
//        //sceneView.allowsCameraControl = false
//        //panGesture.toggle()
//
//        cameraNode.eulerAngles.x = -Float.pi/2
//        cameraNode.position = .init(0, 0.5, 0)
//
//
//
////        if let node = self.sceneView.scene!.rootNode.childNode(withName: "camera", recursively: false) {
////            print("tapped Hukan")
////            node.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
////        }
//
////        print(sceneView.cameraControlConfiguration.rotationSensitivity)
////        print(sceneView.cameraControlConfiguration.flyModeVelocity)
////        print(sceneView.cameraControlConfiguration.panSensitivity)
////        print(sceneView.cameraControlConfiguration.truckSensitivity)
////        print(sceneView.cameraControlConfiguration.allowsTranslation)
//
//        print(sceneView.defaultCameraController)
//        print(sceneView.defaultCameraController.autoContentAccessingProxy)
//        print(sceneView.defaultCameraController.interactionMode)
        
    }
    
    @objc func scenePanGesture(_ recognizer: UIPanGestureRecognizer) {
        //if panGesture == true {
            //タッチした位置を基準にして左右がx，上下がyで右下に行くほど値が大きくなる
            let translation = recognizer.translation(in: recognizer.view!)
            print(translation)
        
            if let node = self.sceneView.scene!.rootNode.childNode(withName: "camera", recursively: false) {
                let posi = node.position
                print(posi)
                node.position = SCNVector3(posi.x + Float(translation.x)/500, posi.y - Float(translation.y)/500, posi.z)
                print("position:\(node.position)")
                recognizer.setTranslation(CGPoint.zero, in: recognizer.view!)
            }
        //}
    }
    
    //拡大・縮小
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            lastGestureScale = 1
        }
    
        let newGestureScale: Float = Float(recognizer.scale)
        print("newGestureScale: \(newGestureScale)")
    
        // ここで直前のscaleとのdiffぶんだけ取得しときます
        let diff = newGestureScale - lastGestureScale
        print("diff: \(diff)")
    
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "camera", recursively: false) {
            let posi = node.position
            //node.position = SCNVector3(posi.x + Float(translation.x)/500, posi.y - Float(translation.y)/500, posi.z)
//            //diff分だけscaleを変化させる。1は1倍、1.2は1.2倍
//            node.scale = SCNVector3Make(
//                currentScale.x * (1 + diff),
//                currentScale.y * (1 + diff),
//                currentScale.z * (1 + diff)
//            )
        }
        lastGestureScale = newGestureScale
        print("lastGestureScale: \(lastGestureScale)")
    }
    
    func make_oirar(w: Float, x: Float, y: Float, z: Float) -> Float {
        var thita_x: Float
        var thita_y: Float
        var thita_z: Float
        
        let m00 = 1-2*y*y-2*z*z
        let m01 = 2*x*y+2*w*z
        //let m02 = 2*x*z-2*w*y
        let m10 = 2*x*y-2*w*z
        let m11 = 1-2*x*x-2*z*z
        //let m12 = 2*y*z+2*w*x
        let m20 = 2*x*z+2*w*y
        let m21 = 2*y*z-2*w*x
        let m22 = 1-2*x*x-2*y*y
        
        if m21 == 1.0 {
            thita_x = Float.pi/2.0
            thita_y = 0
            thita_z = atan2(m10,m00)
        }
        else if m21 == -1.0 {
            thita_x = -1.0 * (Float.pi/2.0)
            thita_y = 0
            thita_z = atan2(m10,m00)
        }
        else {
            thita_x = asin(m21)
            thita_y = atan2(-m20,m22)
            thita_z = atan2(-m01,m11)
        }
        
        print("(x , y , z) = (\(String(format: "%f", thita_x)), \(String(format: "%f", thita_y)), \(String(format: "%f", thita_z)))")
        print("角度 : ",thita_y * (180.0/Float.pi))
        
        return thita_y
    }
    
    @objc func sceneRotateGesture(_ recognizer: UIRotationGestureRecognizer) {
        let newGestureRotation = Float(recognizer.rotation)
        print("newGestureRotation:\(newGestureRotation)")
    
        if recognizer.state == .began {
            lastGestureRotation = 0
        }
        // 前回とのdiffを取得
        let diff = newGestureRotation - lastGestureRotation
    
        // 今回はオイラーアングルのyを取るため、y軸中心の回転をさせます。
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "camera", recursively: false) {
            let eulerY = node.eulerAngles.y
            print("eulerY:\(eulerY)")
            node.eulerAngles.y = eulerY - diff
            print("eulerAngles.y:\(node.eulerAngles.y)")
        }
        lastGestureRotation = newGestureRotation
    }
    
    
    public func buildNode2(vertexData: NSData, count: Int) -> SCNNode {
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        
//        let normalSource = SCNGeometrySource(
//            data: normalsData as Data,
//            semantic: SCNGeometrySource.Semantic.normal,
//            vectorCount: count,
//            usesFloatComponents: true,
//            componentsPerVector: 3,
//            bytesPerComponent: MemoryLayout<Float>.size,
//            dataOffset: 0,
//            dataStride: MemoryLayout<vector_float3>.size
//        )
//        //SCNGeometrySource(normals: normals)
        
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: count,
            bytesPerIndex: MemoryLayout<Int>.size
        )

        // for bigger dots
        element.pointSize = 1
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 7

        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        
        return SCNNode(geometry: pointsGeometry)
    }
    
    @IBAction func right_Change(_ sender: UIButton) {
        if current_model_num < database_model_num - 1 {
            current_model_num += 1
            model_kirikae_hyouji()
            mesh_slider.value = 1.0
        }
    }
    
    @IBAction func left_change(_ sender: UIButton) {
        if current_model_num > 0 {
            current_model_num -= 1
            model_kirikae_hyouji()
            mesh_slider.value = 1.0
        }
    }
    
    func model_kirikae_hyouji() {
        if let node = sceneView.scene!.rootNode.childNode(withName: "mesh", recursively: false) {
            node.removeFromParentNode()
        }
        if let node = sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
            node.removeFromParentNode()
        }
        
        let realm = try! Realm()
        let results = realm.objects(Navi_SectionTitle.self)
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            if results[section_num].cells[cell_num].models[current_model_num].exit_mesh == 1 {
                let filename = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
                if let referenceNode = SCNReferenceNode(url: filename) {
                    referenceNode.load()
                    referenceNode.name = "mesh"
                    self.scene.rootNode.addChildNode(referenceNode)
                }
            }
            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
                let txt_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).txt")
                guard let fileContents = try? String(contentsOf: txt_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                let row = fileContents.components(separatedBy: "\n")
                let vertice_count = Int(row[0])!
                
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                //let points_data = try NSData(contentsOf: data_model_name)
                
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                let decoder = JSONDecoder()
                guard let datas = try? decoder.decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }
                let points_data = NSData(bytes: datas, length: MemoryLayout<PointCloudVertex>.size * vertice_count)
                
                let node = self.buildNode2(vertexData: points_data, count: vertice_count)
                node.position = SCNVector3(x: 0, y: 0, z: 0)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
}

//var pan_move: Float2 = [0, 0]
//var rotateVector: matrix_float4x4 = simd_float4x4(columns: (simd_float4(1,0,0,0),
//                                                            simd_float4(0,1,0,0),
//                                                            simd_float4(0,0,1,0),
//                                                            simd_float4(0,0,0,1)))

//var scale: Float = 1.0
        
