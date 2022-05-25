//
//  CalculateRenderer.swift
//  ARMesh
//
//  Created by 安江洸希 on 2021/12/06.
//

import Metal
import MetalKit
import ARKit
import RealmSwift

class CalculateRenderer {
    private let device: MTLDevice!
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLComputePipelineState!
    private var viewportSize = CGSize()
    
    private let models: Navi_Modelname
    private let anchors: [ARMeshAnchor]
    private let calcuUniforms: [float4x4]
    private let depth: [depthPosition]
    private let calculateParameta: calculateParameta
    
    private var vertices = [SIMD3<Float>]()
    private var normals = [SIMD3<Float>]()
    private var faces = [Int32]()
    private var texcoords = [SIMD2<Float>]()
    private var face_count: Int!
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    let decoder = JSONDecoder()
    
    private var anchorUniformsBuffer: MetalBuffer<anchorUniforms>
    
    //ポリゴン数の合計
    var sumPolygon = 0
    var texCount = 0
    
    init(models: Navi_Modelname, anchor: [ARMeshAnchor], calcuUniforms: [float4x4], depth: [depthPosition], calculateParameta: calculateParameta) {
        
        self.models = models
        self.anchors = anchor
        self.calcuUniforms = calcuUniforms
        self.depth = depth
        self.calculateParameta = calculateParameta
        
        device = calculateParameta.device
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        let function = library.makeFunction(name: calculateParameta.funcString)!
        pipeline = try! device.makeComputePipelineState(function: function)
        
        anchorUniformsBuffer = .init(device: device, count: 1, index: 9)
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    func calcu5(num: Int) -> Int {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        
        face_count = anchors[num].geometry.faces.count
//        print("頂点数(面の数×3):\(anchors[num].geometry.faces.count * 3)")
//        print("id数(面の数:ポリゴン数)：\(anchors[num].geometry.faces.count)")
        sumPolygon += anchors[num].geometry.faces.count
        
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
        anchorUniformsBuffer[0].tate = Int32(calculateParameta.tate)
        anchorUniformsBuffer[0].yoko = Int32(calculateParameta.yoko)
        anchorUniformsBuffer[0].maxCount = Int32(anchors[num].geometry.faces.count)
        anchorUniformsBuffer[0].arrayCount = Int32(anchors[num].geometry.faces.count * 3)
        anchorUniformsBuffer[0].depthCount = Int32(128*96)
        anchorUniformsBuffer[0].screenWidth = Int32(calculateParameta.screenWidth)
        anchorUniformsBuffer[0].screenHeight = Int32(calculateParameta.screenHeight)
        encoder.setBuffer(anchorUniformsBuffer)
        
        //深度情報
        let depthBuffer = device.makeBuffer(bytes: depth, length: MemoryLayout<depthPosition>.stride * 128*96 * calcuUniforms.count, options: [])
        encoder.setBuffer(depthBuffer, offset: 0, index: 10)
        
        let tryBuffer = device.makeBuffer(bytes: [0], length: MemoryLayout<Int>.stride, options: [])
        //device.makeBuffer(length: MemoryLayout<Int32>.stride * 128*96, options: [])
        encoder.setBuffer(tryBuffer, offset: 0, index: 11)
        
        let width = 1//32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (anchors[num].geometry.faces.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        vertices = vertexData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        //print("Data : \(vertexData)")
        
        let normalsData = Data(bytesNoCopy: new_normalsBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        normals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
        normals = normalsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: normalsData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count! * 3, deallocator: .none)
        faces = [Int32](repeating: Int32(0), count: face_count! * 3)
        faces = facesData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
        }
        
        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, deallocator: .none)
        texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count! * 3)
        texcoords = texcoordsData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
        }
        
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<Int>.stride, deallocator: .none)
//        var tryCount = [0]
//        tryCount = tryData.withUnsafeBytes{
//            Array(UnsafeBufferPointer<Int>(start: $0, count: tryData.count/MemoryLayout<Int>.size))}
//        print("count：\(tryCount)")
        //print(texcoords)
        
        for t in texcoords {
            if t == SIMD2<Float>(0.0, 0.0) {
                texCount += 1
            }
        }
        
        save_model(num: num)
    
        return 1
    }
    
    func save_model(num: Int) {
        let texcoordsData = try! JSONEncoder().encode(texcoords)
        let facesData = try! JSONEncoder().encode(faces)
        let vertexData = Data(bytes: vertices, count: MemoryLayout<SIMD3<Float>>.size * vertices.count)
        let normalsData = Data(bytes: normals, count: MemoryLayout<SIMD3<Float>>.size * normals.count)
        
        let realm = try! Realm()
        try! realm.write {
            models.mesh_anchor[num].texcoords = texcoordsData
            models.mesh_anchor[num].vertices = vertexData
            models.mesh_anchor[num].normals = normalsData
            models.mesh_anchor[num].faces = facesData
            models.mesh_anchor[num].vertice_count = face_count * 3
            models.texture_bool = 3
        }
    }
}
