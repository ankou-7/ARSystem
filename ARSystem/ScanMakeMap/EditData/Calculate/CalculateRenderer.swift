//
//  CalculateRenderer.swift
//  ARMesh
//
//  Created by 安江洸希 on 2021/12/06.
//

import Metal
import MetalKit
import ARKit

class CalculateRenderer {
    private let device: MTLDevice!
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLComputePipelineState!
    private var viewportSize = CGSize()
    
    private let models_dayString: String
    var modelID: Int
    private let calcuUniforms: [float4x4]
    private let depth: [depthPosition]
    private let calculateParameta: calculateParameta
    
    private var vertices = [SIMD3<Float>]()
    private var normals = [SIMD3<Float>]()
    private var faces = [Int32]()
    private var texcoords = [SIMD2<Float>]()
    private var face_count: Int!
    
    let decoder = JSONDecoder()
    
    private var anchorUniformsBuffer: MetalBuffer<anchorUniforms>
    
    let maxInFlightBuffers = 3
    private let inFlightSemaphore: DispatchSemaphore
    
    //ポリゴン数の合計
    var sumPolygon = 0
    var texCount = 0
    
    init(models_dayString: String, modelID: Int, calcuUniforms: [float4x4], depth: [depthPosition], calculateParameta: calculateParameta) {
        
        self.models_dayString = models_dayString
        self.modelID = modelID
        self.calcuUniforms = calcuUniforms
        self.depth = depth
        self.calculateParameta = calculateParameta
        
        device = calculateParameta.device
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        let function = library.makeFunction(name: calculateParameta.funcString)!
        pipeline = try! device.makeComputePipelineState(function: function)
        
        anchorUniformsBuffer = .init(device: device, count: 1, index: 9)
        
        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
        
        //makeDirectory()
        DataManagement.makeDirectory(name: "\(models_dayString)/\(modelID)/texcoords")
        DataManagement.makeDirectory(name: "\(models_dayString)/\(modelID)/vertex")
        DataManagement.makeDirectory(name: "\(models_dayString)/\(modelID)/normals")
        DataManagement.makeDirectory(name: "\(models_dayString)/\(modelID)/faces")
        
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
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
        print("紐付けた画像数:\(picNum.count):\(picNum)")
        
        return picNum
    }
    
    func calcu5(num: Int, anchor: ARMeshAnchor) -> Int {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
        encoder.setComputePipelineState(pipeline)
        face_count = anchor.geometry.faces.count
        print("\(num):頂点数(面の数×3):\(anchor.geometry.faces.count * 3)")
//        print("id数(面の数:ポリゴン数)：\(anchor.geometry.faces.count)")
        sumPolygon += anchor.geometry.faces.count
        
        //入力
        encoder.setBuffer(anchor.geometry.vertices.buffer, offset: 0, index: 0)
        encoder.setBuffer(anchor.geometry.normals.buffer, offset: 0, index: 1)
        encoder.setBuffer(anchor.geometry.faces.buffer, offset: 0, index: 2)
        
        
        
//        for offset in 0..<anchor.geometry.faces.indexCountPerPrimitive {
//            let vertexIndexAddress = anchor.geometry.faces.buffer.contents().advanced(by: (1 * anchor.geometry.faces.indexCountPerPrimitive + offset) * MemoryLayout<UInt32>.size)
//            let per_face_index = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
//            print(per_face_index)
//        }
        
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
        
        //メッシュアンカーに紐付けた画像番号を取得
        var picNum = read_anchor_picNum(i: num)
        let picNumBuffer = device.makeBuffer(bytes: picNum, length: MemoryLayout<Int32>.stride * picNum.count, options: [])
        encoder.setBuffer(picNumBuffer, offset: 0, index: 12)
        
        //割り当てたポリゴンの位置を判別する配列
        let idBuffer = device.makeBuffer(bytes: [Int32](repeating: Int32(0), count: anchor.geometry.faces.count), length: MemoryLayout<Int32>.stride * anchor.geometry.faces.count, options: [])
        encoder.setBuffer(idBuffer, offset: 0, index: 13)
        
        //計算に必要なその他
        anchorUniformsBuffer[0].transform = anchor.transform
        anchorUniformsBuffer[0].calcuCount = Int32(calcuUniforms.count)
        anchorUniformsBuffer[0].tate = Int32(calculateParameta.tate)
        anchorUniformsBuffer[0].yoko = Int32(calculateParameta.yoko)
        anchorUniformsBuffer[0].maxCount = Int32(anchor.geometry.faces.count)
        anchorUniformsBuffer[0].arrayCount = Int32(anchor.geometry.faces.count * 3)
        anchorUniformsBuffer[0].depthCount = Int32(128*96)
        anchorUniformsBuffer[0].screenWidth = Int32(calculateParameta.screenWidth)
        anchorUniformsBuffer[0].screenHeight = Int32(calculateParameta.screenHeight)
        anchorUniformsBuffer[0].picNumCount = Int32(picNum.count)
        encoder.setBuffer(anchorUniformsBuffer)
        
        //深度情報
        let depthBuffer = device.makeBuffer(bytes: depth, length: MemoryLayout<depthPosition>.stride * 128*96 * calcuUniforms.count, options: [])
        encoder.setBuffer(depthBuffer, offset: 0, index: 10)
        
        let tryBuffer = device.makeBuffer(bytes: [Int32](repeating: Int32(0), count: picNum.count), length: MemoryLayout<Int32>.stride * picNum.count, options: [])
        //device.makeBuffer(length: MemoryLayout<Int32>.stride * 128*96, options: [])
        encoder.setBuffer(tryBuffer, offset: 0, index: 11)
        
        let width = 32 //32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (anchor.geometry.faces.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        let normalsData = Data(bytesNoCopy: new_normalsBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count! * 3, deallocator: .none)
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count! * 3, deallocator: .none)
        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count! * 3, deallocator: .none)
        
//        print("facesData.count:\(facesData.count / MemoryLayout<Int32>.stride)")
//        print("face_count:\(face_count! * 3)")
        
        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<Int32>.stride * picNum.count, deallocator: .none)
        var tryCount = [Int32](repeating: Int32(0), count: picNum.count)
        tryCount = tryData.withUnsafeBytes{
            Array(UnsafeBufferPointer<Int32>(start: $0, count: tryData.count/MemoryLayout<Int32>.size))}
        //print("trys：\(tryCount)")
        
        //print(texcoords)
        
        if calculateParameta.funcString == "choicePic_textureCalculate" {
            save_allData(num: num, texcoordsData: texcoordsData, vertexData: vertexData, normalsData: normalsData, facesData: facesData)
        } else {
            //変換
            vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
            vertices = vertexData.withUnsafeBytes {
                Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
            }
            normals = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count! * 3)
            normals = normalsData.withUnsafeBytes {
                Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: normalsData.count/MemoryLayout<SIMD3<Float>>.size))
            }
            faces = [Int32](repeating: Int32(0), count: face_count! * 3)
            faces = facesData.withUnsafeBytes {
                Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
            }
            texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count! * 3)
            texcoords = texcoordsData.withUnsafeBytes {
                Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
            }
            
            for t in texcoords {
                if t == SIMD2<Float>(0.0, 0.0) {
                    texCount += 1
                }
            }
            print("\(num):出力数:\(texcoords.count)")
            
            save_model(num: num)
        }
    
        return 1
    }
    
    
    //MARK: - メッシュ情報を結合したバッファを使用した方法
    //*計算に使用するデータを全て結合する必要がある
    func use_AllBuffer_Calcu(facesCount: Int, facesBuffer: MTLBuffer, verticesBuffer: MTLBuffer, normalsBuffer: MTLBuffer, sepaFacesBuffer: MTLBuffer, sepaVerticesBuffer: MTLBuffer, anchorTransformBUffer: MTLBuffer, picNumArrayBuffer: MTLBuffer, sepaPicNumArrayBuffer: MTLBuffer) { //}-> (Data, Data, Data, Data, [Int32], [SIMD2<Float>]) {
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
        encoder.setComputePipelineState(pipeline)
        
        //入力
        encoder.setBuffer(verticesBuffer, offset: 0, index: 0)
        encoder.setBuffer(normalsBuffer, offset: 0, index: 1)
        encoder.setBuffer(facesBuffer, offset: 0, index: 2)
        
        encoder.setBuffer(sepaVerticesBuffer, offset: 0, index: 3)
        encoder.setBuffer(sepaFacesBuffer, offset: 0, index: 4)
        
        //出力
        let texcoordsBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * facesCount, options: [])
        let new_verticesBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * facesCount, options: [])
        let new_normalsBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * facesCount, options: [])
        let new_facesBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride * facesCount, options: [])
        
        encoder.setBuffer(texcoordsBuffer, offset: 0, index: 5)
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 6)
        encoder.setBuffer(new_normalsBuffer, offset: 0, index: 7)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 8)
        
        //計算に必要なその他 9
        //anchorUniformsBuffer[0].transform = anchor.transform
        anchorUniformsBuffer[0].calcuCount = Int32(calcuUniforms.count)
        anchorUniformsBuffer[0].tate = Int32(calculateParameta.tate)
        anchorUniformsBuffer[0].yoko = Int32(calculateParameta.yoko)
        anchorUniformsBuffer[0].maxCount = Int32(facesCount/3)
        //anchorUniformsBuffer[0].arrayCount = Int32(anchor.geometry.faces.count * 3)
        anchorUniformsBuffer[0].depthCount = Int32(128*96)
        anchorUniformsBuffer[0].screenWidth = Int32(calculateParameta.screenWidth)
        anchorUniformsBuffer[0].screenHeight = Int32(calculateParameta.screenHeight)
        //anchorUniformsBuffer[0].picNumCount = Int32(picNum.count)
        encoder.setBuffer(anchorUniformsBuffer)
        
        //スクリーン座標変換用の行列
        let calcuUniformsBuffer = device.makeBuffer(bytes: calcuUniforms, length: MemoryLayout<float4x4>.stride * calcuUniforms.count, options: [])
        encoder.setBuffer(calcuUniformsBuffer, offset: 0, index: 10)
        
        //アンカーのtranform配列のバッファ
        encoder.setBuffer(anchorTransformBUffer, offset: 0, index: 11)
        
        //深度情報
        let depthBuffer = device.makeBuffer(bytes: depth, length: MemoryLayout<depthPosition>.stride * 128*96 * calcuUniforms.count, options: [])
        encoder.setBuffer(depthBuffer, offset: 0, index: 12)
        
        //メッシュアンカーに紐付けた画像番号
        encoder.setBuffer(picNumArrayBuffer, offset: 0, index: 13)
        encoder.setBuffer(sepaPicNumArrayBuffer, offset: 0, index: 14)
        
        let tryBuffer = device.makeBuffer(bytes: [float4x4](repeating: float4x4(SIMD4<Float>(0,0,0,0), SIMD4<Float>(0,0,0,0),
                                                                                SIMD4<Float>(0,0,0,0), SIMD4<Float>(0,0,0,0)), count: 17),
                                          length: MemoryLayout<float4x4>.stride * 17, options: [])
        encoder.setBuffer(tryBuffer, offset: 0, index: 15)

        
        let width = 32 //32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (facesCount/3 + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * facesCount, deallocator: .none)
        let normalsData = Data(bytesNoCopy: new_normalsBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * facesCount, deallocator: .none)
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * facesCount, deallocator: .none)
        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * facesCount, deallocator: .none)
        
//        //確認用
//        vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: facesCount)
//        vertices = vertexData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
//        for v in vertices[0...10] {
//            print(v)
//        }
//        for v in vertices[vertices.count-10...vertices.count-1] {
//            print(v)
//        }
        
//        faces = [Int32](repeating: Int32(0), count: facesCount)
//        faces = facesData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
//        }
//        print(faces[0...10])
//        texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: facesCount)
//        texcoords = texcoordsData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
//        }
        
        //結果を保存
        //delete_allData()
        //makeDirectory()
        save_allData(num: 0, texcoordsData: texcoordsData, vertexData: vertexData, normalsData: normalsData, facesData: facesData)
    
        //return (texcoordsData, vertexData, normalsData, facesData, faces, texcoords)
    }
    
    //テクスチャ座標の計算時にデータ保存用のディレクトリを作成する関数
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
    
    func save_allData(num: Int, texcoordsData: Data, vertexData: Data, normalsData: Data, facesData: Data) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let texcoordsPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/texcoords/texcoords\(num).data")
        let vertexPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/vertex/vertex\(num).data")
        let normalsPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/normals/normals\(num).data")
        let facesPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/faces/faces\(num).data")
        do {
            try texcoordsData.write(to: texcoordsPath)
            try vertexData.write(to: vertexPath)
            try normalsData.write(to: normalsPath)
            try facesData.write(to: facesPath)
            print("GPU計算データ\(num)保存成功")
        } catch {
            print("GPU計算データ\(num)保存失敗", error)
        }
    }
    
    func delete_allData() {
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/texcoords")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/vertex")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/normals")
        DataManagement.removeDirectory(name: "\(models_dayString)/\(modelID)/faces")
    }
    
    func save_data(data: Data, filePath: String) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let Path = url.appendingPathComponent(filePath)
        do {
            try data.write(to: Path)
        } catch {
            print("保存失敗", error)
        }
    }
    
    func save_model(num: Int) {
        let texcoordsData = try! JSONEncoder().encode(texcoords)
        let facesData = try! JSONEncoder().encode(faces)
        let vertexData = Data(bytes: vertices, count: MemoryLayout<SIMD3<Float>>.size * vertices.count)
        let normalsData = Data(bytes: normals, count: MemoryLayout<SIMD3<Float>>.size * normals.count)
        
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let texcoordsPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/texcoords/texcoords\(num).data")
        let vertexPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/vertex/vertex\(num).data")
        let normalsPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/normals/normals\(num).data")
        let facesPath = url.appendingPathComponent("\(models_dayString)/\(modelID)/faces/faces\(num).data")
        do {
            try texcoordsData.write(to: texcoordsPath)
            try vertexData.write(to: vertexPath)
            try normalsData.write(to: normalsPath)
            try facesData.write(to: facesPath)
            print("GPU計算データ\(num)保存成功")
        } catch {
            print("GPU計算データ\(num)保存失敗", error)
        }
    }
}
