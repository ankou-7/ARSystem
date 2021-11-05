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

class EditDataController: UIViewController, ARSCNViewDelegate,  UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate {
    
    //画面遷移した際のsectionとcellの番号を格納
    var section_num = Int()
    var cell_num = Int()
    
    var current_model_num = 0 //現在表示しているモデルの番号を格納
    var database_model_num = 1 //読み込んだcellの中に格納されているモデル数

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    let decoder = JSONDecoder()
    let results = try! Realm().objects(Navi_SectionTitle.self)
    var knownAnchors = Dictionary<UUID, SCNNode>()
    
    var anchors: [ARMeshAnchor] = []
    var texcoords2: [[SIMD2<Float>]] = []
    var new_uiimage: UIImage!
    var uiimage_array: [UIImage] = []
    @IBOutlet var imageView: UIImageView!
    
    var objectName_array: [String] = []
    var objectInfo: [(object_name: String, //オブジェクトの名前
                      object_name_identify: String, //個別の名前
                      object_num: Int, //オブジェクト番号
                      object_type: String, //オブジェクトの型
                      object_posi_x: Float,
                      object_posi_y: Float,
                      object_posi_z: Float,
                      object_scale_x: Float,
                      object_scale_y: Float,
                      object_scale_z: Float,
                      object_euler_x: Float,
                      object_euler_y: Float,
                      object_euler_z: Float)] = []
    
    var cameraNode = SCNNode()
    var lastGestureRotation: Float = 0.0
    var lastGestureScale: Float = 1.0
    
    @IBOutlet var left_modelbutton: UIButton!
    @IBOutlet var right_modelbutton: UIButton!
    @IBOutlet var modelname_label: UILabel!
    
    var ui_view = UIView()
    
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
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.0
        cameraNode.opacity = 0 //透明化
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.0)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        //lightNode.position = SCNVector3(x: 0, y: 10, z: -10)
        scene.rootNode.addChildNode(lightNode)
        
        if results[section_num].cells[cell_num].models.count < 2 {
            right_modelbutton.isHidden = true
            left_modelbutton.isHidden = true
            modelname_label.isHidden = true
        }
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(twoTap(gesture:)))
        doubleTapGesture.numberOfTapsRequired = 2
        sceneView.addGestureRecognizer(doubleTapGesture)
        
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
        
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        self.database_model_num = results[section_num].cells[cell_num].models.count
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        
        print(results[section_num].cells[cell_num].models[current_model_num].pic)
        for i in 0..<count {
            let uiimage = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        //16384以下にする必要あり
        new_uiimage = ComposeUIImage(UIImageArray: uiimage_array, width: 2880 * CGFloat(yoko), height: 3840 * CGFloat(tate))
        //imageView.image = new_uiimage
        
        for i in 0..<results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.count {
            let mesh_data = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].mesh
            if let mesh_anchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                anchors.append(mesh_anchor)
            }
            
            texcoords2.append([])
            let texcoords_data = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords
            guard let texcoords = try? decoder.decode([SIMD2<Float>].self, from: texcoords_data! as Data) else {
                fatalError("読み込みエラー")
            }
            
            texcoords2[i].append(contentsOf: texcoords)
        }
        
        print(results[section_num].cells[cell_num].models)
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else {
            load_anchor(tex_bool: false)
        }

        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            
//            if results[section_num].cells[cell_num].models[current_model_num].exit_mesh == 1 {
//                let mesh_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).scn")
//                if let referenceNode = SCNReferenceNode(url: mesh_model_name) {
//                    referenceNode.load()
//                    referenceNode.name = "mesh"
//                    self.scene.rootNode.addChildNode(referenceNode)
//                }
//            }
            
//            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
//                let txt_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).txt")
//                guard let fileContents = try? String(contentsOf: txt_model_name) else {
//                    fatalError("ファイル読み込みエラー")
//                }
//                let row = fileContents.components(separatedBy: "\n")
//                let vertice_count = Int(row[0])!
//
//                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
//
//                //let points_data = try NSData(contentsOf: data_model_name)
//
//                guard let data = try? Data(contentsOf: data_model_name) else {
//                    fatalError("ファイル読み込みエラー")
//                }
//                print(data.count)
//                print(data)
//                let decoder = JSONDecoder()
//                guard let datas = try? decoder.decode([PointCloudVertex].self, from: data) else {
//                    fatalError("JSON読み込みエラー")
//                }
//                let points_data = NSData(bytes: datas, length: MemoryLayout<PointCloudVertex>.size * vertice_count)
//
//                let node = self.buildNode2(vertexData: points_data, count: vertice_count)
//                node.position = SCNVector3(x: 0, y: 0, z: 0)
//                node.name = "point"
//                self.scene.rootNode.addChildNode(node)
//            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func tap_colorNode(_ sender: UIButton) {
        delete_mesh()
        load_anchor(tex_bool: true)
    }
    
    @IBAction func tap_meshNode(_ sender: UIButton) {
        delete_mesh()
        load_anchor(tex_bool: false)
    }
    
    var item = ObjectItem(name: "", id: 0, kind: "")
    let ObjectdataSource = ObjectModel()
    var select_object_num = 0
    var tap_object_flag = false
    
    @IBAction func tap_objectMenu_button(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "PopOver", bundle: nil)
        let contentVC = storyboard.instantiateViewController(withIdentifier: "MarkerPopOverController") as! MarkerPopOverController
        
        contentVC.modalPresentationStyle = .popover
        contentVC.preferredContentSize = CGSize(width: 100, height: 300)
        
        guard let popoverPresentationController = contentVC.popoverPresentationController else { return }
        
        popoverPresentationController.sourceView = view
        popoverPresentationController.sourceRect = sender.frame
        popoverPresentationController.permittedArrowDirections = .any
        popoverPresentationController.delegate = self
        
        contentVC.closure = { (num: Int) -> Void in
            self.select_object_num = num
            self.item = self.ObjectdataSource.item(row: self.select_object_num)
            print(self.select_object_num)
            print(self.item)
        }
        
        tap_object_flag = true
        
        present(contentVC, animated: true, completion: nil)
    }
    
    @objc fileprivate func twoTap(gesture: UITapGestureRecognizer) {
        if gesture.numberOfTapsRequired == 2 {
            // ダブルタップ時の動作
            
        }
    }
    
    var touchMove_flag = false
    var choiceNode_name: String!
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        let hitResults = sceneView.hitTest(location, options: [:])
        for result in hitResults {
            if result.node.parent?.name == "axis" {
                sceneView.allowsCameraControl = false
            }
        }
        startAxisDrag(screenPos: location)
        touchMove_flag = false
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        updateAxisDrag(screenPos: location)
        touchMove_flag = true
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: self.sceneView)
        endAxisDrag(screenPos: location)
        sceneView.allowsCameraControl = true
        
        if touchMove_flag == false {
            if tap_object_flag == true {
                let hitResults = sceneView.hitTest(location, options: [:])
                print(hitResults)
                if hitResults.count > 0 {
                    //print(hitResults[0].node.parent?.name)
                    
//                    for (i, name) in objectName_array.enumerated() {
//                        if hitResults[0].node.name == name {
//                            if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
//                                node.removeFromParentNode()
//                            }
//                            let axis = ObjectOrigin().makeAxisNode()
//                            axis.position = SCNVector3(objectInfo[i].object_posi_x, objectInfo[i].object_posi_y, objectInfo[i].object_posi_z)
//                            axis.scale = SCNVector3(2.0, 2.0, 2.0)
//                            sceneView.scene!.rootNode.addChildNode(axis)
//                        }
//                    }
                    
                    if hitResults[0].node.name == "child_tex_node" {
                        let posi = hitResults[0].worldCoordinates
                        guard let url = Bundle.main.url(forResource: "art.scnassets/\(item.name)", withExtension: "usdz") else { return }
                        let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                        let node = scene.rootNode.childNode(withName: item.name, recursively: true)
                        node?.scale = SCNVector3(0.01, 0.01, 0.01)
                        node?.position = posi
                        node!.name = item.name + String(objectInfo.count)
                        choiceNode_name = item.name + String(objectInfo.count)
                        let scale = node?.scale
                        let euler = node?.eulerAngles
                        objectName_array.append(node!.name!)
                        let info = (object_name: item.name, object_name_identify: node!.name!, object_num: item.id, object_type: item.kind, object_posi_x: posi.x, object_posi_y: posi.y, object_posi_z: posi.z, object_scale_x: scale!.x, object_scale_y: scale!.y, object_scale_z: scale!.z, object_euler_x: euler!.x, object_euler_y: euler!.y, object_euler_z: euler!.z)
                        objectInfo.append(info)
                        print(objectInfo)
                        print(objectName_array)
                        
                        if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                            node.removeFromParentNode()
                        }
                        
                        //座標軸
                        let axis = ObjectOrigin().makeAxisNode()
                        axis.position = posi
                        axis.scale = SCNVector3(2.0, 2.0, 2.0)
                        sceneView.scene!.rootNode.addChildNode(axis)
                        //node?.addChildNode(axis)
                        
                        sceneView.scene!.rootNode.addChildNode(node!)
                        
                        //tap_object_flag = false
                        touchMove_flag = false
                    }
                }
            }
        }
    }
    
    var origin_posi = CGPoint(x: 0, y: 0)
    var distance: Float = 0.0
    var pre_screenPos = CGPoint(x: 0, y: 0)
    var select_node: SCNNode!
    var start_flag = false
    
    func startAxisDrag(screenPos: CGPoint) {
        let hitResults = sceneView.hitTest(screenPos, options: [:])
        for result in hitResults {
            
            if result.node.parent?.name == "axis" {
                let posi = sceneView.projectPoint(result.node.parent!.position)
                origin_posi = CGPoint(x: CGFloat(posi.x), y: CGFloat(posi.y))
                distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
                pre_screenPos = screenPos
                select_node = result.node
                start_flag = true
                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            }
        }
    }
    
    func updateAxisDrag(screenPos: CGPoint) {
        if start_flag == true {
            let posi = sceneView.projectPoint(select_node.parent!.position)
            let now_distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
            let diff = now_distance - distance
            let translation = screenPos.y - pre_screenPos.y
            if select_node.name == "XAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
            }
            else if select_node.name == "YAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
            }
            else if select_node.name == "ZAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
            }
            else if select_node.name == "XCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
            }
            else if select_node.name == "YCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
            }
            else if select_node.name == "ZCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
            }
            let now_posi = sceneView.projectPoint(select_node.parent!.position)
            origin_posi = CGPoint(x: CGFloat(now_posi.x), y: CGFloat(now_posi.y))
            distance = sqrt((now_posi.x - Float(screenPos.x)) * (now_posi.x - Float(screenPos.x)) + (now_posi.y - Float(screenPos.y)) * (now_posi.y - Float(screenPos.y)))
            pre_screenPos = screenPos
        }
    }
    
    func endAxisDrag(screenPos: CGPoint) {
        if start_flag == true {
            start_flag = false
            
            if let node = sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                let posi = node.position
                let scale = node.scale
                let euler = node.eulerAngles
                let num = objectName_array.firstIndex(of: choiceNode_name)!
                print(num)
                
                objectInfo[num].object_posi_x = posi.x
                objectInfo[num].object_posi_y = posi.y
                objectInfo[num].object_posi_z = posi.z
                objectInfo[num].object_scale_x = scale.x
                objectInfo[num].object_scale_y = scale.y
                objectInfo[num].object_scale_z = scale.z
                objectInfo[num].object_euler_x = euler.x
                objectInfo[num].object_euler_y = euler.y
                objectInfo[num].object_euler_z = euler.z
                
                print(objectInfo)
            }
            
            if select_node.name == "XAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
            else if select_node.name == "XCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
        }
    }
    
    func load_anchor(tex_bool: Bool) {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for (i, mesh_anchor) in anchors.enumerated() {
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
            let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
            let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
            let facesElement = SCNGeometryElement(data: data, primitiveType: convertType(type: faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
            var sources = [verticesSource, normalsSource]
            
            if tex_bool == true {
                let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords2[i])
                sources.append(textureCoordinates)
            }
            
            let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
            nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage
            
            if tex_bool == false {
                let defaultMaterial = SCNMaterial()
                defaultMaterial.fillMode = .lines
                defaultMaterial.diffuse.contents = UIColor.green
                nodeGeometry.materials = [defaultMaterial]
            }
            
            let node = SCNNode(geometry: nodeGeometry)
            node.simdTransform = mesh_anchor.transform
            knownAnchors[mesh_anchor.identifier] = node
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
            //scene.rootNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(tex_node)
        print("load完了")
    }
    
    func save_anchor() {
        for (i, _) in anchors.enumerated() {
            let texcoords_data = try! JSONEncoder().encode(texcoords2[i])
            
            let realm = try! Realm()
            try! realm.write {
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords = texcoords_data
            }
        }
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 1
        }
        print(results[section_num].cells[cell_num].models)
        print("save完了")
    }
    
    func delete_mesh() {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
        knownAnchors = Dictionary<UUID, SCNNode>()
    }
    
    func convertType(type: ARGeometryPrimitiveType) -> SCNGeometryPrimitiveType {
        switch type {
        case .line:
            return .line
        case .triangle:
            return .triangles
        @unknown default:
            fatalError("unknown type")
        }
    }
    
    @IBAction func tap_makeTexture_button(_ sender: UIButton) {
        make_texture()
    }
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意.
        UIGraphicsBeginImageContext(CGSize(width: width/2, height: height/2))
        
        var num = -1
        // UIImageのある分回す.
        for (i,image) in UIImageArray.enumerated() {
            if i % 4 == 0 {
                num += 1
            }
            // コンテキストに画像を描画する.
            image.draw(in: CGRect(x: CGFloat(i % 4) * image.size.width/2, y: CGFloat(num) * image.size.height/2, width: image.size.width/2, height: image.size.height/2))
        }
        // コンテキストからUIImageを作る.
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        // コンテキストを閉じる.
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func make_texture() {
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        
        //RGB画像
        let uiImage = new_uiimage
        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
        
        //内部パラメータ保存用
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].texture_pic = imageData
        }
        
        DispatchQueue.global().sync {
            for i in 0..<count {
                print("\(i+1)回目：")
                let json_data = try? decoder.decode(json_pointcloudUniforms.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
                let cameraPosition = SCNVector3(json_data!.cameraPosition.x,
                                                json_data!.cameraPosition.y,
                                                json_data!.cameraPosition.z)
                let cameraEulerAngles = SCNVector3(json_data!.cameraEulerAngles.x,
                                                   json_data!.cameraEulerAngles.y,
                                                   json_data!.cameraEulerAngles.z)
                
                let move = SCNAction.move(to: cameraPosition, duration: 0)
                let rotation = SCNAction.rotateTo(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
                cameraNode.runAction(SCNAction.group([move, rotation]),
                                     completionHandler: { [self] in
                    calcTextureCoordinates(num: i, yoko: yoko, tate: tate)
                    print("\(i+1)：完了")
                    if i+1 == count {
                        print("全周完了")
                        DispatchQueue.main.sync {
                            
                            Alert()
                        }
                        
                    }
                })
            }
            
        }
    }
    
    @objc func Alert() {
        let title = "テクスチャ座標計算完了"
        let message = "モデルを表示しますか"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            save_anchor()
            delete_mesh()
            load_anchor(tex_bool: true)
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    func calcTextureCoordinates(num: Int, yoko: Float, tate: Float) {
        for (i, mesh_anchor) in anchors.enumerated() {
            let verticles = mesh_anchor.geometry.vertices
            for j in 0..<verticles.count {
                let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                let world_vertex4 = simd_mul(mesh_anchor.transform, vertex4)
                let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                let pt = sceneView.projectPoint(world_vector3)
                
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                    let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                    texcoords2[i][j] = SIMD2<Float>(u, v)
                }
            }
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
