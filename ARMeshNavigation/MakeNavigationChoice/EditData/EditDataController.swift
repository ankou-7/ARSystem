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
    
    var anchors: [ARMeshAnchor]!
    var texcoords2: [[SIMD2<Float>]]!
    var new_uiimage: UIImage!
    var uiimage_array: [UIImage]!
    @IBOutlet var imageView: UIImageView!
    
    var objectName_array: [String] = []
    @IBOutlet weak var delete_finish_button: UIButton!
    
    var cameraNode = SCNNode()
    var lastGestureScale: Float = 1.0
    
    @IBOutlet var left_modelbutton: UIButton!
    @IBOutlet var right_modelbutton: UIButton!
    @IBOutlet var modelname_label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        
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
        scene.rootNode.addChildNode(lightNode)
        
        delete_finish_button.isHidden = true
        
        if results[section_num].cells[cell_num].models.count < 2 {
            right_modelbutton.isHidden = true
            left_modelbutton.isHidden = true
            modelname_label.isHidden = true
        }
        
        //pinch gesuture
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(type(of: self).scenePinchGesture(_:))
        )
        pinch.delegate = self
        sceneView.addGestureRecognizer(pinch)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        anchors = []
        texcoords2 = []
        uiimage_array = []
        
        for s in results[section_num].cells[cell_num].models[current_model_num].obj {
            objectName_array.append(s.name_identify)
        }
        
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        let num: CGFloat = 3.0 //画像のサイズの縮尺率
        print("pic_count：\(count)")
        
        for i in 0..<count {
            let uiimage = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        //16384以下にする必要あり
        new_uiimage = ComposeUIImage(UIImageArray: uiimage_array, width: (2880 / num) * CGFloat(yoko), height: (3840 / num) * CGFloat(tate), yoko: yoko, num: num)
        imageView.image = new_uiimage
        
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
        
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else {
            load_anchor(tex_bool: false)
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
    
    @IBAction func tap_pointNode(_ sender: UIButton) {
        delete_mesh()
        load_pointCloud()
    }
    
    func load_pointCloud() {
        let modelname = results[section_num].cells[cell_num].models[current_model_num].modelname
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            if results[section_num].cells[cell_num].models[current_model_num].exit_point == 1 {
                let data_model_name = documentDirectoryFileURL.appendingPathComponent("\(modelname).data")
                guard let data = try? Data(contentsOf: data_model_name) else {
                    fatalError("ファイル読み込みエラー")
                }
                guard let datas = try? JSONDecoder().decode([PointCloudVertex].self, from: data) else {
                    fatalError("JSON読み込みエラー")
                }

                let node = self.build_pointsNode(points: datas)
                node.name = "point"
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @IBAction func load_saveObject(_ sender: UIButton) {
        tap_object_flag = true
        if results[section_num].cells[cell_num].models[current_model_num].obj.count > 0 {
            for obj in results[section_num].cells[cell_num].models[current_model_num].obj {
                if obj.type == "usdz" {
                    guard let url = Bundle.main.url(forResource: "art.scnassets/\(obj.name)", withExtension: "usdz") else { return }
                    let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                    let node = scene.rootNode.childNode(withName: obj.name, recursively: true)
                    let json_data = try? decoder.decode(ObjectInfo_data.self, from: obj.info_data)
                    let posi = json_data!.Position
                    let scale = json_data?.Scale
                    let euler = json_data?.EulerAngles
                    node!.position = SCNVector3(posi.x, posi.y, posi.z)
                    node!.scale = SCNVector3(scale!.x, scale!.y, scale!.z)
                    node!.eulerAngles = SCNVector3(euler!.x, euler!.y, euler!.z)
                    node!.name = obj.name_identify
                    sceneView.scene!.rootNode.addChildNode(node!)
                }
            }
        }
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
        }
        
        tap_object_flag = true
        present(contentVC, animated: true, completion: nil)
    }
    
    var delete_flag = false
    
    @IBAction func delete_object(_ sender: UIButton) {
            let title = "配置オブジェクトの削除"
            let message = "削除したいオブジェクトをタップして下さい．"
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
                delete_finish_button.isHidden = false
                delete_flag = true
                if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                    node.removeFromParentNode()
                }
            })
                
            self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func tap_delete_finish_button(_ sender: UIButton) {
        delete_finish_button.isHidden = true
        delete_flag = false
    }
    
    
    var touchMove_flag = false
    var choiceNode_name: String = ""
    
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
                if delete_flag == false {
                    let hitResults = sceneView.hitTest(location, options: [:])
                    if hitResults.count > 0 {
                        for (i, name) in objectName_array.enumerated() {
                            if (hitResults[0].node.name == name ||
                                hitResults[0].node.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name){
                                if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                                    node.removeFromParentNode()
                                }
                                let axis = ObjectOrigin().makeAxisNode()
                                let json_data = try? decoder.decode(ObjectInfo_data.self, from:results[section_num].cells[cell_num].models[current_model_num].obj[i].info_data)
                                let posi = json_data!.Position
                                //let scale = json_data?.Scale
                                let euler = json_data?.EulerAngles
                                
                                axis.position = SCNVector3(posi.x, posi.y, posi.z)
                                axis.scale = SCNVector3(2.0, 2.0, 2.0)
                                axis.eulerAngles = SCNVector3(euler!.x, euler!.y, euler!.z)
                                sceneView.scene!.rootNode.addChildNode(axis)
                                choiceNode_name = name
                            }
                        }
                        
                        if hitResults[0].node.name == "child_tex_node" {
                            let posi = hitResults[0].worldCoordinates
                            guard let url = Bundle.main.url(forResource: "art.scnassets/\(item.name)", withExtension: "usdz") else { return }
                            let scene = try! SCNScene(url: url, options: [.checkConsistency: true])
                            let node = scene.rootNode.childNode(withName: item.name, recursively: true)
                            node?.scale = SCNVector3(0.01, 0.01, 0.01)
                            node?.position = posi
                            node!.name = item.name + String(results[section_num].cells[cell_num].models[current_model_num].add_obj_count)
                            sceneView.scene!.rootNode.addChildNode(node!)
                            
                            choiceNode_name = node!.name!
                            objectName_array.append(node!.name!)
                            
                            let entity = ObjectInfo_data(Position: Vector3Entity(x: posi.x,
                                                                                 y: posi.y,
                                                                                 z: posi.z),
                                                         Scale: Vector3Entity(x: (node?.scale.x)!,
                                                                              y: (node?.scale.y)!,
                                                                              z: (node?.scale.z)!),
                                                         EulerAngles: Vector3Entity(x: (node?.eulerAngles.x)!,
                                                                                    y: (node?.eulerAngles.y)!,
                                                                                    z: (node?.eulerAngles.z)!))
                            let json_data = try! JSONEncoder().encode(entity)
                            let realm = try! Realm()
                            try! realm.write {
                                results[section_num].cells[cell_num].models[current_model_num].add_obj_count += 1
                                results[section_num].cells[cell_num].models[current_model_num].obj.append(ObjectInfo(
                                    value: ["name": item.name,
                                            "name_identify": node!.name!,
                                            "type": item.kind,
                                            "info_data": json_data]))
                            }
                            
                            if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
                                node.removeFromParentNode()
                            }
                            let axis = ObjectOrigin().makeAxisNode()
                            axis.position = posi
                            axis.scale = SCNVector3(2.0, 2.0, 2.0)
                            sceneView.scene!.rootNode.addChildNode(axis)
                            
                            //tap_object_flag = false
                            touchMove_flag = false
                        }
                    }
                }
                else if delete_flag == true {
                    let hitResults = sceneView.hitTest(location, options: [:])
                    if hitResults.count > 0 {
                        for (i, name) in objectName_array.enumerated() {
                            if (hitResults[0].node.name == name ||
                                hitResults[0].node.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name ||
                                hitResults[0].node.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.parent?.name == name){
                                
                                sceneView.scene?.rootNode.childNode(withName: name, recursively: false)!.removeFromParentNode()
                                let realm = try! Realm()
                                try! realm.write {
                                    results[section_num].cells[cell_num].models[current_model_num].obj.remove(at: i)
                                }
                                objectName_array.remove(at: i)
                            }
                        }
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
                let num = objectName_array.firstIndex(of: choiceNode_name)!
                let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                                     y: node.position.y,
                                                                     z: node.position.z),
                                             Scale: Vector3Entity(x: node.scale.x,
                                                                  y: node.scale.y,
                                                                  z: node.scale.z),
                                             EulerAngles: Vector3Entity(x: node.eulerAngles.x,
                                                                        y: node.eulerAngles.y,
                                                                        z: node.eulerAngles.z))
                let json_data = try! JSONEncoder().encode(entity)
                let realm = try! Realm()
                try! realm.write {
                    results[section_num].cells[cell_num].models[current_model_num].obj[num].info_data = json_data
                }
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
    
    //拡大・縮小
    @objc func scenePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            lastGestureScale = 1
        }
    
        let newGestureScale: Float = Float(recognizer.scale)
        let diff = newGestureScale - lastGestureScale
    
        if !choiceNode_name.isEmpty {
            if let node = self.sceneView.scene!.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                let currentScale = node.scale
                //diff分だけscaleを変化させる。1は1倍、1.2は1.2倍
                node.scale = SCNVector3Make(
                    currentScale.x * (1 + diff),
                    currentScale.y * (1 + diff),
                    currentScale.z * (1 + diff)
                )
                
                let num = objectName_array.firstIndex(of: choiceNode_name)!
                let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                                     y: node.position.y,
                                                                     z: node.position.z),
                                             Scale: Vector3Entity(x: node.scale.x,
                                                                  y: node.scale.y,
                                                                  z: node.scale.z),
                                             EulerAngles: Vector3Entity(x: node.eulerAngles.x,
                                                                        y: node.eulerAngles.y,
                                                                        z: node.eulerAngles.z))
                let json_data = try! JSONEncoder().encode(entity)
                let realm = try! Realm()
                try! realm.write {
                    results[section_num].cells[cell_num].models[current_model_num].obj[num].info_data = json_data
                }
            }
            lastGestureScale = newGestureScale
        }
    }
    
    func load_anchor(tex_bool: Bool) {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for (i, mesh_anchor) in anchors.enumerated() {
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            
//            if i == 4 {
//                print(faces.count)
//                for j in 0..<faces.count {
//                    print(mesh_anchor.geometry.classificationOf(faceWithIndex: j).description)
//                }
            
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
//        }
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
        print("save完了")
    }
    
    func delete_mesh() {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
        knownAnchors = Dictionary<UUID, SCNNode>()
        
        if let node = sceneView.scene!.rootNode.childNode(withName: "point", recursively: false) {
            node.removeFromParentNode()
        }
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
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat, yoko: Float, num: CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意.
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        var tate_count = -1
        // UIImageのある分回す.
        for (i,image) in UIImageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する.
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る.
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        // コンテキストを閉じる.
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func make_texture() {
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        
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
                    if i+1 == count {
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
    
    private func build_pointsNode(points: [PointCloudVertex]) -> SCNNode {
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
        
    @IBAction func right_Change(_ sender: UIButton) {
        if current_model_num < database_model_num - 1 {
            current_model_num += 1
            model_kirikae_hyouji()
        }
    }
    
    @IBAction func left_change(_ sender: UIButton) {
        if current_model_num > 0 {
            current_model_num -= 1
            model_kirikae_hyouji()
        }
    }
    
    func model_kirikae_hyouji() {
        delete_mesh()
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else {
            load_anchor(tex_bool: false)
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
