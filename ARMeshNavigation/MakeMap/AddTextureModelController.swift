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
    
    var texcoords2: [[SIMD2<Float>]] = []
    
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
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.5)
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
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        for i in 0..<count {
            let uiimage = UIImage(data: results[0].pic[i].pic_data!)
            uiimage_array.append(uiimage!)
        }
        let uiimg = UIImage(data: results[0].pic[0].pic_data!)
        //16384以下にする必要あり
        new_uiimage = ComposeUIImage(UIImageArray: uiimage_array, width: uiimg!.size.width * CGFloat(yoko), height: uiimg!.size.height * CGFloat(tate))
        imageView.image = new_uiimage
        
        print("\(uiimg!.size.width * CGFloat(yoko)), \((uiimg!.size.height) * CGFloat(tate))")
        print("\(new_uiimage?.size.width), \(new_uiimage?.size.height)") //2880.0, 3840.0
    }
    
    var vertex_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var mesh_array: [PointCloudVertex] = []
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
                //vertex_array.append([])
                
                let verticles = meshAnchor.geometry.vertices
                for _ in 0..<verticles.count {
                    texcoords2[count].append(SIMD2<Float>(0, 0))
                    
//                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
//                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
//                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
//                    let world_vertex4 = simd_mul(meshAnchor.transform, vertex4)
//                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
//                    vertex_array[count].append(world_vector3)
                }
                
//                let faces = meshAnchor.geometry.faces
//                for index in 0..<faces.count {
//                    let indicesPerFace = faces.indexCountPerPrimitive
//                    var face: [Int32] = []
//                    for offset in 0..<indicesPerFace {
//                        let vertexIndexAddress = faces.buffer.contents().advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
//                        face.append(Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
//                    }
//                    //face_array.append(face)
//                }
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
    
    @IBAction func tap_changeColor(_ sender: UIButton) {
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture_node", recursively: false) {
            node.opacity = 1.0
        }
    }
    
    @IBAction func tap_changeMesh(_ sender: UIButton) {
        if let node = sceneView.scene?.rootNode.childNode(withName: "texture_node", recursively: false) {
            node.opacity = 0.0
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "mesh_node", recursively: false) {
            node.opacity = 1.0
        }
    }
    
    func save_anchor() {
        //RGB画像
        let uiImage = new_uiimage
        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
        print("save:\(uiImage?.size)")
        
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
        
        print(results2)
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

    @IBAction func tap(_ sender: UIButton) {
        let count = results[0].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        
        DispatchQueue.global().sync {
            for i in 0..<count {
                print("\(i+1)回目：")
                //change_camera(num: i, yoko: yoko, tate: tate)
                let json_data = try? decoder.decode(json_parameta.self, from:results[0].json[i].json_data!)
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
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
