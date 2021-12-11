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
    
    private let anchor: ARMeshAnchor
    private let vertices: MTLBuffer
    private let normals: MTLBuffer
    private let faces: MTLBuffer
    private let face_count: Int
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    let decoder = JSONDecoder()
    
    var matrix: [float4x4]!
    var calcuUniforms: CalcuUniforms = {
        var unifotms = CalcuUniforms()
        
        return unifotms
    }()
    
    init(anchor: ARMeshAnchor, metalDevice device: MTLDevice) {
        self.device = device
        
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        let function = library.makeFunction(name: "calcu2")!
        pipeline = try! device.makeComputePipelineState(function: function)
        
        self.anchor = anchor
        self.vertices = anchor.geometry.vertices.buffer
        self.normals = anchor.geometry.normals.buffer
        self.faces = anchor.geometry.faces.buffer
        self.face_count = anchor.geometry.faces.count
        
        MeshUniformsBuffer = .init(device: device, count: face_count * 3, index: 7)
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    var texcoords2: [SIMD2<Float>] = []
    var vertex_array: [SCNVector3] = []
    var normal_array: [SCNVector3] = []
    var face_array: [Int32] = []
    
    var new_face_array: [Int32] = []
    var new_vertex_array: [SCNVector3] = []
    var new_normal_array: [SCNVector3] = []
    var new_texcoords2: [SIMD2<Float>] = []
    
    private var MeshUniformsBuffer: MetalBuffer<MeshUniforms>
    
    func makeArray() {
        let verticles = anchor.geometry.vertices
        let normals = anchor.geometry.normals
        for j in 0..<verticles.count {
            
            let vertexPointer = verticles.buffer.contents().advanced(by: verticles.offset + (verticles.stride * j))
            let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let vertex4 = vector_float4(vertex.x, vertex.y, vertex.z, 1)
            let world_vertex4 = simd_mul(anchor.transform, vertex4)
            let world_vector3 = SCNVector3(x: world_vertex4.x, y: world_vertex4.y, z: world_vertex4.z)
            vertex_array.append(world_vector3)
            
            let normalsPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * j))
            let normal = normalsPointer.assumingMemoryBound(to: SCNVector3.self).pointee
            normal_array.append(normal)
        }
        
        let faces = anchor.geometry.faces
        for j in 0..<faces.count {
            let indicesPerFace = faces.indexCountPerPrimitive
            for offset in 0..<indicesPerFace {
                let vertexIndexAddress = faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
                face_array.append(per_face)
                
                new_face_array.append(Int32(face_array.count))
                new_vertex_array.append(SCNVector3(x: 0, y: 0, z: 0))
                new_normal_array.append(SCNVector3(x: 0, y: 0, z: 0))
                texcoords2.append(SIMD2<Float>(0, 0))
            }
        }
        
        print(vertex_array.count)
        print(new_vertex_array.count)
        print(face_array.count)
        print(new_face_array.count)
    }
    
    func calcu4() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
        makeArray()
        
        //main処理
        //入力
        let vertexBuffer = device.makeBuffer(bytes: vertex_array, length: MemoryLayout<SIMD3<Float>>.stride * vertex_array.count, options: .storageModeShared)
        let normalBuffer = device.makeBuffer(bytes: normal_array, length: MemoryLayout<SIMD3<Float>>.stride * normal_array.count, options: .storageModeShared)
        let faceBuffer = device.makeBuffer(bytes: face_array, length: MemoryLayout<UInt32>.stride * face_count * 3, options: .storageModeShared)
        
        encoder.setBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setBuffer(normalBuffer, offset: 0, index: 1)
        encoder.setBuffer(faceBuffer, offset: 0, index: 2)
        
        //出力
        let texcoordsBuffer = device.makeBuffer(bytes: texcoords2, length: MemoryLayout<SIMD2<Float>>.stride * face_count * 3, options: .storageModeShared)
        let new_verticesBuffer = device.makeBuffer(bytes: new_vertex_array, length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: .storageModeShared)
        let new_normalsBuffer = device.makeBuffer(bytes: new_normal_array, length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: .storageModeShared)
        let new_facesBuffer = device.makeBuffer(bytes: new_face_array, length: MemoryLayout<UInt32>.stride * face_count * 3, options: .storageModeShared)
        
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 3)
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 4)
        encoder.setBuffer(new_normalsBuffer, offset: 0, index: 5)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 6)
        
        encoder.setBuffer(MeshUniformsBuffer)
        
        let width = 32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (face_count * 3 + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let data = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<UInt32>.stride * face_count * 3, deallocator: .none)
//        var resultData = [UInt32](repeating: UInt32(0), count: face_count * 3)
//        resultData = data.withUnsafeBytes {
//            Array(UnsafeBufferPointer<UInt32>(start: $0, count: data.count/MemoryLayout<UInt32>.size))
//        }
        
        let data = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, deallocator: .none)
        var resultData = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
        resultData = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: data.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        print("[Input data]: \(face_array)")
        print(vertex_array)
        print("[Result data]: \(resultData)")
        
        print(MeshUniformsBuffer[0])
    }
    
    func calcu3() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
        //main処理
        encoder.setBuffer(vertices, offset: 0, index: 0)
        encoder.setBuffer(normals, offset: 0, index: 1)
        encoder.setBuffer(faces, offset: 0, index: 2)
        
        let texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count * 3)
        let texcoordsBuffer = device.makeBuffer(bytes: texcoords, length: MemoryLayout<SIMD2<Float>>.stride * face_count * 3, options: .storageModeShared)
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 3)
        
        let new_vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
        let new_verticesBuffer = device.makeBuffer(bytes: new_vertices, length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: .storageModeShared)
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 4)
        
        let new_normals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
        let new_normalsBuffer = device.makeBuffer(bytes: new_normals, length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: .storageModeShared)
        encoder.setBuffer(new_normalsBuffer, offset: 0, index: 5)
        
        let new_faces = [UInt32](repeating: UInt32(0), count: face_count * 3)
        let new_facesBuffer = device.makeBuffer(bytes: new_faces, length: MemoryLayout<UInt32>.stride * face_count * 3, options: .storageModeShared)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 6)
        
        let width = 32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (face_count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
//        let data = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<UInt32>.stride * face_count * 3, deallocator: .none)
//        var resultData = [UInt32](repeating: UInt32(0), count: face_count * 3)
//        resultData = data.withUnsafeBytes {
//            Array(UnsafeBufferPointer<UInt32>(start: $0, count: data.count/MemoryLayout<UInt32>.size))
//        }
//        //結果の表示
//        var face_array: [UInt32] = []
//        for j in 0..<anchor.geometry.faces.count {
//            for offset in 0..<anchor.geometry.faces.indexCountPerPrimitive {
//                let vertexIndexAddress = anchor.geometry.faces.buffer.contents().advanced(by: (j * anchor.geometry.faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
//                let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
//                face_array.append(UInt32(per_face_index))
//            }
//        }
        
        let data = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, deallocator: .none)
        var resultData = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
        resultData = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: data.count/MemoryLayout<SIMD3<Float>>.size))
        }
        //print("[Input data]: \(face_array)")
        print("[Result data]: \(resultData)")
    }
    
    func calcu2() -> SCNNode {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
        //main処理
        encoder.setBuffer(vertices, offset: 0, index: 0)
        encoder.setBuffer(normals, offset: 0, index: 1)
        encoder.setBuffer(faces, offset: 0, index: 2)
        
//        let matrixBuffer = device.makeBuffer(bytes: [matrix[0]], length: MemoryLayout<float4x4>.stride, options: .storageModeShared)
//        encoder.setBuffer(matrixBuffer, offset: 0, index: 3)
        
        let count = results[0].cells[0].models[0].pic.count
        let yoko: Float = 17.0
        let tate: Float = ceil(Float(count)/yoko)
        let json_data = try? decoder.decode(MakeMap_parameta.self, from:results[0].cells[0].models[0].json[0].json_data!)
        let viewMatrix = simd_float4x4(json_data!.viewMatrix.x,
                                       json_data!.viewMatrix.y,
                                       json_data!.viewMatrix.z,
                                       json_data!.viewMatrix.w)
        let projectionMatrix = simd_float4x4(json_data!.projectionMatrix.x,
                                             json_data!.projectionMatrix.y,
                                             json_data!.projectionMatrix.z,
                                             json_data!.projectionMatrix.w)
        let matrix = projectionMatrix * viewMatrix
        calcuUniforms.tate = Int32(tate)
        calcuUniforms.yoko = Int32(yoko)
        calcuUniforms.matrix = matrix
        calcuUniforms.transform = anchor.transform
        
        let CalcuUniformsBuffer = device.makeBuffer(bytes: [calcuUniforms], length: MemoryLayout<CalcuUniforms>.stride, options: .storageModeShared)
        encoder.setBuffer(CalcuUniformsBuffer, offset: 0, index: 3)
        
        var texcoords: [SIMD2<Float>] = []
        for _ in 0..<face_count {
            texcoords.append(SIMD2<Float>(0,0))
        }
        let texcoordsBuffer = device.makeBuffer(bytes: texcoords, length: MemoryLayout<SIMD2<Float>>.stride * face_count, options: .storageModeShared)
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 4)
        
        let width = 32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (face_count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let data = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count, deallocator: .none)
        var resultData = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count)
        resultData = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: data.count/MemoryLayout<SIMD2<Float>>.size))
        }
        //結果の表示
        print("[Input data]: \(texcoords)")
        print("[Result data]: \(resultData)")
        
        let node = build(texcoords: resultData)
    
        return node
    }
    
    func build(texcoords: [SIMD2<Float>]) -> SCNNode {
        let verticles = anchor.geometry.vertices
        let normals = anchor.geometry.normals
        let faces = anchor.geometry.faces
        
        let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
        let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
        let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
        let facesElement = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
        var sources = [verticesSource, normalsSource]
        
        let textureCoordinates = SCNGeometrySource(textureCoordinates2: texcoords)
        sources.append(textureCoordinates)
        
        let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
        nodeGeometry.firstMaterial?.diffuse.contents = UIImage(data: results[0].cells[0].models[0].texture_pic)
        
        let node = SCNNode(geometry: nodeGeometry)
        node.simdTransform = anchor.transform
        
        return node
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
    
    func read() {
        print(vertices)
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
