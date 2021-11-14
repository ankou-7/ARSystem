//
//  AddTextureModelController.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/30.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift

class AddTextureModelController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    var cameraNode = SCNNode()
    
    var anchors: [ARAnchor] = []
    var knownAnchors = Dictionary<UUID, SCNNode>()
    let results = try! Realm().objects(Data_parameta.self)
    
    var new_uiimage: UIImage!
    @IBOutlet weak var imageView: UIImageView!
    let decoder = JSONDecoder()
    var json_data1: json_parameta!
    var json_data2: json_parameta!
    
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.0
        cameraNode.opacity = 0 //透明化
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(cameraNode)
        
//        //パラメータを一時的に保存する場所を初期化
//        try! realm.write {
//            realm.delete(realm.objects(Anchors_data.self))
//        }
        
        //座標軸
        //let axis = ObjectOrigin().makeAxisNode()
        //scene.rootNode.addChildNode(axis)
        
        var uiimage_array: [UIImage] = []
        let count = results[0].pic.count
        print("\(count)枚の画像")
        let yoko: Float = 17.0 //4.0
        let tate: Float = ceil(Float(count)/yoko)
        let num: CGFloat = 3.0 //画像のサイズの縮尺率
        for i in 0..<count {
            let uiimage = UIImage(data: results[0].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        //16384以下にする必要あり
        new_uiimage = ComposeUIImage(UIImageArray: uiimage_array, width: (2880 / num) * CGFloat(yoko), height: (3840 / num) * CGFloat(tate), yoko: yoko, num: num)
        imageView.image = new_uiimage
        
        activityView.isHidden = true
    }

    var texcoords2: [[SIMD2<Float>]] = []
    var tex_bool: [[Bool]] = []
    var vertex_array: [[SCNVector3]] = []
    var normal_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var new_face_array: [[Int32]] = []
    let realm = try! Realm()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let mesh_node = SCNNode()
        mesh_node.name = "mesh_node"

        var count = -1
        for anchor in anchors {
            var sceneNode : SCNNode?
            
            if let meshAnchor = anchor as? ARMeshAnchor {
                let meshGeo = SCNGeometry.fromAnchor(meshAnchor:meshAnchor)
                sceneNode = SCNNode(geometry:meshGeo)
                count += 1
                texcoords2.append([])
                tex_bool.append([])
                vertex_array.append([])
                face_array.append([])
                normal_array.append([])
                
                let verticles = meshAnchor.geometry.vertices
                let normals = meshAnchor.geometry.normals
                for i in 0..<verticles.count {
                    texcoords2[count].append(SIMD2<Float>(0, 0))
                    tex_bool[count].append(false)
                    
                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                    let world_vertex4 = simd_mul(meshAnchor.transform, vertex4)
                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                    vertex_array[count].append(world_vector3)
                    
                    let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * i))
                    let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                    normal_array[count].append(normal)
                }
                
                let faces = meshAnchor.geometry.faces
                for index in 0..<faces.count {
                    let indicesPerFace = faces.indexCountPerPrimitive
                    //var face: [Int32] = []
                    for offset in 0..<indicesPerFace {
                        let vertexIndexAddress = faces.buffer.contents().advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                        let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                        face_array[count].append(per_face)
                        //face.append(Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
                    }
                    //face_array[count].append(face)
                }
            }
            if let node = sceneNode {
                node.simdTransform = anchor.transform
                knownAnchors[anchor.identifier] = node
                mesh_node.addChildNode(node)
                //scene.rootNode.addChildNode(node)
            }
        }
        scene.rootNode.addChildNode(mesh_node)
    }
    
    func remake_model() {
        let start = Date()
        var num_array: [[Int]] = []
        
        for index in 0..<vertex_array.count {
            new_face_array.append([])
            num_array = []
            for _ in 0..<(face_array[index].count) { // / 10)+1 {
                num_array.append([])
            }
            print("-----------------------------------------------")
            print("変化前")
            print("vertex_count：\(vertex_array[index].count)")
            print("face_index_count：\(face_array[index].count)")
            let start2 = Date()
            for i in 0..<face_array[index].count {
//                let n = Int(face_array[index][i]) / 10
//                if num_array[n].firstIndex(of: Int(face_array[index][i])) == nil {
//                    num_array[n].append(Int(face_array[index][i]))
//                    new_face_array[index].append(face_array[index][i])
//                }
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
                
//                if new_face_array[index].firstIndex(of: face_array[index][i]) == nil {
//                    new_face_array[index].append(face_array[index][i])
//                }
//                else {
//                    vertex_array[index].append(vertex_array[index][Int(face_array[index][i])])
//                    normal_array[index].append(normal_array[index][Int(face_array[index][i])])
//                    texcoords2[index].append(SIMD2<Float>(0, 0))
//                    new_face_array[index].append(Int32(vertex_array[index].count - 1))
//                }
            }
            print("実行時間2：\(Date().timeIntervalSince(start2))")
            print("変化後")
            print("vertex_count：\(vertex_array[index].count)")
            print("new_face_index_count：\(new_face_array[index].count)")
        }
        print("完了")
        print("実行時間：\(Date().timeIntervalSince(start))")
    }
    
    func calcTextureCoordinates5(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3){
        for (i, faces) in new_face_array.enumerated() {
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            for (j, index) in faces.enumerated() {
                let pt = sceneView.projectPoint(vertex_array[i][Int(index)])
                let inner = normal_array[i][Int(index)].x * cameraVector.x + normal_array[i][Int(index)].y * cameraVector.y + normal_array[i][Int(index)].z * cameraVector.z
                let thita = acos(inner) * 180.0 / .pi
                
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    points.append(pt)
                    points_index.append(Int(index))
                }
                if j % 3 == 2 {
                    if points_index.count == 3 {
                        for (k, p) in points.enumerated() {
                            let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            if texcoords2[i][points_index[k]] != SIMD2<Float>(0, 0) {
                                if tex_bool[i][points_index[k]] == false {
                                    if thita <= 135 {
                                        texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
                                        tex_bool[i][points_index[k]] = true
                                    }
                                }
                            }
                            else {
                                texcoords2[i][points_index[k]] = SIMD2<Float>(u, v)
                                if thita <= 135 {
                                    tex_bool[i][points_index[k]] = true
                                }
                            }
                        }
                    }
                    points = []
                    points_index = []
                }
            }
        }
        print("calculate完了")
    }
    
    @IBAction func meke_model(_ sender: UIButton) {
        let count = results[0].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        
        DispatchQueue.global().sync {
            activityView.isHidden = false
            //delete_mesh()
            remake_model()
            
            for i in 0..<count {
                print("\(i+1)回目：")
                
//                self.asyncProcess(number: i) {
//                    (number: Int, cameraVector: SCNVector3) -> Void in
//                    print("#\(number) End")
//                    self.calcTextureCoordinates5(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector)
//                    if i+1 == count {
//                        print("全周完了")
//                        //DispatchQueue.main.sync {
//                            if let node = self.sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
//                                node.opacity = 0.0
//                            }
//                            self.make()
//                            self.activityView.isHidden = true
//                        //}
//                    }
//                }
                
                
                let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[0].json[i].json_data!)
                let cameraPosition = SCNVector3(json_data!.cameraPosition.x,
                                                json_data!.cameraPosition.y,
                                                json_data!.cameraPosition.z)
                let cameraEulerAngles = SCNVector3(json_data!.cameraEulerAngles.x,
                                                   json_data!.cameraEulerAngles.y,
                                                    json_data!.cameraEulerAngles.z)
                let cameraVector = SCNVector3(json_data!.cameraVector.x,
                                              json_data!.cameraVector.y,
                                              json_data!.cameraVector.z)
                let move = SCNAction.move(to: cameraPosition, duration: 0)
                let rotation = SCNAction.rotateBy(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
                cameraNode.runAction(SCNAction.group([move, rotation]),
                                     completionHandler: {
                    self.calcTextureCoordinates5(num: i, yoko: yoko, tate: tate, cameraVector: cameraVector)
                    if i+1 == count {
                        print("全周完了")
                        DispatchQueue.main.sync {
                            if let node = self.sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
                                node.opacity = 0.0
                            }
                            self.make()
                            self.activityView.isHidden = true
                        }
                    }
                })
            }
        }
        
//        let mesh_node = SCNNode()
//        mesh_node.name = "mesh2_node"
//
//        for i in 0..<vertex_array.count {
//            let verticesSource = SCNGeometrySource(vertices: vertex_array[i])
//            let normalsSource = SCNGeometrySource(normals: normal_array[i])
//            let faceSource = SCNGeometryElement(indices: new_face_array[i], primitiveType: .triangles)
//            let customGeometry = SCNGeometry(sources: [verticesSource, normalsSource], elements: [faceSource])
//
//            let defaultMaterial = SCNMaterial()
//            defaultMaterial.fillMode = .lines
//            defaultMaterial.diffuse.contents = UIColor.blue //UIColor(displayP3Red:1, green:1, blue:1, alpha:0.7)
//            customGeometry.materials = [defaultMaterial]
//            let node = SCNNode(geometry: customGeometry)
//            mesh_node.addChildNode(node)
//            //scene.rootNode.addChildNode(node)
//        }
//        scene.rootNode.addChildNode(mesh_node)
    }
    
    func asyncProcess(number: Int, completion: (_ number: Int, _ vector: SCNVector3) -> Void) {
        print("#\(number) Start")
        let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[0].json[number].json_data!)
        let cameraPosition = SCNVector3(-json_data!.cameraPosition.x,
                                        -json_data!.cameraPosition.y,
                                        -json_data!.cameraPosition.z)
        let cameraEulerAngles = SCNVector3(-json_data!.cameraEulerAngles.x,
                                           -json_data!.cameraEulerAngles.y,
                                           -json_data!.cameraEulerAngles.z)
        let cameraVector = SCNVector3(json_data!.cameraVector.x,
                                      json_data!.cameraVector.y,
                                      json_data!.cameraVector.z)
        
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
            node.position = cameraPosition
            node.eulerAngles = cameraEulerAngles
            print("node移動")
        }
        completion(number, cameraVector)
    }
    
    func make() {
        let c_node = SCNNode()
        c_node.name = "texture2_node"
        for i in 0..<vertex_array.count {
            let verticesSource = SCNGeometrySource(vertices: vertex_array[i])
            let normalsSource = SCNGeometrySource(normals: normal_array[i])
            let faceSource = SCNGeometryElement(indices: new_face_array[i], primitiveType: .triangles)
            
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords2[i])
            
            let customGeometry = SCNGeometry(sources: [verticesSource, normalsSource, textureCoordinates], elements: [faceSource])
            customGeometry.firstMaterial?.diffuse.contents = new_uiimage
            
            let node = SCNNode(geometry: customGeometry)
            c_node.addChildNode(node)
            //scene.rootNode.addChildNode(node)
        }
        scene.rootNode.addChildNode(c_node)
    }
    
    
    @IBAction func tap_changeColor(_ sender: UIButton) {
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh2_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture_node", recursively: false) {
            node.opacity = 1.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture2_node", recursively: false) {
            node.opacity = 1.0
        }
    }
    
    @IBAction func tap_changeMesh(_ sender: UIButton) {
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture2_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
            node.opacity = 1.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh2_node", recursively: false) {
            node.opacity = 1.0
        }
    }
    
    func save_anchor() {
        //RGB画像
        let uiImage = new_uiimage
        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
        
        //内部パラメータ保存用
        let results2 = self.realm.objects(Anchors_data.self)
        try! self.realm.write {
            self.realm.add(Anchors_data(value: ["num": results2.count,
                                                "pic": imageData!]))
        }
        
        var count = -1
        for anchor in anchors {
            if let mesh_anchor = anchor as? ARMeshAnchor {
                count += 1
                guard let mesh_data = try? NSKeyedArchiver.archivedData(withRootObject: mesh_anchor, requiringSecureCoding: true)
                else{ return }
                
                let texcoords_data = try! JSONEncoder().encode(texcoords2[count])
                
                try! realm.write {
                    results2[results2.count-1].anchor.append(anchor_data(value: ["mesh": mesh_data,
                                                                                 "texcoords": texcoords_data]))
                }
            }
        }
        print("save完了")
    }
    
    func load_anchor() {
        let results2 = self.realm.objects(Anchors_data.self)
        let image = UIImage(data: results2[results2.count-1].pic!)
        
        let texture_node = SCNNode()
        texture_node.name = "texture_node"
        
        for i in 0..<results2[results2.count-1].anchor.count {
            let mesh_data = results2[results2.count-1].anchor[i].mesh
            if let mesh_anchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
                
                let texcoords_data = results2[results2.count-1].anchor[i].texcoords
                guard let texcoords = try? decoder.decode([SIMD2<Float>].self, from: texcoords_data! as Data) else {
                    fatalError("読み込みエラー")
                }
                
                let verticles = mesh_anchor.geometry.vertices
                let normals = mesh_anchor.geometry.normals
                let faces = mesh_anchor.geometry.faces
                let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
                let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
                let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
                let facesElement = SCNGeometryElement(data: data, primitiveType: convertType(type: faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
                var sources = [verticesSource, normalsSource]
                
                let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)
                sources.append(textureCoordinates)
                
                let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
                nodeGeometry.firstMaterial?.diffuse.contents = image
                let node = SCNNode(geometry: nodeGeometry)
                node.simdTransform = mesh_anchor.transform
                texture_node.addChildNode(node)
                //scene.rootNode.addChildNode(node)
            }
        }
        scene.rootNode.addChildNode(texture_node)
        print("load完了")
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

    @IBAction func tap(_ sender: UIButton) {
        if let node = sceneView.scene?.rootNode.childNode(withName: "custom", recursively: false) {
            node.removeFromParentNode()
        }
        
        make_texture()
    }
    
    func make_texture() {
        let count = results[0].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        
        DispatchQueue.global().sync {
            for i in 0..<count {
                print("\(i+1)回目：")
                //change_camera(num: i, yoko: yoko, tate: tate)
                let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[0].json[i].json_data!)
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
                            save_anchor()
                            if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
                                node.opacity = 0.0
                            }
                            if let node = sceneView.scene?.rootNode.childNode(withName: "mesh2_node", recursively: false) {
                                node.opacity = 0.0
                            }
                            if let node = sceneView.scene?.rootNode.childNode(withName: "texture2_node", recursively: false) {
                                node.opacity = 0.0
                            }
                            Alert()
                        }
                        
                    }
                })
                //Thread.sleep(forTimeInterval: 0.5)
            }
            
        }
    }
    
    @objc func Alert() {
        let title = "テクスチャ座標計算完了"
        let message = "モデルを表示しますか"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            //delete_mesh()
            load_anchor()
        })
            
        self.present(alertController, animated: true, completion: nil)
    }
    
    func change_camera(num: Int, yoko: Float, tate: Float) {
        DispatchQueue.global().sync {
            let json_data = try? decoder.decode(json_parameta.self, from:results[0].json[num].json_data!)
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
                calcTextureCoordinates(num: num, yoko: yoko, tate: tate)
                //calcTextureCoordinates3(width: 834, height: 1150, num: num, yoko: yoko, tate: tate)
                print("\(num+1)：完了")
            })
        }
    }
    
    func calcTextureCoordinates(num: Int, yoko: Float, tate: Float) {
        var count = -1
        for anchor in anchors {
            if let mesh_anchor = anchor as? ARMeshAnchor {
                count += 1
                let verticles = mesh_anchor.geometry.vertices
                for i in 0..<verticles.count {
                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                    let world_vertex4 = simd_mul(anchor.transform, vertex4)
                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                    let pt = sceneView.projectPoint(world_vector3)
                    
                    if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                        let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                        let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                        //if texcoords[i] == SIMD2<Float>(0.0, 0.0) {
                        texcoords2[count][i] = SIMD2<Float>(u, v)
                        //}
                    }
                }
            }
        }
    }
    
    func calcTextureCoordinates3(num: Int, yoko: Float, tate: Float){
        for (index, vertexs) in vertex_array.enumerated() {
            for (i, vertex) in vertexs.enumerated() {
                let pt = sceneView.projectPoint(vertex)
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                    let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                    texcoords2[index][i] = SIMD2<Float>(u, v)
                }
            }
        }
    }
    
    func calcTextureCoordinates4(num: Int, yoko: Float, tate: Float){
        for (i, faces) in face_array.enumerated() {
            var in_points: [SCNVector3] = []
            var out_points: [SCNVector3] = []
            for (j, index) in faces.enumerated() {
                let pt = sceneView.projectPoint(vertex_array[i][Int(index)])
                if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                    in_points.append(pt)
                } else {
                    out_points.append(pt)
                }
                
                if j % 3 == 2 {
                    if in_points.count == 2 && out_points.count == 1 {
                        //新しい頂点の作成
                        print(in_points)
                        print(out_points)
                        new_vertexPoints(in_points: in_points, out_points: out_points)
                        
                    }
                    in_points = []
                    out_points = []
                }
            }
        }
    }
    
    func makeNode(posi: SCNVector3) {
        let node = SCNNode(geometry: SCNSphere(radius: 0.001))
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        node.position = posi
        self.scene.rootNode.addChildNode(node)
    }
    
    func new_vertexPoints(in_points: [SCNVector3], out_points: [SCNVector3]) {
        var a: SCNVector3!
        var b: SCNVector3!
        var c: SCNVector3!
        
        var d: CGPoint!
        var e: CGPoint!
        var d3: SCNVector3!
        var e3: SCNVector3!
        
        if in_points.count == 2 {
            a = in_points[0]
            b = in_points[1]
            c = out_points[0]
        }
        
        if c.y >= 0 && c.y <= 1150 && c.x < 0 {
            let x: CGFloat = 0
            d = CGPoint(x: x, y: y_point(x1: a.x, y1: a.y, x2: c.x, y2: c.y, x: x))
            e = CGPoint(x: x, y: y_point(x1: b.x, y1: b.y, x2: c.x, y2: c.y, x: x))
        }
        else if c.y >= 0 && c.y <= 1150 && c.x > 834 {
            let x: CGFloat = 834
            d = CGPoint(x: x, y: y_point(x1: a.x, y1: a.y, x2: c.x, y2: c.y, x: x))
            e = CGPoint(x: x, y: y_point(x1: b.x, y1: b.y, x2: c.x, y2: c.y, x: x))
        }
        else if c.x >= 0 && c.x <= 834 && c.y < 0 {
            let y: CGFloat = 0
            d = CGPoint(x: x_point(x1: a.x, y1: a.y, x2: c.x, y2: c.y, y: y), y: y)
            e = CGPoint(x: x_point(x1: b.x, y1: b.y, x2: c.x, y2: c.y, y: y), y: y)
        }
        else if c.x >= 0 && c.x <= 834 && c.y > 1150 {
            let y: CGFloat = 1150
            d = CGPoint(x: x_point(x1: a.x, y1: a.y, x2: c.x, y2: c.y, y: y), y: y)
            e = CGPoint(x: x_point(x1: b.x, y1: b.y, x2: c.x, y2: c.y, y: y), y: y)
        }
        
        
        print("d: \(d!)")
        print("e: \(e!)")
        
        let hitResults_d = sceneView.hitTest(d!, options: [:])
        if !hitResults_d.isEmpty {
            for j in 0..<hitResults_d.count {
                if  (hitResults_d[j].node.name != nil) {
                    if hitResults_d[j].node.name! == "custom" {
                        d3 = hitResults_d[0].worldCoordinates
                    }
                }
            }
        }
        let hitResults_e = sceneView.hitTest(e!, options: [:])
        if !hitResults_e.isEmpty {
            for j in 0..<hitResults_e.count {
                if  (hitResults_e[j].node.name != nil) {
                    if hitResults_e[j].node.name! == "custom" {
                        e3 = hitResults_e[0].worldCoordinates
                    }
                }
            }
        }
        
        guard let d33 = d3 else {
            print("d3error")
            return
        }
        guard let e33 = e3 else {
            print("e3error")
            return
        }
        print("d3: \(d33)")
        print("e3: \(e33)")
        
        makeNode(posi: d33)
        makeNode(posi: e33)
        
        return
    }
    
    func y_point(x1: Float, y1: Float, x2: Float, y2: Float, x: CGFloat) -> CGFloat{
        let y = ((y2-y1)/(x2-x1)) * (Float(x)-x1) + y1
        return CGFloat(y)
    }
    func x_point(x1: Float, y1: Float, x2: Float, y2: Float, y: CGFloat) -> CGFloat{
        let x = ((x2-x1)/(y2-y1)) * (Float(y)-y1) + x1
        return CGFloat(x)
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
    
    func delete_mesh() {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
        knownAnchors = Dictionary<UUID, SCNNode>()
        
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture_node", recursively: false) {
            node.removeFromParentNode()
        }
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
