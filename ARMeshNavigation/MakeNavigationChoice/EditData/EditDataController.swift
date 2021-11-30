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
    var tex_bool: [[Bool]] = []
    var vertex_array: [[SCNVector3]] = []
    var normal_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var face_bool: [[Int]] = []
    
    var new_face_array: [[Int32]] = []
    var new_vertex_array: [[SCNVector3]] = []
    var new_normal_array: [[SCNVector3]] = []
    var new_texcoords2: [[SIMD2<Float>]] = []
    
    var new_uiimage: UIImage!
    var uiimage_array: [UIImage] = []
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var imageView2: UIImageView!
    @IBOutlet weak var ActivityView: UIActivityIndicatorView!
    
    var pixelData: [UInt8] = []
    var new_pixelData: [UInt8] = [UInt8](repeating: 0, count: 44236800)
    
    var objectName_array: [String] = []
    @IBOutlet weak var delete_finish_button: UIButton!
    @IBOutlet weak var depth_button: UIButton!
    
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
        depth_button.isHidden = true
        ActivityView.stopAnimating()
        //ActivityView.isHidden = true
        
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
    
    func triming(pointA: CGPoint, pointB: CGPoint) -> [CGPoint] {
        let Ax = Int(pointA.x)
        let Ay = Int(pointA.y)
        let Bx = Int(pointB.x)
        let By = Int(pointB.y)
        let n = abs(Bx - Ax) //横
        let m = abs(By - Ay) //縦
        
        var index: [CGPoint] = []
        var r_x = 1
        var r_y = -1
        if Bx - Ax < 0 {
            r_x = -1
        }
        if By - Ay > 0 {
            r_y = 1
        }
        
        if n == 0 {
            let nx = Ax
            var ny = Ay
            index.append(CGPoint(x: nx, y: ny))
            for _ in 1...m {
                ny += r_y
                index.append(CGPoint(x: nx, y: ny))
            }
        } else if m == 0 {
            var nx = Ax
            let ny = Ay
            index.append(CGPoint(x: nx, y: ny))
            for _ in 1...n {
                nx += r_x
                index.append(CGPoint(x: nx, y: ny))
            }
        } else {
            if m >= n {
                if (m % n) == 0 {
                    let p = m / n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for _ in 1...n {
                        nx += r_x
                        for _ in 0..<p {
                            ny += r_y
                            index.append(CGPoint(x: nx, y: ny))
                        }
                    }
                }
                if (m % n) != 0 {
                    let p = Int(floor(Double(m / n)))//m / n
                    let q = m % n
                    //let r = Int(floor(Double(n / q)))
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for i in 1...n {
                        nx += r_x
                        for _ in 0..<p {
                            ny += r_y
                            index.append(CGPoint(x: nx, y: ny))
                        }
                        if i == n {
                            for _ in 0..<q {
                                ny += r_y
                                index.append(CGPoint(x: nx, y: ny))
                            }
                        }
                    }
                }
            } else if m < n {
                if (n % m) == 0 {
                    let p = m / n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for _ in 1...m {
                        ny += r_y
                        for _ in 0..<p {
                            nx += r_x
                            index.append(CGPoint(x: nx, y: ny))
                        }
                    }
                }
                if (n % m) != 0 {
                    let p = Int(floor(Double(n / m)))//m / n
                    let q = m % n
                    var nx = Ax
                    var ny = Ay
                    index.append(CGPoint(x: nx, y: ny))
                    for i in 1...m {
                        ny += r_y
                        for _ in 0..<p {
                            nx += r_x
                            index.append(CGPoint(x: nx, y: ny))
                        }
                        if i == m {
                            for _ in 0..<q {
                                nx += r_x
                                index.append(CGPoint(x: nx, y: ny))
                            }
                        }
                    }
                }
            }
        }
        
        return index
    }
    
    func makeX(y: Int, pointA: CGPoint, pointB: CGPoint) -> Int {
        let a = Float(pointB.y - pointA.y) / Float(pointB.x - pointA.x)
        let x = (CGFloat(y) - pointA.y) / CGFloat(a) + pointA.x
        //print(x)
        return Int(round(x))
    }
    
    func get_pixelData(pixelData: [UInt8], pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) {
        //let XArray = [Int(pointA.x), Int(pointB.x), Int(pointC.x)]
        let YArray = [Int(pointA.y), Int(pointB.y), Int(pointC.y)]
        let points = [pointA, pointB, pointC]
        //let sortedXArray = XArray.enumerated().sorted{ $0.element < $1.element }.map{ $0.offset }
        let sortedYArray = YArray.enumerated().sorted{ $0.element < $1.element }.map{ $0.offset }
        //print(sortedYArray)
        
//        XArray.sort()
//        YArray.sort()
//        print(XArray)
//        print(YArray)
        
        for y in YArray[sortedYArray[0]]...YArray[sortedYArray[1]] {
            if (points[sortedYArray[1]].x < points[sortedYArray[2]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[1]])
                let right = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[2]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            } else if (points[sortedYArray[1]].x > points[sortedYArray[2]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[2]])
                let right = makeX(y: y, pointA: points[sortedYArray[0]], pointB: points[sortedYArray[1]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            }
        }
        for y in YArray[sortedYArray[1]]...YArray[sortedYArray[2]] {
            if (points[sortedYArray[0]].x < points[sortedYArray[1]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[0]])
                let right = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[1]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            } else if (points[sortedYArray[0]].x > points[sortedYArray[1]].x) {
                let left = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[1]])
                let right = makeX(y: y, pointA: points[sortedYArray[2]], pointB: points[sortedYArray[0]])
                //print("i, left, right = \(y), \(left), \(right)")
                if left < right {
                    for i in left...right {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                } else {
                    for i in right...left {
                        new_pixelData[4*2880*y+i*4] = pixelData[4*2880*y+i*4]
                        new_pixelData[4*2880*y+i*4+1] = pixelData[4*2880*y+i*4+1]
                        new_pixelData[4*2880*y+i*4+2] = pixelData[4*2880*y+i*4+2]
                        new_pixelData[4*2880*y+i*4+3] = pixelData[4*2880*y+i*4+3]
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        let image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[0].pic_data!)
//        imageView.image = image
//        pixelData = (image?.cgImage!.pixelData())!
//        //print(pixel_image)
//        print(pixelData.count)
//        print(pixelData[0..<20])
        
//        var new_pixelData: [UInt8] = [UInt8](repeating: 0, count: pixelData!.count)
//        for i in 4*2880*1000 ..< 4*2880*1050 + 1 {
//            new_pixelData[i] = pixelData![i]
//        }
//        for (i, n) in pixelData!.enumerated() {
//            if i > 4*2880*100 && i < 4*2880*1000 {
//                new_pixelData.append(n)
//            } else {
//                new_pixelData.append(255)
//            }
//        }

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
        //imageView.image = new_uiimage
        
        //メッシュ情報初期化
        for i in 0..<results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.count {
            let mesh_data = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].mesh
            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                anchors.append(meshAnchor)
            }
            texcoords2.append([])
            normal_array.append([])
            tex_bool.append([])
            vertex_array.append([])
            face_array.append([])
            face_bool.append([])
            
            new_face_array.append([])
            new_vertex_array.append([])
            new_normal_array.append([])
            new_face_array.append([])
            new_texcoords2.append([])
        }
        
//        let realm = try! Realm()
//        try! realm.write {
//            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 0
//        }
        
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 0 {
            load_anchor(tex_bool: false)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 2 {
            load_anchor2()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func tap_colorNode(_ sender: UIButton) {
        delete_mesh()
        if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 1 {
            load_anchor(tex_bool: true)
        } else if results[section_num].cells[cell_num].models[current_model_num].texture_bool == 2 {
            load_anchor2()
        }
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
    
    //MARK: -オブジェクト処理
    
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
    
    //MARK: -メッシュ処理
    @IBAction func tap_texture_riset(_ sender: UIButton) {
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 0
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.removeAll()
        }
        print(results[section_num].cells[cell_num].models[current_model_num].mesh_anchor)
        
        for anchor in anchors {
            guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            else{ return }
            try! realm.write {
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor.append(anchor_data(value: ["mesh": mesh_data]))
            }
        }
        
        
//        for i in 0..<texcoords2.count {
//            for j in 0..<texcoords2[i].count {
//                texcoords2[i][j] = SIMD2<Float>(0, 0)
//            }
//        }
//        save_model()
        delete_mesh()
        load_anchor(tex_bool: false)
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
                let texcoords = try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords as Data)
                let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords!)
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
    
    func load_anchor2() {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            
            let faces = try? decoder.decode([Int32].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces as Data)
            let texcoords = try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords as Data)
            
            let verticeSource = SCNGeometrySource(
                data: vertexData! as Data,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SCNVector3>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData! as Data,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SCNVector3>.size
            )
            let faceSource = SCNGeometryElement(indices: faces!, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords!)

            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage
            
            let node = SCNNode(geometry: nodeGeometry)
            
            knownAnchors[anchors[i].identifier] = node
            tex_node.addChildNode(node)
            //scene.rootNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(tex_node)
        print("load完了")
    }
    
    func save_model(num: Int) {
        for (i, _) in anchors.enumerated() {
            var texcoords_data = Data()
            var vertices_data = Data()
            var normals_data = Data()
            var faces_data = Data()
            
            if num != 2 {
                texcoords_data = try! JSONEncoder().encode(texcoords2[i])
                vertices_data = Data(bytes: vertex_array[i], count: MemoryLayout<SCNVector3>.size * vertex_array[i].count)
                normals_data = Data(bytes: normal_array[i], count: MemoryLayout<SCNVector3>.size * normal_array[i].count)
                if num == 1 {
                    faces_data = try! JSONEncoder().encode(new_face_array[i])
                } else {
                    faces_data = try! JSONEncoder().encode(face_array[i])
                }
            } else if num == 2 {
                texcoords_data = try! JSONEncoder().encode(new_texcoords2[i])
                vertices_data = Data(bytes: new_vertex_array[i], count: MemoryLayout<SCNVector3>.size * new_vertex_array[i].count)
                normals_data = Data(bytes: new_normal_array[i], count: MemoryLayout<SCNVector3>.size * new_normal_array[i].count)
                faces_data = try! JSONEncoder().encode(new_face_array[i])
            }
            
            let realm = try! Realm()
            try! realm.write {
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords = texcoords_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices = vertices_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals = normals_data
                results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces = faces_data
                if num != 2 {
                    results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count = vertex_array[i].count
                } else if num == 2 {
                    results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count = new_vertex_array[i].count
                }
            }
        }
        let realm = try! Realm()
        try! realm.write {
            if num == 0 {
                results[section_num].cells[cell_num].models[current_model_num].texture_bool = 1
            } else {
                results[section_num].cells[cell_num].models[current_model_num].texture_bool = 2
            }
        }
        print("save完了")
        //print(results[section_num].cells[cell_num].models[current_model_num])
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
        //ActivityView.isHidden = false
        ActivityView.startAnimating()
        make_texture(num: 0)
    }
    
    @IBAction func tap_newmakeTexture(_ sender: UIButton) {
        //ActivityView.isHidden = false
        ActivityView.startAnimating()
        make_texture(num: 1)
    }
    
    @IBAction func tap_makeTexture3(_ sender: UIButton) {
//        DispatchQueue.global().sync {
//            self.ActivityView.startAnimating()
            //make_texture(num: 2)
            make_texture1000(num: 2)
//            self.ActivityView.stopAnimating()
//        }
    }
    
    @IBAction func tap_saveButton(_ sender: UIButton) {
        //save_model()
    }
    
    func Make_meshInfo_Array() {
        for (i, meshAnchor) in anchors.enumerated() {
            texcoords2[i] = []
            tex_bool[i] = []
            vertex_array[i] = []
            face_array[i] = []
            face_bool[i] = []
            normal_array[i] = []
            
            let verticles = meshAnchor.geometry.vertices
            let normals = meshAnchor.geometry.normals
            for j in 0..<verticles.count {
                texcoords2[i].append(SIMD2<Float>(0, 0))
                tex_bool[i].append(false)
                
                let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                let world_vertex4 = simd_mul(meshAnchor.transform, vertex4)
                let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                vertex_array[i].append(world_vector3)
                
                let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * j))
                let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                normal_array[i].append(normal)
            }
            
            let faces = meshAnchor.geometry.faces
            for j in 0..<faces.count {
                let indicesPerFace = faces.indexCountPerPrimitive
                for offset in 0..<indicesPerFace {
                    let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                    let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                    face_array[i].append(per_face)
                }
                face_bool[i].append(-1)
            }
        }
    }
    
    func remake_mesh() {
        var num_array: [[Int]] = []
        
        for index in 0..<vertex_array.count {
            //new_face_array.append([])
            num_array = []
            for _ in 0..<(face_array[index].count) { // / 10)+1 {
                num_array.append([])
            }
            for i in 0..<face_array[index].count {
                let n = Int(face_array[index][i])
                if num_array[n].count == 0 {
                    num_array[n].append(Int(face_array[index][i]))
                    new_face_array[index].append(face_array[index][i])
                }
                else {
                    vertex_array[index].append(vertex_array[index][Int(face_array[index][i])])
                    normal_array[index].append(normal_array[index][Int(face_array[index][i])])
                    texcoords2[index].append(SIMD2<Float>(0, 0))
                    tex_bool[index].append(false)
                    new_face_array[index].append(Int32(vertex_array[index].count - 1))
                }
            }
        }
    }
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat, yoko: Float, num: CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        
        var tate_count = -1
        for (i,image) in UIImageArray.enumerated() {
            if i % Int(yoko) == 0 {
                tate_count += 1
            }
            // コンテキストに画像を描画する
            image.draw(in: CGRect(x: CGFloat(i % Int(yoko)) * image.size.width/num, y: CGFloat(tate_count) * image.size.height/num, width: image.size.width/num, height: image.size.height/num))
        }
        // コンテキストからUIImageを作る
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func make_texture1000(num: Int) {
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
        
        let start = Date()
        for i in 0..<count {
            let depth_array = try? decoder.decode([PointCloudVertex].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!)
            let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
            let cameraVector = SCNVector3(json_data!.cameraVector.x,
                                          json_data!.cameraVector.y,
                                          json_data!.cameraVector.z)
            let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                           json_data!.viewMatrix.y,
                                           json_data!.viewMatrix.z,
                                           json_data!.viewMatrix.w)
            let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                 json_data!.projectionMatrix.y,
                                                 json_data!.projectionMatrix.z,
                                                 json_data!.projectionMatrix.w)
            let matrix = projectionMatrix * viewMatrix
            calcTextureCoordinates2000(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector, depthArray: depth_array!, matrix: matrix)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        print("処理時間：\(elapsed)")
        save_model(num: num)
        delete_mesh()
        load_anchor2()
    }
    
    func make_texture(num: Int) {
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
            let start = Date()
            if num != 2 {
                Make_meshInfo_Array()
            }
            if num == 1 {
                remake_mesh()
            }
            
            for i in 0..<count {
                let depth_array = try? decoder.decode([PointCloudVertex].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!)
                let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[i].json_data!)
                let cameraPosition = SCNVector3(json_data!.cameraPosition.x,
                                                json_data!.cameraPosition.y,
                                                json_data!.cameraPosition.z)
                let cameraEulerAngles = SCNVector3(json_data!.cameraEulerAngles.x,
                                                   json_data!.cameraEulerAngles.y,
                                                   json_data!.cameraEulerAngles.z)
                let cameraVector = SCNVector3(json_data!.cameraVector.x,
                                              json_data!.cameraVector.y,
                                              json_data!.cameraVector.z)
                
                let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                               json_data!.viewMatrix.y,
                                               json_data!.viewMatrix.z,
                                               json_data!.viewMatrix.w)
                let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                     json_data!.projectionMatrix.y,
                                                     json_data!.projectionMatrix.z,
                                                     json_data!.projectionMatrix.w)
                let matrix = projectionMatrix * viewMatrix
                
                let move = SCNAction.move(to: cameraPosition, duration: 0)
                let rotation = SCNAction.rotateBy(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
                cameraNode.runAction(SCNAction.group([move, rotation]),
                                     completionHandler: { [self] in
                    if num == 0 {
                        calcTextureCoordinates(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector)
                    } else if num == 1 {
                        calcTextureCoordinates5(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector)
                    } else if num == 2 {
                        calcTextureCoordinates1000(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector, depthArray: depth_array!, matrix: matrix)
                    }
                    
                    if i+1 == count {
                        DispatchQueue.main.sync {
                            let elapsed = Date().timeIntervalSince(start)
                            print("処理時間：\(elapsed)")
                            //Alert()
                            save_model(num: num)
                            delete_mesh()
                            if num == 0 {
                                //ActivityView.isHidden = true
                                ActivityView.stopAnimating()
                                load_anchor(tex_bool: true)
                            } else {
                                //ActivityView.isHidden = true
                                ActivityView.stopAnimating()
                                load_anchor2()
//                                let image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[0].pic_data!)
//                                imageView2.image = image?.cgImage!.makeImage(pixelData: new_pixelData)
                            }
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
            //save_anchor()
            delete_mesh()
            load_anchor(tex_bool: true)
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    func calcTextureCoordinates(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3) {
        for (i, mesh_anchor) in anchors.enumerated() {
            let verticles = mesh_anchor.geometry.vertices
            //let normals = mesh_anchor.geometry.normals
            for j in 0..<verticles.count {
                let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                let world_vertex4 = simd_mul(mesh_anchor.transform, vertex4)
                let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                let pt = sceneView.projectPoint(world_vector3)
                
                //let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * j))
                //let normal = normalsPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                
                //let inner = normal.x * cameraVector.x + normal.y * cameraVector.y + normal.z * cameraVector.z
                //let thita = acos(inner) * 180.0 / .pi
                
                //if thita >= 135 {
                    if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                        let hitResults = sceneView.hitTest(CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)), options: [SCNHitTestOption.searchMode: 1])
                        if hitResults.count > 1 {
                            for (k, _) in hitResults.enumerated() {
                                if hitResults[k].node.name! == "child_tex_node" {
                                    let hitPoints = hitResults[k].worldCoordinates
                                    if sqrt((world_vector3.x - hitPoints.x)*(world_vector3.x - hitPoints.x) + (world_vector3.y - hitPoints.y)*(world_vector3.y - hitPoints.y) + (world_vector3.z - hitPoints.z)*(world_vector3.z - hitPoints.z)) < 0.001 {
                                        let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                                        let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                                        texcoords2[i][j] = SIMD2<Float>(u, v)
                                    }
                                    break
                                }
                            }
                        } else if hitResults.count == 1 {
                            if hitResults[0].node.name! == "child_tex_node" {
                                let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                                let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                                texcoords2[i][j] = SIMD2<Float>(u, v)
                            }
                        } else if hitResults.count == 0 {
                            let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            texcoords2[i][j] = SIMD2<Float>(u, v)
                        }
                        
//                        if !hitResults.isEmpty {
//                            if hitResults[0].node.name! == "child_tex_node" {
//                                let hitPoints = hitResults[0].worldCoordinates
//                                if abs(world_vector3.x - hitPoints.x) < 0.1 && abs(world_vector3.y - hitPoints.y) < 0.1 && abs(world_vector3.z - hitPoints.z) < 0.1 {
//                                    let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
//                                    let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
//                                    texcoords2[i][j] = SIMD2<Float>(u, v)
//                                }
//                            }
//                        }
//                        let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
//                        let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
//                        texcoords2[i][j] = SIMD2<Float>(u, v)
                    //}
                }
            }
        }
    }
    
    func calcTextureCoordinates2000(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3, depthArray: [PointCloudVertex], matrix: simd_float4x4){
        for (i, mesh_anchor) in anchors.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var perVerticles: [SCNVector3] = []
            var perNormals: [SCNVector3] = []
            var face_count = new_face_array[i].count - 1
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            for j in 0..<faces.count {
                for offset in 0..<faces.indexCountPerPrimitive {
                    let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                    let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * Int(per_face_index)))
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                    let world_vertex4 = simd_mul(mesh_anchor.transform, vertex4)
                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                    let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(per_face_index)))
                    let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                    //let inner = normal.x * cameraVector.x + normal.y * cameraVector.y + normal.z * cameraVector.z
                    //let thita = acos(inner) * 180.0 / .pi
                    
                    let clipSpacePosition = matrix * world_vertex4
                    let normalizedDeviceCoordinate = clipSpacePosition / clipSpacePosition.w
                    let pt = SCNVector3((CGFloat(normalizedDeviceCoordinate.x) + 1) * CGFloat(834 / 2),
                                        (-CGFloat(normalizedDeviceCoordinate.y) + 1) * CGFloat(1150 / 2),
                                        1 - (-CGFloat(normalizedDeviceCoordinate.z) + 1))
                    
                    //var pt = sceneView.projectPoint(world_vector3)
                    //print("projectPoint = \(pt), projection = \(projection)")
                    
                    //if thita <= 135 {
                    if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                        let du = Int(round((1 - pt.x / 834) * 95))
                        let dv = Int(round((pt.y / 1150) * 127))
                        let depthPosi = depthArray[du * 128 + dv]
                        let diff = sqrt((world_vector3.x - depthPosi.x)*(world_vector3.x - depthPosi.x) + (world_vector3.y - depthPosi.y)*(world_vector3.y - depthPosi.y) + (world_vector3.z - depthPosi.z)*(world_vector3.z - depthPosi.z))
                        if diff < 0.2 {
                            points.append(pt)
                            points_index.append(Int(per_face_index))
                            perVerticles.append(world_vector3)
                            perNormals.append(normal)
                        }
                    }
                }
                
                if points_index.count == 3 {
                    for (k, p) in points.enumerated() {
                        face_count += 1
                        let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                        let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                        new_texcoords2[i].append(SIMD2<Float>(u, v))
                        new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                        new_vertex_array[i].append(perVerticles[k])
                        new_normal_array[i].append(perNormals[k])
                    }
                }
                points = []
                points_index = []
                perVerticles = []
                perNormals = []
            }
            
        }
        print("calculate\(num)完了")
    }
    
    func calcTextureCoordinates1000(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3, depthArray: [PointCloudVertex], matrix: simd_float4x4){
        for (i, mesh_anchor) in anchors.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var perVerticles: [SCNVector3] = []
            var perNormals: [SCNVector3] = []
            //var faceNormal: [Bool] = []
            var face_count = new_face_array[i].count - 1
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            for j in 0..<faces.count {
//                if num == 0 {
//                    face_bool[i].append(-1)
//                }
                for offset in 0..<faces.indexCountPerPrimitive {
                    let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                    let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * Int(per_face_index)))
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                    let world_vertex4 = simd_mul(mesh_anchor.transform, vertex4)
                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                    let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(per_face_index)))
                    let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
//                    let inner = normal.x * cameraVector.x + normal.y * cameraVector.y + normal.z * cameraVector.z
//                    let thita = acos(inner) * 180.0 / .pi
                    
                    let clipSpacePosition = matrix * world_vertex4
                    let normalizedDeviceCoordinate = clipSpacePosition / clipSpacePosition.w
                    let projection = SCNVector3((CGFloat(normalizedDeviceCoordinate.x) + 1) * CGFloat(834 / 2),
                                                (-CGFloat(normalizedDeviceCoordinate.y) + 1) * CGFloat(1150 / 2),
                                                1 - (-CGFloat(normalizedDeviceCoordinate.z) + 1))

                    var pt = sceneView.projectPoint(world_vector3)
                    //print("projectPoint = \(pt), projection = \(projection)")
                    
                    //if thita <= 135 {
                        if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
    //                            let du = Int(round((1 - pt.x / 834) * 191))
    //                            let dv = Int(round((pt.y / 1150) * 255))
    //                            let depthPosi = depthArray[du * 256 + dv]
                            let du = Int(round((1 - pt.x / 834) * 95))
                            let dv = Int(round((pt.y / 1150) * 127))
                            let depthPosi = depthArray[du * 128 + dv]
                            let diff = sqrt((world_vector3.x - depthPosi.x)*(world_vector3.x - depthPosi.x) + (world_vector3.y - depthPosi.y)*(world_vector3.y - depthPosi.y) + (world_vector3.z - depthPosi.z)*(world_vector3.z - depthPosi.z))
                                //print("worldPosi = \(world_vector3), depthPosi = \(depthPosi)")
                                //print("diff = \(diff)")
                            if diff < 0.2 {
                                points.append(pt)
                                points_index.append(Int(per_face_index))
                                perVerticles.append(world_vector3)
                                perNormals.append(normal)
//                                if thita <= 135 {
//                                    faceNormal.append(true)
//                                }
                            }
                            
    //                        let hitResults = sceneView.hitTest(CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)), options: [SCNHitTestOption.searchMode: 1])
    //                        if hitResults.count > 1 {
    //                            for (hit, _) in hitResults.enumerated() {
    //                                if hitResults[hit].node.name! == "child_tex_node" {
    //                                    let hitPoints = hitResults[hit].worldCoordinates
    //                                    if sqrt((world_vector3.x - hitPoints.x)*(world_vector3.x - hitPoints.x) + (world_vector3.y - hitPoints.y)*(world_vector3.y - hitPoints.y) + (world_vector3.z - hitPoints.z)*(world_vector3.z - hitPoints.z)) < 0.001 {
    //                                        points.append(pt)
    //                                        points_index.append(Int(per_face_index))
    //                                    }
    //                                    break
    //                                }
    //                            }
    //                        } else if hitResults.count == 1 {
    //                            if hitResults[0].node.name! == "child_tex_node" {
    //                                points.append(pt)
    //                                points_index.append(Int(per_face_index))
    //                            }
    //                        } else if hitResults.count == 0 {
    //                            points.append(pt)
    //                            points_index.append(Int(per_face_index))
    //                        }
    //                        if offset == 0 && points_index.count < 1 {
    //                            break
    //                        }
                        }
                    //}
                }
                
                if points_index.count == 3 {//}&& face_bool[i][Int(floor(CGFloat(j)/3.0))] == -1 {
                    //face_bool[i][j] = i
                    for (k, p) in points.enumerated() {
                        face_count += 1
                        let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                        let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                        new_texcoords2[i].append(SIMD2<Float>(u, v))
                        new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                        new_vertex_array[i].append(perVerticles[k])
                        new_normal_array[i].append(perNormals[k])
//                        new_vertex_array[i].append(vertex_array[i][points_index[k]])
//                        new_normal_array[i].append(normal_array[i][points_index[k]])
                    }
//                    //内積確認
//                    let mesh_normals = SCNVector3(x: (perNormals[0].x + perNormals[1].x + perNormals[2].x)/3,
//                                                  y: (perNormals[0].y + perNormals[1].y + perNormals[2].y)/3,
//                                                  z: (perNormals[0].z + perNormals[1].z + perNormals[2].z)/3)
//                    let inner = mesh_normals.x * cameraVector.x + mesh_normals.y * cameraVector.y + mesh_normals.z * cameraVector.z
//                    let thita = acos(inner) * 180.0 / .pi
//                    if thita <= 135 {
//                        face_bool[i][Int(floor(CGFloat(j)/3.0))] = i
//                    }
//                    if faceNormal.count == 3 {
//                        face_bool[i][Int(floor(CGFloat(j)/3.0))] = i
//                    }
                }
                points = []
                points_index = []
                perVerticles = []
                perNormals = []
                //faceNormal = []
            }
            
        }
        print("calculate\(num)完了")
    }
    
    func calcTextureCoordinates100(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3){
        for (i, faces) in face_array.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var all_points: [[SCNVector3]] = []
            var all_points_index: [[Int]] = []
            var face_count = new_face_array[i].count - 1 //-1
            var now_face_count = -1
            
            for (j, index) in faces.enumerated() {
                let pt = sceneView.projectPoint(vertex_array[i][Int(index)])
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    let world_vector3 = vertex_array[i][Int(index)]
                    let hitResults = sceneView.hitTest(CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)), options: [SCNHitTestOption.searchMode: 1])
                    
                    if hitResults.count > 1 {
                        for (k, _) in hitResults.enumerated() {
                            if hitResults[k].node.name! == "child_tex_node" {
                                let hitPoints = hitResults[k].worldCoordinates
                                if sqrt((world_vector3.x - hitPoints.x)*(world_vector3.x - hitPoints.x) + (world_vector3.y - hitPoints.y)*(world_vector3.y - hitPoints.y) + (world_vector3.z - hitPoints.z)*(world_vector3.z - hitPoints.z)) < 0.001 {
                                    points.append(pt)
                                    points_index.append(Int(index))
                                }
                                break
                            }
                        }
                    } else if hitResults.count == 1 {
                        if hitResults[0].node.name! == "child_tex_node" {
                            points.append(pt)
                            points_index.append(Int(index))
                        }
                    } else if hitResults.count == 0 {
                        points.append(pt)
                        points_index.append(Int(index))
                    }
//                    points.append(pt)
//                    points_index.append(Int(index))
                }
                
                //面ごとの処理
                if j % 3 == 2 {
                    now_face_count += 1
                    if points_index.count == 3 {
                        all_points_index.append(points_index)
                        all_points.append(points)
                    }
                    points = []
                    points_index = []
                }
            }
            
            for l in 0..<all_points_index.count {
            //if face_bool[i][now_face_count] == -1 {
                face_bool[i][now_face_count] = i
                for (k, p) in all_points[l].enumerated() {
                    face_count += 1
                    let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                    let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                    new_texcoords2[i].append(SIMD2<Float>(u, v))
                    new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                    new_vertex_array[i].append(vertex_array[i][all_points_index[l][k]])
                    new_normal_array[i].append(normal_array[i][all_points_index[l][k]])
                }
            }
            all_points_index = []
            all_points = []
        }
        print("calculate完了")
//                        if num == 0 {
//                            get_pixelData(pixelData: pixelData,
//                                          pointA: CGPoint(x: CGFloat(points[0].x)/834 * 2880,
//                                                          y: CGFloat(points[0].y)/1150 * 3840),
//                                          pointB: CGPoint(x: CGFloat(points[1].x)/834 * 2880,
//                                                          y: CGFloat(points[1].y)/1150 * 3840),
//                                          pointC: CGPoint(x: CGFloat(points[2].x)/834 * 2880,
//                                                          y: CGFloat(points[2].y)/1150 * 3840))
//                        }
                        
////                        if face_bool[i][now_face_count] == -1 {
//                            face_bool[i][now_face_count] = i
//                            for (k, p) in points.enumerated() {
//                                face_count += 1
//                                let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
//                                let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
//                                new_texcoords2[i].append(SIMD2<Float>(u, v))
//                                //texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
//
//                                new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
//                                new_vertex_array[i].append(vertex_array[i][points_index[k]])
//                                new_normal_array[i].append(normal_array[i][points_index[k]])
                                
//                                let verticles = anchors[i].geometry.vertices
//                                let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * k))
//                                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
//                                let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
//                                let world_vertex4 = simd_mul(anchors[i].transform, vertex4)
//                                let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
//                                new_vertex_array[i].append(world_vector3)
//
//                                let normals = anchors[i].geometry.normals
//                                let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * k))
//                                let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
//                                new_normal_array[i].append(normal)
                                
//                            }
//                        }
//                    }
//                    points = []
//                    points_index = []
//                }
//            }
//        }
//        print("calculate完了")
    }
        
    func calcTextureCoordinates5(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3){
        for (i, faces) in new_face_array.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            for (j, index) in faces.enumerated() {
                let pt = sceneView.projectPoint(vertex_array[i][Int(index)])
                //let inner = normal_array[i][Int(index)].x * cameraVector.x + normal_array[i][Int(index)].y * cameraVector.y + normal_array[i][Int(index)].z * cameraVector.z
                //let thita = acos(inner) * 180.0 / .pi
                
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    let world_vector3 = vertex_array[i][Int(index)]
                    let hitResults = sceneView.hitTest(CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)), options: [SCNHitTestOption.searchMode: 1])
                    if hitResults.count > 1 {
                        for (k, _) in hitResults.enumerated() {
                            if hitResults[k].node.name! == "child_tex_node" {
                                let hitPoints = hitResults[k].worldCoordinates
                                if sqrt((world_vector3.x - hitPoints.x)*(world_vector3.x - hitPoints.x) + (world_vector3.y - hitPoints.y)*(world_vector3.y - hitPoints.y) + (world_vector3.z - hitPoints.z)*(world_vector3.z - hitPoints.z)) < 0.001 {
                                    points.append(pt)
                                    points_index.append(Int(index))
                                }
                                break
                            }
                        }
                    } else if hitResults.count == 1 {
                        if hitResults[0].node.name! == "child_tex_node" {
                            points.append(pt)
                            points_index.append(Int(index))
                        }
                    } else if hitResults.count == 0 {
                        points.append(pt)
                        points_index.append(Int(index))
                    }
                }
                if j % 3 == 2 {
                    if points_index.count == 3 {
                        for (k, p) in points.enumerated() {
                            let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
                            
//                            if texcoords2[i][points_index[k]] != SIMD2<Float>(0, 0) {
//                                if tex_bool[i][points_index[k]] == false {
//                                    if thita <= 135 {
//                                        texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
//                                        tex_bool[i][points_index[k]] = true
//                                    }
//                                }
//                            }
//                            else {
//                                texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
//                                if thita <= 135 {
//                                    tex_bool[i][points_index[k]] = true
//                                }
//                            }
                        }
                    }
                    
                    points = []
                    points_index = []
                }
            }
        }
        print("calculate完了")
    }
    
    //MARK: - 確認用
    var tap_count = -1
    @IBAction func tap_moveCamera(_ sender: UIButton) {
        if tap_count < results[section_num].cells[cell_num].models[current_model_num].pic.count - 1 {
            tap_count += 1
        }
        
        imageView.image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].pic[tap_count].pic_data!)
        
        let depth_array = try? decoder.decode([PointCloudVertex].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[tap_count].depth_data! as Data)
        var depth: [PointCloudVertex] = []
        for i in 0..<depth_array!.count {
            //if i < 257 {
                depth.append(depth_array![i])
            //}
        }
        
        let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[tap_count].json_data!)
        let cameraPosition = SCNVector3(json_data!.cameraPosition.x,
                                        json_data!.cameraPosition.y,
                                        json_data!.cameraPosition.z)
        let cameraEulerAngles = SCNVector3(json_data!.cameraEulerAngles.x,
                                           json_data!.cameraEulerAngles.y,
                                           json_data!.cameraEulerAngles.z)
        
        let move = SCNAction.move(to: cameraPosition, duration: 0)
        let rotation = SCNAction.rotateBy(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
        cameraNode.runAction(SCNAction.group([move, rotation]),
                             completionHandler: {
            let node = self.build_pointsNode(points: depth)
            node.name = "depth"
            self.scene.rootNode.addChildNode(node)
        })
        
    }
    
    @IBAction func Make_depthModel(_ sender: Any) {
        if tap_count < results[section_num].cells[cell_num].models[current_model_num].pic.count - 1 {
            tap_count += 1
        }
        
        
//        let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[section_num].cells[cell_num].models[current_model_num].json[tap_count].json_data!)
//        let intrinsics = simd_float3x3(json_data!.Intrinsics.x,
//                                       json_data!.Intrinsics.y,
//                                       json_data!.Intrinsics.z)
//        let viewMatrix = simd_float4x4(json_data!.ViewMatrix.x,
//                                       json_data!.ViewMatrix.y,
//                                       json_data!.ViewMatrix.z,
//                                       json_data!.ViewMatrix.w)
//
//        let depthArray = try? decoder.decode([Float32].self, from:results[section_num].cells[cell_num].models[current_model_num].depth[tap_count].depth_data!)
//        print(depthArray?.count)
//
////        let depth_image = UIImage(data: results[section_num].cells[cell_num].models[current_model_num].depth[tap_count].depth_data!)
////        print(depth_image?.size)
////        let depthMap = (depth_image?.pixelBuffer())!
////        print(depthMap)
////        let depthMap = toPixelBuffer(results[section_num].cells[cell_num].models[current_model_num].depth[tap_count].depth_data!, width: 256, height: 192, pixelFormat: kCVPixelFormatType_32BGRA)
//
////        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
////        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
////        let width = CVPixelBufferGetWidth(depthMap)
////        let height = CVPixelBufferGetHeight(depthMap)
////        print(width)
////        print(height)
////        let pointer = UnsafeMutableBufferPointer<Float32>(start: baseAddress!.assumingMemoryBound(to: Float32.self), count: width * height)
////        var depthArray: [Float32] = []
////        for x in (0 ..< 256).reversed() {
////            for y in (0 ..< 192).reversed() {
////                let index = y * width + x
////                depthArray.append(pointer[index])
////            }
////        }
////        CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
////        print(depthArray)
//
//        var vertice_data: [PointCloudVertex] = []
//        var depthSize = 186
//        let depthScreenScaleFactor = Float(self.sceneView.bounds.width * UIScreen.screens.first!.scale / CGFloat(depthSize))
//        let depthScreenScaleFactor_h = Float(self.sceneView.bounds.height * UIScreen.screens.first!.scale / CGFloat(256))
//        print(depthScreenScaleFactor)
//        print(depthScreenScaleFactor_h)
//        print(sceneView.bounds.width)
//        print(sceneView.bounds.height)
//        print(UIScreen.screens.first!.scale)
////        for y in 0 ..< depthSize {
////            for x in 0 ..< depthSize {
////                let depth = depthArray![y * depthSize + x]
////                if depth < 0 {
////                    continue
////                }
////                let x_px = Float(x) * depthScreenScaleFactor
////                let y_px = Float(y) * depthScreenScaleFactor
////                let localPoint = intrinsics * simd_float3(x_px, y_px, 1) * depth
////                let worldPoint = viewMatrix * simd_float4(localPoint, 1)
////                vertice_data.append(PointCloudVertex(x: worldPoint.x,
////                                                        y: worldPoint.y,
////                                                        z: worldPoint.z,
////                                                        r: 255,
////                                                        g: 255,
////                                                        b: 255))
////            }
////        }
//
//        //②
////        for x in (0 ..< 256) {
////            for y in 0 ..< 192 {
////                let depth = depthArray![y * 256 + x]
//////                if depth < 0 {
//////                    continue
//////                }
////                let x_px = Float(192-y) * depthScreenScaleFactor
////                let y_px = Float(256-x) * depthScreenScaleFactor_h
////                let localPoint = intrinsics * simd_float3(x_px, y_px, 1) * depth
////                let worldPoint = viewMatrix * simd_float4(localPoint, 1)
////                vertice_data.append(PointCloudVertex(x: worldPoint.x,
////                                                        y: worldPoint.y,
////                                                        z: worldPoint.z,
////                                                        r: 255,
////                                                        g: 255,
////                                                        b: 255))
////
////            }
////        }
//
////        for x in (0 ..< 192) {
////            for y in 0 ..< 256 {
////                let depth = depthArray![y * 192 + x]
////                if depth < 0 {
////                    continue
////                }
////                let x_px = Float(x) * depthScreenScaleFactor
////                let y_px = Float(y) * depthScreenScaleFactor_h
////                let localPoint = intrinsics * simd_float3(x_px, y_px, 1) * depth
////                let worldPoint = viewMatrix * simd_float4(localPoint, 1)
////                vertice_data.append(PointCloudVertex(x: worldPoint.x,
////                                                        y: worldPoint.y,
////                                                        z: worldPoint.z,
////                                                        r: 255,
////                                                        g: 255,
////                                                        b: 255))
////
////            }
////        }
//
//        //①
//        for y in 0 ..< 256 {
//            for x in 0 ..< 192 {
//                let depth = depthArray![y * 192 + x]
////                if depth < 0 {
////                    continue
////                }
//                let x_px = Float(x) * depthScreenScaleFactor
//                let y_px = Float(y) * depthScreenScaleFactor_h
//                let localPoint = intrinsics * simd_float3(x_px, y_px-300, 1) * depth
//                let worldPoint = viewMatrix * simd_float4(localPoint, 1)
//                vertice_data.append(PointCloudVertex(x: worldPoint.x,
//                                                     y: worldPoint.y,
//                                                     z: worldPoint.z,
//                                                     r: 255,
//                                                     g: 255,
//                                                     b: 255))
//
//            }
//        }
//
//        let node = build_pointsNode(points: vertice_data)
//        node.position = SCNVector3(x: 0, y: 0, z: 0)
//        node.name = "depth"
//        choiceNode_name = node.name!
//        self.scene.rootNode.addChildNode(node)
//
//        if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
//            node.removeFromParentNode()
//        }
//        let axis = ObjectOrigin().makeAxisNode()
//        axis.position = SCNVector3(x: 0, y: 0, z: 0)
//        axis.scale = SCNVector3(2.0, 2.0, 2.0)
//        sceneView.scene!.rootNode.addChildNode(axis)
    }
    
    //MARK: - その他
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
    
    @IBAction func to_ARView(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "EditData", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CheckARViewController") as! CheckARViewController
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
