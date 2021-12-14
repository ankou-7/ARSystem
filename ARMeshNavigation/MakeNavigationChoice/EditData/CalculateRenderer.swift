//
//  CalculateRenderer.swift
//  ARMesh
//
//  Created by 安江洸希 on 2021/12/06.
//

import Metal
import MetalKit
import ARKit
import SwiftUI
import RealmSwift

class CalculateRenderer {
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLComputePipelineState!
    private var viewportSize = CGSize()
    
    private let section_num: Int
    private let cell_num: Int
    private let current_model_num: Int
    
    //private let inFlightSemaphore: DispatchSemaphore
    
    private let anchors: [ARMeshAnchor]
//    private let vertices: MTLBuffer
//    private let normals: MTLBuffer
//    private let faces: MTLBuffer
//    private let face_count: Int
    
    private let tate: Int
    private let yoko: Int
    
    var face_count: Int!
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    let decoder = JSONDecoder()
    
    private let calcuUniforms: [float4x4]
    private let depth: [depthPosition]
    
    init(section_num: Int, cell_num: Int, model_num: Int, anchor: [ARMeshAnchor], metalDevice device: MTLDevice, calcuUniforms: [float4x4], depth: [depthPosition], tate: Int, yoko: Int) {
        
        self.section_num = section_num
        self.cell_num = cell_num
        self.current_model_num = model_num
        
        self.device = device
        
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        let function = library.makeFunction(name: "calcu5")!
        pipeline = try! device.makeComputePipelineState(function: function)
        
        self.anchors = anchor
//        self.vertices = anchor.geometry.vertices.buffer
//        self.normals = anchor.geometry.normals.buffer
//        self.faces = anchor.geometry.faces.buffer
//        self.face_count = anchor.geometry.faces.count
        
        //MeshUniformsBuffer = .init(device: device, count: face_count * 3, index: 7)
        anchorUniformsBuffer = .init(device: device, count: 1, index: 9)
        
        self.calcuUniforms = calcuUniforms
        self.depth = depth
        self.tate = tate
        self.yoko = yoko
        
        //print(calcuUniforms)
        //calcuUniformsBuffer = .init(device: device, count: calcuUniforms.count, index: 8)
        
        //inFlightSemaphore = DispatchSemaphore(value: 3)
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    var texcoords2: [SIMD2<Float>] = []
    var vertex_array: [SIMD3<Float>] = []
    var normal_array: [SIMD3<Float>] = []
    var face_array: [Int32] = []
    
    var new_face_array: [Int32] = []
    var new_vertex_array: [SIMD3<Float>] = []
    var new_normal_array: [SIMD3<Float>] = []
    var new_texcoords2: [SIMD2<Float>] = []
    
    //private var MeshUniformsBuffer: MetalBuffer<MeshUniforms>
    private var anchorUniformsBuffer: MetalBuffer<anchorUniforms>
    //private var calcuUniformsBuffer: MetalBuffer<CalcuUniforms>
    
    func calcu5(num: Int) -> Int {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
        face_count = anchors[num].geometry.faces.count
        print("頂点数:\(anchors[num].geometry.faces.count * 3)")
        print("id数：\(anchors[num].geometry.faces.count)")
        
        //main処理
        encoder.setBuffer(anchors[num].geometry.vertices.buffer, offset: 0, index: 0)
        encoder.setBuffer(anchors[num].geometry.normals.buffer, offset: 0, index: 1)
        encoder.setBuffer(anchors[num].geometry.faces.buffer, offset: 0, index: 2)
        
        //出力
        let texcoordsBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, options: [])
        let new_verticesBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, options: [])
        let new_normalsBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, options: [])
        let new_facesBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride * face_count! * 3, options: [])
        
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 3)
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 4)
        encoder.setBuffer(new_normalsBuffer, offset: 0, index: 5)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 6)
        
        //一時格納用
        let facecoordBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, options: [])
        encoder.setBuffer(facecoordBuffer, offset: 0, index: 7)
        
        //スクリーン座標変換用の行列が入ってる
        let calcuUniformsBuffer = device.makeBuffer(bytes: calcuUniforms, length: MemoryLayout<float4x4>.stride * calcuUniforms.count, options: [])
        encoder.setBuffer(calcuUniformsBuffer, offset: 0, index: 8)
        
        //計算に必要なその他
        anchorUniformsBuffer[0].transform = anchors[num].transform
        anchorUniformsBuffer[0].calcuCount = Int32(calcuUniforms.count)
        print("calcuCount(スクリーン座標変換用の行列数):\(Int32(calcuUniforms.count))")
        anchorUniformsBuffer[0].tate = Int32(tate)
        anchorUniformsBuffer[0].yoko = Int32(yoko)
        anchorUniformsBuffer[0].maxCount = Int32(anchors[num].geometry.faces.count)
        anchorUniformsBuffer[0].arrayCount = Int32(anchors[num].geometry.faces.count * 3)
        anchorUniformsBuffer[0].depthCount = Int32(128*96)
        encoder.setBuffer(anchorUniformsBuffer)
        
        //深度情報
        let depthBuffer = device.makeBuffer(bytes: depth, length: MemoryLayout<depthPosition>.stride * 128*96 * calcuUniforms.count, options: [])
        encoder.setBuffer(depthBuffer, offset: 0, index: 10)
        
        let tryBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * 128*96, options: [])
        encoder.setBuffer(tryBuffer, offset: 0, index: 11)
        
        let width = 1//32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (anchors[num].geometry.faces.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        var vertexs = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        vertexs = vertexData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        let normalsData = Data(bytesNoCopy: new_normalsBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        normals = normalsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: normalsData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count! * 3, deallocator: .none)
        var faces = [Int32](repeating: Int32(0), count: face_count! * 3)
        faces = facesData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
        }
        
        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, deallocator: .none)
        var texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count! * 3)
        texcoords = texcoordsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
        }
        
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
//        var trys = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
//        trys = tryData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: tryData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
        
        print("----------------------------------------------------------------------------------------------------")
        save_model(num: num, vertexs: vertexs, normals: normals, faces: faces, texcoords: texcoords, count: face_count * 3)
    
        return 1
    }
    
    //func build2(vertexData: Data, normalsData: Data, faces: [Int32], texcoords: [SIMD2<Float>], count: Int) -> SCNNode {
    func build2(image: UIImage) -> SCNNode {
        let tex_node = SCNNode()
        tex_node.name = "tex_node"
        for i in 0..<anchors.count {
            let vertexData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertices!
            let normalData = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].normals!
            let count = results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].vertice_count
            
            let faces = (try? decoder.decode([Int32].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].faces))!
            let texcoords = (try? decoder.decode([SIMD2<Float>].self, from: results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[i].texcoords))!
            
            let verticeSource = SCNGeometrySource(
                data: vertexData,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)
            
            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = image //UIImage(data: results[section_num].cells[cell_num].models[current_model_num].texture_pic)
            
//            let defaultMaterial = SCNMaterial()
//            defaultMaterial.fillMode = .lines
//            defaultMaterial.diffuse.contents = UIColor.blue
//            nodeGeometry.materials = [defaultMaterial]
            
            let node = SCNNode(geometry: nodeGeometry)
            node.name = "child_tex_node"
            tex_node.addChildNode(node)
        }
        return tex_node
    }
    
    func save_model(num: Int, vertexs: [SIMD3<Float>], normals: [SIMD3<Float>], faces: [Int32], texcoords: [SIMD2<Float>], count: Int) {
        
        let texcoordsData = try! JSONEncoder().encode(texcoords)
        let facesData = try! JSONEncoder().encode(faces)
        let vertexData = Data(bytes: vertexs, count: MemoryLayout<SIMD3<Float>>.size * vertexs.count)
        let normalsData = Data(bytes: normals, count: MemoryLayout<SIMD3<Float>>.size * normals.count)
        
        let realm = try! Realm()
        try! realm.write {
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[num].texcoords = texcoordsData
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[num].vertices = vertexData
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[num].normals = normalsData
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[num].faces = facesData
            results[section_num].cells[cell_num].models[current_model_num].mesh_anchor[num].vertice_count =  count
            results[section_num].cells[cell_num].models[current_model_num].texture_bool = 3
        }
        print("save完了")
    }
    
    //MARK: - その他
    
    var hikaku: [SIMD4<Float>] = []
    
    func makeArray(num: Int) {
        vertex_array = []
        normal_array = []
        face_array = []
        new_face_array = []
        new_vertex_array = []
        new_normal_array = []
        texcoords2 = []
        
        let verticles = anchors[num].geometry.vertices
        let normals = anchors[num].geometry.normals
        for j in 0..<verticles.count {
            
            let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
            let world_vertex4 = simd_mul(anchors[num].transform, vertex4)
            let world_vector3 = SIMD3<Float>(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
            //vertex_array.append(world_vector3)
            vertex_array.append(vertex)
            
            let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * j))
            let normal = normalsPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            normal_array.append(normal)
        }
        
        let faces = anchors[num].geometry.faces
        for j in 0..<faces.count {
            let indicesPerFace = faces.indexCountPerPrimitive
            for offset in 0..<indicesPerFace {
                let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                face_array.append(per_face)
                
                new_face_array.append(Int32(face_array.count-1))
                new_vertex_array.append(SIMD3<Float>(x: 0, y: 0, z: 0))
                new_normal_array.append(SIMD3<Float>(x: 0, y: 0, z: 0))
                texcoords2.append(SIMD2<Float>(0, 0))
            }
        }
        
        //print(vertex_array.count)
        //print(new_vertex_array.count)
        //print(faces.count)
        //print(face_array.count)
        //print(new_face_array.count)
    }
    
    func calcu4(num: Int) -> Int {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
//        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
//        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
//            if let self = self {
//                self.inFlightSemaphore.signal()
//            }
//        }
        
        makeArray(num: num)
        face_count = anchors[num].geometry.faces.count
        print("face_count:\(face_count!)")
        
        //main処理
        //入力
//        let vertexBuffer = MetalBuffer<SIMD3<Float>>(device: device, array: vertex_array, index: 0, options: [])
//        encoder.setBuffer(vertexBuffer)
        let vertexBuffer = device.makeBuffer(bytes: vertex_array, length: MemoryLayout<SIMD3<Float>>.stride * vertex_array.count, options: [])
        let normalBuffer = device.makeBuffer(bytes: normal_array, length: MemoryLayout<SIMD3<Float>>.stride * normal_array.count, options: .storageModeShared)
        let faceBuffer = device.makeBuffer(bytes: face_array, length: MemoryLayout<Int32>.stride * face_count! * 3, options: .storageModeShared)
        
        encoder.setBuffer(vertexBuffer, offset: 0, index: 0)
        //encoder.setBuffer(anchors[num].geometry.vertices.buffer, offset: 0, index: 0)
        encoder.setBuffer(normalBuffer, offset: 0, index: 1)
        encoder.setBuffer(faceBuffer, offset: 0, index: 2)
        
        //出力
        let texcoordsBuffer = device.makeBuffer(bytes: texcoords2, length: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, options: [])
        let new_verticesBuffer = device.makeBuffer(bytes: new_vertex_array, length: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, options: [])
        let new_normalsBuffer = device.makeBuffer(bytes: new_normal_array, length: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, options: [])
        let new_facesBuffer = device.makeBuffer(bytes: new_face_array, length: MemoryLayout<Int32>.stride * face_count! * 3, options: [])
        
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 3)
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 4)
        encoder.setBuffer(new_normalsBuffer, offset: 0, index: 5)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 6)
        
        //encoder.setBuffer(MeshUniformsBuffer)
        
        let calcuUniformsBuffer = device.makeBuffer(bytes: calcuUniforms, length: MemoryLayout<float4x4>.stride * calcuUniforms.count, options: [])
        encoder.setBuffer(calcuUniformsBuffer, offset: 0, index: 8)
        //encoder.setBuffer(calcuUniformsBuffer)
        
        anchorUniformsBuffer[0].transform = anchors[num].transform
        anchorUniformsBuffer[0].calcuCount = Int32(calcuUniforms.count)
        print("calcuCount:\(Int32(calcuUniforms.count))")
        anchorUniformsBuffer[0].tate = Int32(tate)
        anchorUniformsBuffer[0].yoko = Int32(yoko)
        anchorUniformsBuffer[0].maxCount = Int32(face_count! * 3)
        print("総count:\(face_count! * 3)")
        encoder.setBuffer(anchorUniformsBuffer)
        
        let tryBuffer = device.makeBuffer(bytes: new_vertex_array, length: MemoryLayout<Int32>.stride * face_count! * 3, options: [])
        encoder.setBuffer(tryBuffer, offset: 0, index: 10)
        
        let faceBool_array = [Int](repeating: 0, count: face_count)
        let faceBoolBuffer = device.makeBuffer(bytes: faceBool_array, length: MemoryLayout<Int>.stride * face_count!, options: .storageModeShared)
        encoder.setBuffer(faceBoolBuffer, offset: 0, index: 11)
        
        let facecoordBuffer = device.makeBuffer(bytes: texcoords2, length: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, options: [])
        encoder.setBuffer(facecoordBuffer, offset: 0, index: 12)
        
        //確認用
        let Vbuffer = anchors[num].geometry.vertices.buffer
        let Fbuffer = anchors[num].geometry.faces.buffer
        encoder.setBuffer(Fbuffer, offset: 0, index: 13)
        
        let width = 1//32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        //calcu3
        //let numThreadgroups = MTLSize(width: (face_count! * 3 + width - 1) / width, height: 1, depth: 1)
        //calcu4
        let numThreadgroups = MTLSize(width: (face_count! + width - 1) / width, height: 1, depth: 1)
        
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        var vertexs = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        vertexs = vertexData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        let normalsData = Data(bytesNoCopy: new_normalsBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        normals = normalsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: normalsData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count! * 3, deallocator: .none)
        var faces = [Int32](repeating: Int32(0), count: face_count! * 3)
        faces = facesData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
        }
        
        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, deallocator: .none)
        var texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count! * 3)
        texcoords = texcoordsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
        }
        
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
//        var trys = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
//        trys = tryData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: tryData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count! * 3, deallocator: .none)
        var trys = [Int32](repeating: Int32(0), count: face_count! * 3)
        trys = tryData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int32>(start: $0, count: tryData.count/MemoryLayout<Int32>.size))
        }
        
        //結果の表示
        //print("[Input data]: \(texcoords2)")
        //print("[Result data]: \(texcoords)")
        //print(anchorUniformsBuffer[0])
        //print(calcuUniforms)
        
        
        print(new_vertex_array[0...10])
        print(vertexs[0...10])
        print("face_array.count:\(face_array.count)")
        print(trys)
        print("------------------------------------------------------------------------------------------------------------------------------------------")
        //print(texcoords)
        
        //let node = build(texcoords: resultData)
        //let node = build2(vertexData: vertexData, normalsData: normalsData, faces: faces, texcoords: texcoords, count: face_count * 3)
        save_model(num: num, vertexs: vertexs, normals: normals, faces: faces, texcoords: texcoords, count: face_count * 3)
    
        return 1
    }
    
    func calcu() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(pipeline)
        
        var inputData:[Float] = []
        for _ in 0...100-1 {
            inputData.append(Float(arc4random_uniform(UInt32(100))))
        }
        let inputBuffer = device.makeBuffer(bytes: inputData, length: MemoryLayout<Float>.stride * inputData.count, options:.storageModeShared)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        let outputData = [Float](repeating: 0, count: inputData.count)
        //let outputData = [[Float]](repeating: [Float](repeating: 0, count: inputData[0].count), count:2)
        let outputDataBuffer = device.makeBuffer(bytes: outputData, length: MemoryLayout<Float>.stride * outputData.count, options:.storageModeShared)
        encoder.setBuffer(outputDataBuffer, offset: 0, index: 1)
        
        let width = 32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (inputData.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        //エンコーダーからのコマンドは終了
        encoder.endEncoding()
        
        //コマンドバッファを実行し、完了するまで待機
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        //print(pipeline.maxTotalThreadsPerThreadgroup) //1024
        //print(pipeline.threadExecutionWidth) //32
        
        //結果をresultDataに格納
        let data = Data(bytesNoCopy: outputDataBuffer!.contents(), count: MemoryLayout<Float>.stride * outputData.count, deallocator: .none)
        var resultData = [Float](repeating: 1, count: outputData.count * 2)
        resultData = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Float>(start: $0, count: data.count/MemoryLayout<Float>.size))
        }
        
        //結果の表示
        print("[Input data]: \(inputData)")
        print("[Result data]: \(resultData)")
    }

}

extension SCNGeometrySource {
    convenience init(textureCoordinates2 texcoord: [SIMD2<Float>]) {
        let stride = MemoryLayout<SIMD2<Float>>.stride
        let bytePerComponent = MemoryLayout<Float>.stride
        let data = Data(bytes: texcoord, count: stride * texcoord.count)
        self.init(data: data, semantic: SCNGeometrySource.Semantic.texcoord, vectorCount: texcoord.count, usesFloatComponents: true, componentsPerVector: 2, bytesPerComponent: bytePerComponent, dataOffset: 0, dataStride: stride)
    }
}
