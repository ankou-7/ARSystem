//
//  CPUCalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import RealmSwift
import ARKit
import Foundation

class CPUCalculateTexture {
    private var anchors: [ARMeshAnchor]
    private var models: Navi_Modelname
    private var picCount: Int
    private var calculateParameta: calculateParameta
    
    private var sceneView: SCNView
    private var cameraNode: SCNNode
    
//    private var cameraVector: SCNVector3!
//    private var calcuMatrix: simd_float4x4!
//    private var depth = [depthPosition]()
    
    var texcoords2: [[SIMD2<Float>]] = []
    var tex_bool: [[Bool]] = []
    var vertex_array: [[SCNVector3]] = []
    var normal_array: [[SCNVector3]] = []
    var face_array: [[Int32]] = []
    var face_bool: [[Int]] = []
    
    var new_face_array: [[Int32]] = []
    var new_vertex_array: [[SIMD3<Float>]] = []
    var new_normal_array: [[SIMD3<Float>]] = []
    var new_texcoords2: [[SIMD2<Float>]] = []
    
    var url: URL!
    
    //ポリゴン数の合計
    var sumPolygon = 0
    var texCount = 0
    var st = ""
    
    init(anchors: [ARMeshAnchor], models: Navi_Modelname, picCount: Int, calculateParameta: calculateParameta, cameraNode: SCNNode, sceneView: SCNView) {
        self.anchors = anchors
        self.models = models
        self.picCount = picCount
        self.calculateParameta = calculateParameta
        
        self.cameraNode = cameraNode
        self.sceneView = sceneView
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        setupArray()
    }
    
    func setupArray() {
        for _ in 0..<anchors.count {
            texcoords2.append([])
            normal_array.append([])
            tex_bool.append([])
            vertex_array.append([])
            face_array.append([])
            face_bool.append([])
            
            new_face_array.append([])
            new_vertex_array.append([])
            new_normal_array.append([])
            new_texcoords2.append([])
        }
    }
    
    func makeCPUTexture(completionHandler: @escaping () -> ()) {
        let start = Date()
        var time = ""
        print("calcu開始")
        for i in 0..<picCount {
            make_calcuParameta(num: i) { (dep, mat, vec) in
                self.calcTextureCoordinates(num: i, cameraVector: vec, depthArray: dep, matrix: mat)
                if i == 0 {
                    print("総ポリゴン数\(self.sumPolygon)")
                    self.st +=  """
                                総ポリゴン数
                                \(self.sumPolygon)
                                各パラメータでのテクスチャが割り当てられたポリゴン数\n
                                """
                }
                print("割り当てられたポリゴン数\(self.texCount)")
                self.st += "\(self.texCount)\n"
                time += "\(Date().timeIntervalSince(start))\n"
            }
            
        }
        st += time
        saveDocument(text: st, filename: "CPU")
        save_model()
        
        print("calcu終了")
        print("処理時間：\(Date().timeIntervalSince(start))")
        completionHandler()
    }
    
    func saveDocument(text: String, filename: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let archivePath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/\(filename).txt")
            do {
                try text.write(to: archivePath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func make_calcuParameta(num: Int, completionHandler: @escaping ([depthPosition], simd_float4x4, SCNVector3) -> ()) {
        let decoder = JSONDecoder()
        
        let depthPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/depth\(num).data")
        let depth = try? decoder.decode([depthPosition].self, from: try! Data(contentsOf: depthPath))
        
        let jsonPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/json\(num).data")
        let json_data = try? decoder.decode(MakeMap_parameta.self, from: try! Data(contentsOf: jsonPath))
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
        let calcuMatrix = projectionMatrix * viewMatrix
        
        completionHandler(depth!, calcuMatrix, cameraVector)
    }
    
    func calcTextureCoordinates(num: Int, cameraVector: SCNVector3, depthArray: [depthPosition], matrix: simd_float4x4){
        
        sumPolygon = 0
        for (i, mesh_anchor) in anchors.enumerated() {
            let tate = Float(calculateParameta.tate)
            let yoko = Float(calculateParameta.yoko)
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var perVerticles: [SCNVector3] = []
            var perNormals: [SCNVector3] = []
            var face_count = new_face_array[i].count - 1
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            sumPolygon += faces.count
            
            for j in 0..<faces.count {
                if num == 0 {
                    face_bool[i].append(-1)
                }
                if face_bool[i][j] == -1 {
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
                        //print("projectPoint = \(pt)")
                        
                        //if thita <= 135 {
                        if depthArray.count > 0 {
                            if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                                let du = Int(round((1 - pt.x / 834) * 95))
                                let dv = Int(round((pt.y / 1150) * 127))
                                //print(depthArray)
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
                    }
                    
                    if points_index.count == 3 {
                        texCount += 1
                        face_bool[i][j] = i
                        for (k, p) in points.enumerated() {
                            face_count += 1
                            let u = p.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = p.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            new_texcoords2[i].append(SIMD2<Float>(u, v))
                            new_face_array[i].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                            new_vertex_array[i].append(SIMD3<Float>(perVerticles[k]))
                            new_normal_array[i].append(SIMD3<Float>(perNormals[k]))
                        }
                    }
                    points = []
                    points_index = []
                    perVerticles = []
                    perNormals = []
                }
            }
            
        }
        print("calculate\(num)完了")
    }
    
    //MARK: - アンカー毎に全てのパラメータを処理
    func makeCPUTexture2(completionHandler: @escaping () -> ()) {
        let start = Date()
        var poly = ""
        var time = ""
        print("calcu開始")
        make_calcuParameta2() { (dep, mat) in
            for (i, anchor) in self.anchors.enumerated() {
                //処理
                self.calcTextureCoordinates2(num: i, anchor: anchor, depthArray: dep, matrixs: mat)
                poly += "\(self.sumPolygon)\n"
                time += "\(Date().timeIntervalSince(start))\n"
                print("calculate\(i)完了")
            }
        }
        
        st += poly + time
        saveDocument(text: st, filename: "バージョン2")
        save_model()
        
        print("calcu終了")
        print("処理時間：\(Date().timeIntervalSince(start))")
        completionHandler()
    }
    
    func make_calcuParameta2(completionHandler: @escaping ([depthPosition], [simd_float4x4]) -> ()) {
        let decoder = JSONDecoder()
        var calcuMatrix = [simd_float4x4]()
        var depth = [depthPosition]()
        
        for i in 0..<models.pic.count {
            
            let jsonPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/json\(i).data")
            let json_data = try? decoder.decode(MakeMap_parameta.self, from: try! Data(contentsOf: jsonPath))
            
            let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                           json_data!.viewMatrix.y,
                                           json_data!.viewMatrix.z,
                                           json_data!.viewMatrix.w)
            let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                                 json_data!.projectionMatrix.y,
                                                 json_data!.projectionMatrix.z,
                                                 json_data!.projectionMatrix.w)
            let matrix = projectionMatrix * viewMatrix
            calcuMatrix.append(matrix)
            
            let depthPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/depth\(i).data")
            let depth_array = try? decoder.decode([depthPosition].self, from: try! Data(contentsOf: depthPath))
            depth.append(contentsOf: depth_array!)
        }
        
        completionHandler(depth, calcuMatrix)
    }
    
    //１つのアンカーに対して全てのパラメータを処理
    func calcTextureCoordinates2(num: Int, anchor: ARMeshAnchor, depthArray: [depthPosition], matrixs: [simd_float4x4]){
        let tate = Float(calculateParameta.tate)
        let yoko = Float(calculateParameta.yoko)
        let scWidth = Float(calculateParameta.screenWidth)
        let scHeight = Float(calculateParameta.screenHeight)
        
        var face_count = new_face_array[num].count - 1 //新しく構成する頂点のインデックス番号（-1から）
        
        //アンカー情報
        let verticles = anchor.geometry.vertices
        let normals = anchor.geometry.normals
        let faces = anchor.geometry.faces
        sumPolygon += faces.count
        
        //全パラメータで処理
        for (i, matrix) in matrixs.enumerated() {
            for j in 0..<faces.count {
                if i == 0 {
                    face_bool[num].append(-1) //１番目のパラメータ処理時にポリゴン数だけ-1を格納（-1ならそのポリゴンはまだ処理してない）
                }
                if face_bool[num][j] == -1 {
                    //各ポリゴン毎に処理
                    var points: [SCNVector3] = [] //UV計算された頂点のスクリーン座標を格納
                    var perVerticles: [SCNVector3] = []
                    var perNormals: [SCNVector3] = []
                    
                    for offset in 0..<faces.indexCountPerPrimitive {
                        let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                        let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                        
                        let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * Int(per_face_index)))
                        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                        let world_vertex4 = simd_mul(anchor.transform, vertex4)
                        let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                        let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(per_face_index)))
                        let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                        
                        //ポリゴンの頂点座標（3次元）をスクリーン座標（2次元）に変換
                        let clipSpacePosition = matrix * world_vertex4
                        let normalizedDeviceCoordinate = clipSpacePosition / clipSpacePosition.w
                        let pt = SCNVector3((CGFloat(normalizedDeviceCoordinate.x) + 1) * CGFloat(834 / 2),
                                            (-CGFloat(normalizedDeviceCoordinate.y) + 1) * CGFloat(1150 / 2),
                                            1 - (-CGFloat(normalizedDeviceCoordinate.z) + 1))
                        
                        if depthArray.count > 0 {
                            if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= scHeight && pt.z < 1.0 {
                                let du = Int(round((1 - pt.x / 834) * 95))
                                let dv = Int(round((pt.y / 1150) * 127))
                                let depthPosi = depthArray[du * 128 + dv]
                                
                                let diff = sqrt((world_vector3.x - depthPosi.x)*(world_vector3.x - depthPosi.x) + (world_vector3.y - depthPosi.y)*(world_vector3.y - depthPosi.y) + (world_vector3.z - depthPosi.z)*(world_vector3.z - depthPosi.z))
                                if diff < 0.2 {
                                    points.append(pt)
                                    perVerticles.append(world_vector3)
                                    perNormals.append(normal)
                                }
                            }
                        }
                    }
                    
                    if points.count == 3 {
                        texCount += 1
                        face_bool[num][j] = num
                        
                        for (k, pt) in points.enumerated() {
                            face_count += 1
                            let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            
                            new_texcoords2[num].append(SIMD2<Float>(u, v))
                            new_face_array[num].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                            new_vertex_array[num].append(SIMD3<Float>(perVerticles[k]))
                            new_normal_array[num].append(SIMD3<Float>(perNormals[k]))
                        }
                    }
                }
            }
        }
    }
    
    //MARK: - hittestを用いた処理
    func makeCPUTexture3(completionHandler: @escaping () -> ()) {
        let start = Date()
        var poly = ""
        var time = ""
        var count = 0
        let max = 1//self.models.json.count
        
        print("calcu開始")
        make_calcuParameta2() { (dep, mat) in
            //DispatchQueue.global().sync {
            for j in 0..<1{//self.models.json.count {
                    let json_data = try? JSONDecoder().decode(MakeMap_parameta.self, from: self.models.json[j].json_data!)
                    let cameraPosition = SCNVector3(json_data!.cameraPosition.x,
                                                    json_data!.cameraPosition.y,
                                                    json_data!.cameraPosition.z)
                    let cameraEulerAngles = SCNVector3(json_data!.cameraEulerAngles.x,
                                                       json_data!.cameraEulerAngles.y,
                                                        json_data!.cameraEulerAngles.z)
                    let move = SCNAction.move(to: cameraPosition, duration: 0)
                    let rotation = SCNAction.rotateTo(x: CGFloat(cameraEulerAngles.x), y: CGFloat(cameraEulerAngles.y), z: CGFloat(cameraEulerAngles.z), duration: 0)
                    self.cameraNode.runAction(SCNAction.group([move, rotation]),
                                         completionHandler: {
                        //処理
                        for (i, anchor) in self.anchors.enumerated() {
                            self.calcTextureCoordinates3(num: i, anchor: anchor, matrixs: mat)
                            poly += "\(self.sumPolygon)\n"
                            time += "\(Date().timeIntervalSince(start))\n"
                            print(poly)
                            print(time)
                            print("calculate\(i)完了")
                        }
                        
                        count += 1
                        if count == max {
                            DispatchQueue.main.async {
                                self.st += poly + time
                                self.saveDocument(text: self.st, filename: "バージョン1")
                                self.save_model()
                                
                                print("calcu終了")
                                print("処理時間：\(Date().timeIntervalSince(start))")
                                completionHandler()
                            }
                        }
                    })
                //}
            }
        }
    }
    
    func calcTextureCoordinates3(num: Int, anchor: ARMeshAnchor, matrixs: [simd_float4x4]){
        let tate = Float(calculateParameta.tate)
        let yoko = Float(calculateParameta.yoko)
        let scWidth = Float(calculateParameta.screenWidth)
        let scHeight = Float(calculateParameta.screenHeight)
        
        var face_count = new_face_array[num].count - 1 //新しく構成する頂点のインデックス番号（-1から）
        
        //アンカー情報
        let verticles = anchor.geometry.vertices
        let normals = anchor.geometry.normals
        let faces = anchor.geometry.faces
        sumPolygon += faces.count
        
        //全パラメータで処理
        for (i, matrix) in matrixs.enumerated() {
            for j in 0..<faces.count {
                if i == 0 {
                    face_bool[num].append(-1) //１番目のパラメータ処理時にポリゴン数だけ-1を格納（-1ならそのポリゴンはまだ処理してない）
                }
                if face_bool[num][j] == -1 {
                    //各ポリゴン毎に処理
                    var points: [SCNVector3] = [] //UV計算された頂点のスクリーン座標を格納
                    var perVerticles: [SCNVector3] = []
                    var perNormals: [SCNVector3] = []
                    
                    for offset in 0..<faces.indexCountPerPrimitive {
                        let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                        let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                        
                        let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * Int(per_face_index)))
                        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
                        let world_vertex4 = simd_mul(anchor.transform, vertex4)
                        let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
                        let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(per_face_index)))
                        let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
                        
                        //ポリゴンの頂点座標（3次元）をスクリーン座標（2次元）に変換
                        let clipSpacePosition = matrix * world_vertex4
                        let normalizedDeviceCoordinate = clipSpacePosition / clipSpacePosition.w
                        let pt = SCNVector3((CGFloat(normalizedDeviceCoordinate.x) + 1) * CGFloat(834 / 2),
                                            (-CGFloat(normalizedDeviceCoordinate.y) + 1) * CGFloat(1150 / 2),
                                            1 - (-CGFloat(normalizedDeviceCoordinate.z) + 1))
                        
                        if pt.x >= 0 && pt.x <= 834 && pt.y >= 0 && pt.y <= 1150 && pt.z < 1.0 {
                            
                            let hitResults = sceneView.hitTest(CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)), options: [:])
                            if !hitResults.isEmpty {
                                if hitResults[0].node.parent?.name == "meshNode" {
                                    let hitPoints = hitResults[0].worldCoordinates
                                    //print("\(hitPoints)")
                                    if abs(world_vector3.x - hitPoints.x) < 0.1 && abs(world_vector3.y - hitPoints.y) < 0.1 && abs(world_vector3.z - hitPoints.z) < 0.1 {
                                        points.append(pt)
                                        perVerticles.append(world_vector3)
                                        perNormals.append(normal)
                                    }
                                }
                            }
                        }
                    }
                    
                    if points.count == 3 {
                        texCount += 1
                        //face_bool[num][j] = i
                        
                        for (k, pt) in points.enumerated() {
                            face_count += 1
                            let u = pt.x / (834 * yoko)  + Float((num % Int(yoko))) / yoko
                            let v = pt.y / (1150 * tate) + Float(floor(Float(num) / yoko)) / tate
                            
                            new_texcoords2[num].append(SIMD2<Float>(u, v))
                            new_face_array[num].append(Int32(face_count)) //新しく順番に面を構成するインデックスを格納
                            new_vertex_array[num].append(SIMD3<Float>(perVerticles[k]))
                            new_normal_array[num].append(SIMD3<Float>(perNormals[k]))
                        }
                    }
                }
            }
        }
    }
    
    //MARK: - データベースに保存
    func save_model() {
        
        for (i, _) in anchors.enumerated() {
            let texcoords_data = try! JSONEncoder().encode(new_texcoords2[i])
            let vertices_data = Data(bytes: new_vertex_array[i], count: MemoryLayout<SIMD3<Float>>.size * new_vertex_array[i].count)
            let normals_data = Data(bytes: new_normal_array[i], count: MemoryLayout<SIMD3<Float>>.size * new_normal_array[i].count)
            let faces_data = try! JSONEncoder().encode(new_face_array[i])
            
            let realm = try! Realm()
            try! realm.write {
                models.mesh_anchor[i].texcoords = texcoords_data
                models.mesh_anchor[i].vertices = vertices_data
                models.mesh_anchor[i].normals = normals_data
                models.mesh_anchor[i].faces = faces_data
                models.mesh_anchor[i].vertice_count = new_vertex_array[i].count
            }
            
            let texcoordsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/texcoords\(i).data")
            let vertexPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/vertex\(i).data")
            let normalsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/normals\(i).data")
            let facesPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/faces\(i).data")
            do {
                try texcoords_data.write(to: texcoordsPath)
                try vertices_data.write(to: vertexPath)
                try normals_data.write(to: normalsPath)
                try faces_data.write(to: facesPath)
                print("CPU計算データ\(i)保存成功")
            } catch {
                print("CPU計算データ\(i)保存失敗", error)
            }
            
        }
        
        let realm = try! Realm()
        try! realm.write {
            models.texture_bool = 2
        }
        print("save完了")
    }
}
