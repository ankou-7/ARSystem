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
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLComputePipelineState!
    private var viewportSize = CGSize()
    
    private let section_num: Int
    private let cell_num: Int
    private let current_model_num: Int
    
    private let anchors: [ARMeshAnchor]
//    private let vertices: MTLBuffer
//    private let normals: MTLBuffer
//    private let faces: MTLBuffer
//    private let face_count: Int
    
    private let tate: Int
    private let yoko: Int
    
    private let screenWidth: Int
    private let screenHeight: Int
    
    var face_count: Int!
    
    let results = try! Realm().objects(Navi_SectionTitle.self)
    let decoder = JSONDecoder()
    
    private let calcuUniforms: [float4x4]
    private let depth: [depthPosition]
    
    init(section_num: Int, cell_num: Int, model_num: Int, anchor: [ARMeshAnchor], metalDevice device: MTLDevice, calcuUniforms: [float4x4], depth: [depthPosition], tate: Int, yoko: Int, screenWidth: Int, screenHeight: Int, texString: String) {
        
        self.section_num = section_num
        self.cell_num = cell_num
        self.current_model_num = model_num
        
        self.device = device
        
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        let function = library.makeFunction(name: texString)!
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
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        
        //print(calcuUniforms)
        //calcuUniformsBuffer = .init(device: device, count: calcuUniforms.count, index: 8)
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
        print("頂点数(面の数×3):\(anchors[num].geometry.faces.count * 3)")
        print("id数(面の数)：\(anchors[num].geometry.faces.count)")
        
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
        anchorUniformsBuffer[0].tate = Int32(tate)
        anchorUniformsBuffer[0].yoko = Int32(yoko)
        anchorUniformsBuffer[0].maxCount = Int32(anchors[num].geometry.faces.count)
        anchorUniformsBuffer[0].arrayCount = Int32(anchors[num].geometry.faces.count * 3)
        anchorUniformsBuffer[0].depthCount = Int32(128*96)
        anchorUniformsBuffer[0].screenWidth = Int32(screenWidth)
        anchorUniformsBuffer[0].screenHeight = Int32(screenHeight)
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
        
        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<Int>.stride, deallocator: .none)
        var trys = [Int](repeating: 0, count: 1)
        trys = tryData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int>(start: $0, count: tryData.count/MemoryLayout<Int>.size))
        }
        print("描画頂点数：\(trys[0])")
        
        save_model(num: num, vertexs: vertexs, normals: normals, faces: faces, texcoords: texcoords, count: face_count * 3)
    
        return 1
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
        //print("save完了")
    }
}
