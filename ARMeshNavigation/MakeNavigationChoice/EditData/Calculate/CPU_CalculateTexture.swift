//
//  CPU_CalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit

extension EditDataController {
    
    func make_texture1000(num: Int) {
        let count = results[section_num].cells[cell_num].models[current_model_num].pic.count
        let yoko: Float = 17.0//4.0
        let tate: Float = ceil(Float(count)/yoko)
        
//        //RGB画像
//        let uiImage = new_uiimage
//        let imageData = uiImage!.jpegData(compressionQuality: 0.5)
//
//        //内部パラメータ保存用
//        let realm = try! Realm()
//        try! realm.write {
//            results[section_num].cells[cell_num].models[current_model_num].texture_pic = imageData
//        }
        
        let start = Date()
        for i in 0..<count {
            let depth_array = try? decoder.decode([depthPosition].self, from: results[section_num].cells[cell_num].models[current_model_num].depth[i].depth_data!)
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
        texmeshNode = BuildTextureMeshNode(result: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor, texImage: new_uiimage)
        sceneView.scene?.rootNode.addChildNode(texmeshNode)
    }
    
    func calcTextureCoordinates2000(num: Int, yoko: Float, tate: Float, cameraVector: SCNVector3, depthArray: [depthPosition], matrix: simd_float4x4){
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
