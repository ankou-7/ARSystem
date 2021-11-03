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
    
    var uiimage1: UIImage!
    var uiimage2: UIImage!
    var new_uiimage: UIImage!
    var new_uiimage2: UIImage!
    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var imageview1: UIImageView!
    @IBOutlet weak var imageview2: UIImageView!
    @IBOutlet weak var imageview3: UIImageView!
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
//        let results2 = self.realm.objects(Anchors_data.self)
//        print(results2)
//        print(results2[results2.count-1].pic)
//        imageview2.image = UIImage(data: results2[results2.count-1].pic)
        
        //座標軸
        //let axis = ObjectOrigin().makeAxisNode()
        //scene.rootNode.addChildNode(axis)
        
        //選択した特徴点マッチングのための画像表示
//        uiimage1 = UIImage(data: results[0].pic[0].pic_data!)
//        print(uiimage1.size)
        //        let num = 1//results[0].pic.count-1
//        uiimage2 = UIImage(data: results[0].pic[num].pic_data!)
//        imageview1.image = uiimage1
//        imageview2.image = uiimage2
//        new_uiimage = ComposeUIImage(UIImageArray: [uiimage1, uiimage2], width: uiimage1.size.width * 2, height: uiimage2.size.height * 2)
        //        print(new_uiimage?.size!)
//        //imageview3.image = new_uiimage
        imageview.isHidden = true
        imageview1.isHidden = true
        imageview2.isHidden = true
        //imageview3.isHidden = true
        
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
        imageview3.image = new_uiimage
        
        //let uiimage = UIImage(data: results[0].pic[0].pic_data!)
        print("\(uiimg!.size.width * CGFloat(yoko)), \((uiimg!.size.height) * CGFloat(tate))")
        print(new_uiimage?.size) //2880.0, 3840.0
        
//        let resizeScale = 0.5
//        let resizeScale_y = 0.5
//        let resizedColorImage = CIImage(cgImage: new_uiimage.cgImage!).transformed(by: CGAffineTransform(scaleX: resizeScale, y: resizeScale_y))
//        print(UIImage(ciImage: resizedColorImage).size)
//        imageview2.image = UIImage(ciImage: resizedColorImage)
//        new_uiimage2 = UIImage(ciImage: resizedColorImage)
        
//        json_data1 = try? decoder.decode(json_parameta.self, from:results[0].json[0].json_data!)
//        json_data2 = try? decoder.decode(json_parameta.self, from: results[0].json[num].json_data!)
    }
    
    var vertex_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var mesh_array: [PointCloudVertex] = []
    let realm = try! Realm()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var count = -1
        for anchor in anchors {
            var sceneNode : SCNNode?

            if let meshAnchor = anchor as? ARMeshAnchor {
                let meshGeo = SCNGeometry.fromAnchor(meshAnchor:meshAnchor)
                sceneNode = SCNNode(geometry:meshGeo)
                anchor_count += 1
                count += 1
                texcoords2.append([])
                //vertex_array.append([])
                
                let verticles = meshAnchor.geometry.vertices
                for i in 0..<verticles.count {
                    texcoords2[count].append(SIMD2<Float>(0, 0))
                    
                    let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                    let world_vertex4 = simd_mul(meshAnchor.transform, vertex4)
                    let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                    //vertex_array[count].append(world_vector3)
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
                scene.rootNode.addChildNode(node)
            }
        }
        //print(texcoords2)
        
//        print(vertex_array)
//        print(face_array)
//        print("texcoords座標数：\(texcoords.count)")
//        print("頂点数：\(vertex_array.count)")
//        print("面数：\(face_array.count)")
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
        
        let decoder = JSONDecoder()
        let results2 = self.realm.objects(Anchors_data.self)
        
        let image = UIImage(data: results2[results2.count-1].pic!)
        print("load:\(image?.size)")
        
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
                scene.rootNode.addChildNode(node)
            }
        }
        print("load完了")
    }
    
    @IBAction func load_mesh(_ sender: UIButton) {
        load_anchor()
    }
    
    
    func ComposeUIImage(UIImageArray : [UIImage], width: CGFloat, height : CGFloat)->UIImage!{
        // 指定された画像の大きさのコンテキストを用意.
        UIGraphicsBeginImageContext(CGSize(width: width/2, height: height/2))
        
        let count = UIImageArray.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
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
    
    
    
    @IBAction func trans(_ sender: UIButton) {
        print("Add")
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                print("貼り付け")
                node.geometry?.firstMaterial?.diffuse.contents = new_uiimage
            }
        }
    }
    
    @IBAction func trans2(_ sender: UIButton) {
        let count = results[0].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        let num = 0
        change_camera(num: num, yoko: yoko, tate: tate)
    }

    var tap_count = -1
    @IBAction func tap(_ sender: UIButton) {
        let count = results[0].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        
        DispatchQueue.global().sync {
            for i in 0..<count {
//        if tap_count < count {
//            tap_count += 1
//            print("\(tap_count+1)回目：")
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
                            Alert()
                        }
                        
                    }
                })
                //Thread.sleep(forTimeInterval: 0.5)
            }
            
        }
    }
    
    @objc func Alert() {
        //var alertTextField: UITextField?
        let title = "テクスチャ座標計算完了"
        let message = "モデルを表示しますか"
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            delete_mesh()
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
            
            //cameraNode.position = cameraPosition
            //cameraNode.eulerAngles = cameraEulerAngles
            
            let move = SCNAction.move(to: cameraPosition, duration: 0)
            let rotation = SCNAction.rotateTo(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
            cameraNode.runAction(SCNAction.group([move, rotation]),
                                 completionHandler: { [self] in
                //make_mesh(num: num, yoko: yoko, tate: tate)
                calcTextureCoordinates(num: num, yoko: yoko, tate: tate)
                //calcTextureCoordinates3(width: 834, height: 1150, num: num, yoko: yoko, tate: tate)
                print("\(num+1)：完了")
            })
            
            //        let cameraTransform = simd_float4x4(json_data.cameraTransform.x,
            //                                            json_data.cameraTransform.y,
            //                                            json_data.cameraTransform.z,
            //                                            json_data.cameraTransform.w)
            //        cameraNode.simdTransform = cameraTransform
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
    
    func make_mesh(num: Int, yoko: Float, tate: Float) {
        delete_mesh()
        var count = -1
        for anchor in anchors {
            if let mesh_anchor = anchor as? ARMeshAnchor {
                count += 1
                let verticles = mesh_anchor.geometry.vertices
                let normals = mesh_anchor.geometry.normals
                let faces = mesh_anchor.geometry.faces
                let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
                let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
                let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
                let facesElement = SCNGeometryElement(data: data, primitiveType: convertType(type: faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
                var sources = [verticesSource, normalsSource]
                
                //calcTextureCoordinates(num: num, yoko: yoko, tate: tate)
                
                let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords2[count])
                print(texcoords2[count])
                sources.append(textureCoordinates)
                
                let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
                nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage
                let node = SCNNode(geometry: nodeGeometry)
                node.simdTransform = anchor.transform
                knownAnchors[anchor.identifier] = node
                
//                // SCNProgram作成
//                let program = SCNProgram()
//                program.vertexFunctionName = "vertexShader"
//                program.fragmentFunctionName = "fragmentShader"
//
//                // シェーダをマテリアルに適用
//                if let material = node.geometry?.firstMaterial {
//                    let imageProperty = SCNMaterialProperty(contents: new_uiimage!)
//                    material.setValue(imageProperty, forKey: "texture")
//                    material.program = program
//                }
                
                scene.rootNode.addChildNode(node)
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
    
    var anchor_count = 0
    @IBAction func point(_ sender: UIButton) {
        //delete_mesh()
        let count = results[0].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        //make_mesh(num: tap_count, yoko: yoko, tate: tate)
    
        //保存
        save_anchor()
    }
    
    func delete_mesh() {
        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
            }
        }
        knownAnchors = Dictionary<UUID, SCNNode>()
    }
    
    func calcTextureCoordinates4(verticles: ARGeometrySource, modelMatrix: simd_float4x4, width: Float, height: Float, num: Int, yoko: Float, tate: Float) -> SCNGeometrySource? {
        var coords: [SIMD2<Float>] = []
        for i in 0..<verticles.count {
            let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
            let world_vertex4 = simd_mul(modelMatrix, vertex4)
            let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
            let pt = sceneView.projectPoint(world_vector3)
            
            if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                //print("3次元：\(world_vertex4):2次元：\(pt)")
                //mesh_array.append(PointCloudVertex(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z, r: 255, g: 0, b: 0))
                let u = pt.x / (width * yoko)  + Float((num % Int(yoko))) / yoko
                let v = pt.y / (height * tate) + Float(floor(Float(num) / yoko)) / tate
                //if texcoords[i] == SIMD2<Float>(0.0, 0.0) {
                    //print(SIMD2<Float>(u, v))
                    //texcoords[i] = SIMD2<Float>(u, v)
                coords.append(SIMD2<Float>(u, v))
                //}
            } else {
                coords.append(SIMD2<Float>(0, 0))
            }
        }
        let result = SCNGeometrySource(textureCoordinates: coords)
        
        return result
    }
    
    @IBAction func tap2(_ sender: UIButton) {
        let count = results[0].pic.count
        let yoko: Float = 4.0
        let tate: Float = ceil(Float(count)/4.0)
        
        for anchor in anchors {
            if let mesh_anchor = anchor as? ARMeshAnchor {
                let verticles = mesh_anchor.geometry.vertices
                let normals = mesh_anchor.geometry.normals
                let faces = mesh_anchor.geometry.faces
                let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
                let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
                let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
                let facesElement = SCNGeometryElement(data: data, primitiveType: convertType(type: faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
                var sources = [verticesSource, normalsSource]
                let textureCoordinates = calcTextureCoordinates4(verticles: verticles, modelMatrix: anchor.transform, width: 834, height: 1150, num: 0, yoko: yoko, tate: tate)!
                sources.append(textureCoordinates)
                
                let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
                nodeGeometry.firstMaterial?.diffuse.contents = new_uiimage

                let node = SCNNode(geometry: nodeGeometry)
                node.simdTransform = anchor.transform
                scene.rootNode.addChildNode(node)
            }
        }
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}


//func calcTextureCoordinates(verticles: ARGeometrySource, modelMatrix: simd_float4x4, width: Float, height: Float, num: Int) ->  SCNGeometrySource? {
//
//        var count = 0
//        for i in 0..<verticles.count {
//            let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * i))
//            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
//            let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
//            let world_vertex4 = simd_mul(modelMatrix, vertex4)
//            let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
//            let pt = sceneView.projectPoint(world_vector3)
////            let u = pt.x / (width * 2)  + Float(num - 1) / 2.0
////            let v = pt.y / (height * 2)
//            if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
////                let p = CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y))
////                let hitResults = sceneView.hitTest(p, options: [:])
////                if !hitResults.isEmpty {
//                    let u = pt.x / (width * 2)  + Float(num - 1) / 2.0
//                    let v = pt.y / (height * 2)
//
//                    texcoords[i] = SIMD2<Float>(u, v)
//                    count = count + 1
//                    print("\(count) : \(pt)")
////                }
//            }
//
////            if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
////                texcoords[i] = SIMD2<Float>(u, v)
////                count = count + 1
////                print("\(count) : \(pt)")
////            }
//        }
//        print("texcoords.count = \(texcoords.count)")
//        let result = SCNGeometrySource(textureCoordinates: texcoords)
//        return result
//    }
