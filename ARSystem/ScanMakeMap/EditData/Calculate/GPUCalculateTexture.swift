//
//  GPUCalculateTexture.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import RealmSwift
import ARKit
import Foundation

class GPUCalculateTexture {
    
    private var sceneView: SCNView
    private var anchors: [ARMeshAnchor]
    var models_dayString: String
    var models_parametaNum: Int
    var modelID: Int
    private var calculateParameta: calculateParameta
    
    private var calcuMatrix = [float4x4]()
    private var depth = [depthPosition]()
    private var calculateRenderer: CalculateRenderer!
    
    private var url: URL!
    
    var removeCount: [Int]
    
    var st = ""
    var posi = ""
    
    // 使用者が単位を把握できるようにするため
    typealias MegaByte = UInt64
    
    init(sceneView: SCNView, anchors: [ARMeshAnchor], models_dayString: String, models_parametaNum: Int, modelID: Int, calculateParameta: calculateParameta, removeCount: [Int]) {
        self.sceneView = sceneView
        self.anchors = anchors
        self.models_dayString = models_dayString
        self.models_parametaNum = models_parametaNum
        self.modelID = modelID
        self.calculateParameta = calculateParameta
        
        self.removeCount = removeCount
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        make_calcuParameta()
    }
    
    func makeGPUTexture(completionHandler: @escaping () -> ()) {
        var flag = 0
        let start = Date()
        var poly = ""
        var time = ""
        print("calcu開始")
        
//        self.calculateRenderer = CalculateRenderer(models: models, anchor: anchors, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer = CalculateRenderer(models_dayString: models_dayString, modelID: modelID, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        var i = 0
        _ = anchors.map { anchor in
            print("-----------------------------------------")
            print("\(flag)回目")
            flag += self.calculateRenderer.calcu5(num: i, anchor: anchors[i])
            poly += "\(calculateRenderer.sumPolygon)\n"
            time += "\(Date().timeIntervalSince(start))\n"
            i+=1
        }
        
//        for i in 0..<anchors.count {
//            print("-----------------------------------------")
//            print("\(flag)回目")
//            flag += self.calculateRenderer.calcu5(num: i, anchor: anchors[i])
//            poly += "\(calculateRenderer.sumPolygon)\n"
//            time += "\(Date().timeIntervalSince(start))\n"
//            //print("メモリ使用量：\(String(describing: getMemoryUsed()))")
//        }
        print("-----------------------------------------")
        print("calcu終了")
        print("処理時間：\(Date().timeIntervalSince(start))")
        print("総ポリゴン数：\(calculateRenderer.sumPolygon)")
        print("割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)")
        print("テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))")
        print("割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)")
        st += """
                    総ポリゴン数：\(calculateRenderer.sumPolygon)
                    割り当てられたポリゴン数：\(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3)
                    テクスチャ割り当て割合：\(Double(calculateRenderer.sumPolygon - calculateRenderer.texCount / 3) / Double(calculateRenderer.sumPolygon))
                    割り当てられなかったポリゴン数：\(calculateRenderer.texCount / 3)\n
                """
        st += poly + time
        saveDocument(text: st)
        
        completionHandler()
    }
    
    func noLog_makeGPUTexture(completionHandler: @escaping (Int, Data, Data, Data, Data, [Int32], [SIMD2<Float>]) -> ()) {
        var flag = 0
        
        var texcoordsData = Data()
        var vertexData = Data()
        var normalsData = Data()
        var facesData = Data()
        var faces = [Int32]()
        var texcoords = [SIMD2<Float>]()
        
        let per_start = Date()
        delete_allData()
        makeDirectory()
        self.calculateRenderer = CalculateRenderer(models_dayString: models_dayString, modelID: modelID, calcuUniforms: calcuMatrix, depth: depth, calculateParameta: calculateParameta)
        self.calculateRenderer.drawRectResized(size: self.sceneView.bounds.size)
        
        let (facesCount, AllFacesBuffer, AllVerticesBuffer, AllNormalsBuffer, sepaFacesBuffer, sepaVerticesBuffer) = makeAllBuffer()
        let (picNumArrayBuffer, sepapicNumArrayBuffer, anchorTransformBuffer) = make_allpicNumArray()
        
        print("準備処理時間：\(Date().timeIntervalSince(per_start))")
        
        let start = Date()
        
        if calculateParameta.funcString == "all_textureCalculate" {
            //(texcoordsData, vertexData, normalsData, facesData, faces, texcoords) =
            calculateRenderer.use_AllBuffer_Calcu(facesCount: facesCount,
                                                  facesBuffer: AllFacesBuffer,
                                                  verticesBuffer: AllVerticesBuffer,
                                                  normalsBuffer: AllNormalsBuffer,
                                                  sepaFacesBuffer: sepaFacesBuffer,
                                                  sepaVerticesBuffer: sepaVerticesBuffer,
                                                  anchorTransformBUffer: anchorTransformBuffer,
                                                  picNumArrayBuffer: picNumArrayBuffer,
                                                  sepaPicNumArrayBuffer: sepapicNumArrayBuffer)
        } else {
            for i in 0..<anchors.count {
                print("-----------------------------------------")
                let per_start = Date()
                flag += self.calculateRenderer.calcu5(num: i, anchor: anchors[i])
                print("各処理時間：\(Date().timeIntervalSince(per_start))")
            }
        }
        
        print("処理時間：\(Date().timeIntervalSince(start))")
        
        completionHandler(flag, texcoordsData, vertexData, normalsData, facesData, faces, texcoords)
    }
    
    func makeAllBuffer() -> (Int, MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer){
        var allFaces = [Int32]()
        
        var allVerticeCount = 0
        for anchor in anchors {
            allVerticeCount += anchor.geometry.vertices.count
        }
        var allVertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: allVerticeCount) //[SIMD3<Float>]()
        var allNormals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: allVerticeCount)
        
        var separateFaces = [Int32]()
        var separateVertices = [Int32]()
        
        for (i, anchor) in anchors.enumerated() {
            let faceCount = anchor.geometry.faces.count
            let facesBuffer = anchor.geometry.faces.buffer
            let verticesBuffer = anchor.geometry.vertices.buffer
            let normalsBuffer = anchor.geometry.normals.buffer
            
//            print("faceCount:\(faceCount)")
//            print("faceCount*3:\(faceCount*3)")
//            print("verticesCount:\(anchor.geometry.vertices.count)")
//            print("normalsCount:\(anchor.geometry.normals.count)")
            
            if i == 0 {
                separateVertices.append(Int32(anchor.geometry.vertices.count))
            } else {
                separateVertices.append(separateVertices[i-1] + Int32(anchor.geometry.vertices.count))
            }
            
            separateFaces.append(contentsOf: [Int32](repeating: Int32(i), count: faceCount))
            
            //if i == 0 {
                for j in 0..<anchor.geometry.faces.count {
                    for offset in 0..<anchor.geometry.faces.indexCountPerPrimitive {
                        let vertexIndexAddress = anchor.geometry.faces.buffer.contents().advanced(by: (j * anchor.geometry.faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
                        let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                        
                        let vertexPointer = anchor.geometry.vertices.buffer.contents().advanced(by: anchor.geometry.vertices.offset + (anchor.geometry.vertices.stride * Int(per_face_index)))
                        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        
                        let normalsPointer = anchor.geometry.normals.buffer.contents().advanced(by: anchor.geometry.normals.offset + (anchor.geometry.normals.stride * Int(per_face_index)))
                        let normal = normalsPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                        
                        allFaces.append(per_face_index)
                        if i != 0 {
                            allVertices[Int(per_face_index + separateVertices[i-1])] = vertex
                            allNormals[Int(per_face_index + separateVertices[i-1])] = normal
                        } else {
                            allVertices[Int(per_face_index)] = vertex
                            allNormals[Int(per_face_index)] = normal
                        }
                    }
                }
                
//                print("faceCount:\(faceCount)")
//                print("faceCount*3:\(faceCount*3)")
//                print("verticesCount:\(anchor.geometry.vertices.count)")
//
//                print(anchor.geometry.vertices.buffer)
//                print(allFaces[0...10])
//                let facesData = Data(bytesNoCopy: facesBuffer.contents(), count: MemoryLayout<Int32>.stride * faceCount * 3, deallocator: .none)
//                var faces = [Int32](repeating: Int32(0), count: faceCount * 3)
//                faces = facesData.withUnsafeBytes {
//                    Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
//                }
//                print(faces[0...10])
//                print(faces.count)
//
//
//                print("取り出し")
//                print(allVertices[0...10])
//                print(allVertices.count)
//
//                print("コピー")
//                let verticesData = Data(bytesNoCopy: verticesBuffer.contents(), count: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.vertices.count, deallocator: .none)
//                print(verticesData.count/MemoryLayout<SIMD3<Float>>.size)
//                var vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: anchor.geometry.vertices.count)
//                vertices = verticesData.withUnsafeBytes {
//                    Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: verticesData.count/MemoryLayout<SIMD3<Float>>.size))
//                }
//                print(vertices[0...10])
//                print(vertices.count)
//                for posi in vertices[0...10] {
//                    makeNode(posi: posi)
//                }
                
//                let normalsData = Data(bytesNoCopy: normalsBuffer.contents(), count: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.normals.count, deallocator: .none)
//                let normals = normalsData.withUnsafeBytes {
//                    Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: normalsData.count/MemoryLayout<SIMD3<Float>>.size))
//                }
                
                
//                allFaces.append(contentsOf: faces)
//                allVertices.append(contentsOf: vertices)
//                allNormals.append(contentsOf: normals)
            
            //}
            
            
            
//            separateFaces.append(Int32(faces.count))
//            separateVertices.append(Int32(vertices.count))
            //separateVertices.append(contentsOf: [Int32](repeating: Int32(i), count: anchor.geometry.vertices.count))
            
        }
        
        //print(allVertices[0...10])
        //print(allVertices[allVertices.count-10...allVertices.count-1])
//        for posi in allVertices[0...20] {
//            let transform = anchors[0].transform
//            let worldPosi = simd_mul(transform, vector_float4(posi.x, posi.y, posi.z, 1.0))
//            print(worldPosi)
//            makeNode(posi: SIMD3<Float>(worldPosi.x, worldPosi.y, worldPosi.z))
//        }
        //print(allFaces[0...10])
        //print(anchors[0].transform)
        for k in allFaces[0...10] {
            let posi = allVertices[Int(k)]
            //print(posi)
            let transform = anchors[0].transform
            let worldPosi = simd_mul(transform, vector_float4(posi.x, posi.y, posi.z, 1.0))
            //print(worldPosi)
            makeNode(posi: SIMD3<Float>(worldPosi.x, worldPosi.y, worldPosi.z))
        }
//        for posi in allVertices[allVertices.count-20...allVertices.count-1] {
//            let transform = anchors.last!.transform
//            let worldPosi = simd_mul(transform, vector_float4(posi.x, posi.y, posi.z, 1.0))
//            makeNode(posi: SIMD3<Float>(worldPosi.x, worldPosi.y, worldPosi.z))
//        }
//        for k in allFaces[allFaces.count-10...allFaces.count-1] {
//            let posi = allVertices[Int(k + separateVertices[separateVertices.count-2])]
//            let transform = anchors.last!.transform
//            let worldPosi = simd_mul(transform, vector_float4(posi.x, posi.y, posi.z, 1.0))
//            print(worldPosi)
//            makeNode(posi: SIMD3<Float>(worldPosi.x, worldPosi.y, worldPosi.z))
//        }
        
        print("総ポリゴン数：\(allFaces.count/3)")
        print("総ポリゴン数*3：\(allFaces.count)")
        print("総頂点数：\(allVertices.count)")
        print(separateFaces.count)
        print(separateVertices)
        
        let facesCount = allFaces.count
        let AllFacesBuffer = sceneView.device!.makeBuffer(bytes: allFaces, length: MemoryLayout<Int32>.stride * allFaces.count, options: [])
        let AllVerticesBuffer = sceneView.device!.makeBuffer(bytes: allVertices, length: MemoryLayout<SIMD3<Float>>.stride * allVertices.count, options: [])
        let AllNormalsBuffer = sceneView.device!.makeBuffer(bytes: allNormals, length: MemoryLayout<SIMD3<Float>>.stride * allNormals.count, options: [])
        let sepaFacesBuffer = sceneView.device!.makeBuffer(bytes: separateFaces, length: MemoryLayout<Int32>.stride * separateFaces.count, options: [])
        let sepaVerticesBuffer = sceneView.device!.makeBuffer(bytes: separateVertices, length: MemoryLayout<Int32>.stride * separateVertices.count, options: [])
        
//        print(AllFacesBuffer)
//        print(AllVerticesBuffer)
//        print(AllNormalsBuffer)
//        print(separateFaces)
//        print(separateVertices)
        
        return (facesCount, AllFacesBuffer!, AllVerticesBuffer!, AllNormalsBuffer!, sepaFacesBuffer!, sepaVerticesBuffer!)
    }
    
    func makeNode(posi: SIMD3<Float>) {
        let node = SCNNode(geometry: SCNSphere(radius: 0.01))
        node.position = SCNVector3(x: posi.x, y: posi.y, z: posi.z)
        sceneView.scene?.rootNode.addChildNode(node)
    }
    
    func saveDocument(text: String) {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let archivePath = url.appendingPathComponent("\(models_dayString)/\(modelID)/バージョン3.txt")
            do {
                try text.write(to: archivePath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
            
            let posiPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/posi.txt")
            do {
                try posi.write(to: posiPath, atomically: false, encoding: .utf8)
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func make_allpicNumArray() -> (MTLBuffer, MTLBuffer, MTLBuffer) {
        var picNumArray = [Int32]()
        var sepaPicNumArray = [Int32]()
        var anchorTransform =  [float4x4]()
        
        for i in 0..<anchors.count {
            let picNum = read_anchor_picNum(i: i)
            picNumArray.append(contentsOf: picNum)
            //print("\(i):\(picNumArray)")
            if i == 0 {
                sepaPicNumArray.append(Int32(picNum.count))
            } else {
                sepaPicNumArray.append(sepaPicNumArray[i-1] + Int32(picNum.count))
            }
            //print("\(i):\(sepaPicNumArray)")
            anchorTransform.append(anchors[i].transform)
        }
        
        //print(anchorTransform)
        
        let picNumArrayBuffer = sceneView.device!.makeBuffer(bytes: picNumArray, length: MemoryLayout<Int32>.stride * picNumArray.count, options: [])
        let sepapicNumArrayBuffer = sceneView.device!.makeBuffer(bytes: sepaPicNumArray, length: MemoryLayout<Int32>.stride * sepaPicNumArray.count, options: [])
        let anchorTransformBuffer = sceneView.device!.makeBuffer(bytes: anchorTransform, length: MemoryLayout<float4x4>.stride * anchorTransform.count, options: [])
        
        return (picNumArrayBuffer!, sepapicNumArrayBuffer!, anchorTransformBuffer!)
    }
    
    func read_anchor_picNum(i: Int) -> [Int32] {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        let txtPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/mesh/mesh\(i).txt")
        guard let fileContents = try? String(contentsOf: txtPath, encoding: .utf8) else {
            print("file読み込み失敗")
            return []
        }
        
        var lines = fileContents.split(separator: "\n")
        var picNum = lines.map { Int32($0)! - 1 } //String → Intに変換
        //print("紐付けた画像数:\(picNum.count):\(picNum)")
        
        return picNum
    }
    
    func make_calcuParameta() {
        let decoder = JSONDecoder()
        
        for i in 0..<models_parametaNum { //pic.count {
            if removeCount.firstIndex(of: i) == nil {
                let jsonPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/json/json\(i).data")
                //let json_data = try? decoder.decode(MakeMap_parameta.self, from: models.json[i].json_data!)
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
                
                var dis = sqrt((json_data!.cameraPosition.x * json_data!.cameraPosition.x) + (json_data!.cameraPosition.y * json_data!.cameraPosition.y) + (json_data!.cameraPosition.z * json_data!.cameraPosition.z))
                posi += "\(i) : \(dis)\n"
                
                let depthPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/depth/depth\(i).data")
                //let depth_array = (try? decoder.decode([depthPosition].self, from: models.depth[i].depth_data!))!
                let depth_array = try? decoder.decode([depthPosition].self, from: try! Data(contentsOf: depthPath))
                depth.append(contentsOf: depth_array!)
            }
        }
    }
    
    func makeDirectory() {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let texcoords_directory = url.appendingPathComponent("\(models_dayString)/\(modelID)/texcoords", isDirectory: true)
            let vertex_directory = url.appendingPathComponent("\(models_dayString)/\(modelID)/vertex", isDirectory: true)
            let normals_directory = url.appendingPathComponent("\(models_dayString)/\(modelID)/normals", isDirectory: true)
            let faces_directory = url.appendingPathComponent("\(models_dayString)/\(modelID)/faces", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: texcoords_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: vertex_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: normals_directory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: faces_directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
    }
    
    func delete_allData() {
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/texcoords")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/vertex")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/normals")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/faces")
    }
    
    // 引数にenumで任意の単位を指定できるのが好ましい e.g. unit = .auto (デフォルト引数)
    func getMemoryUsed() -> MegaByte? {
        // タスク情報を取得
        var info = mach_task_basic_info()
        // `info`の値からその型に必要なメモリを取得
        var count = UInt32(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            task_info(mach_task_self_,
                      task_flavor_t(MACH_TASK_BASIC_INFO),
                      // `task_info`の引数にするためにInt32のメモリ配置と解釈させる必要がある
                      $0.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                UnsafeMutablePointer<Int32>(pointer)
            }, &count)
        }
        // MB表記に変換して返却
        return result == KERN_SUCCESS ? info.resident_size / 1024 / 1024 : nil
    }
}
