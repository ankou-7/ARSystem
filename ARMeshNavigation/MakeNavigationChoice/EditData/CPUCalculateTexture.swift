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
    
    private var cameraVector: SCNVector3!
    private var calcuMatrix: simd_float4x4!
    private var depth = [depthPosition]()
    
    let decoder = JSONDecoder()
    
    //var anchors: [ARMeshAnchor] = []
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
    
    init(anchors: [ARMeshAnchor], models: Navi_Modelname, picCount: Int, calculateParameta: calculateParameta) {
        self.anchors = anchors
        self.models = models
        self.calculateParameta = calculateParameta
    }
    
    func setupArray() {
        for _ in 0..<models.mesh_anchor.count {
            //let mesh_data = models.mesh_anchor[i].mesh
//            if let meshAnchor = try! NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: mesh_data!) {
//                anchors.append(meshAnchor)
//            }
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
        print("calcu開始")
        for i in 0..<picCount {
            make_calcuParameta(i: i)
            calcTextureCoordinates2000(num: i, cameraVector: cameraVector, depthArray: depth, matrix: calcuMatrix)
        }
        
        print("calcu終了")
        let elapsed = Date().timeIntervalSince(start)
        print("処理時間：\(elapsed)")
        completionHandler()
    }
    
    func make_calcuParameta(i: Int) {
        depth = (try? decoder.decode([depthPosition].self, from: models.depth[i].depth_data!))!
        let json_data = try? decoder.decode(MakeMap_parameta.self, from: models.json[i].json_data!)
        cameraVector = SCNVector3(json_data!.cameraVector.x,
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
        calcuMatrix = projectionMatrix * viewMatrix
    }
    
    func calcTextureCoordinates(num: Int, cameraVector: SCNVector3, depthArray: [depthPosition], matrix: simd_float4x4){
        for (i, mesh_anchor) in anchors.enumerated() {
            var tate = calculateParameta.tate
            var yoko = calculateParameta.yoko
            var points: [SCNVector3] = []
            var points_index: [Int] = []
            var perVerticles: [SCNVector3] = []
            var perNormals: [SCNVector3] = []
            var face_count = new_face_array[i].count - 1
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
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
                        //face_bool[i][j] = i
                        //print("----------------------------")
                        for (k, p) in points.enumerated() {
                            //print(perNormals[k])
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
}
