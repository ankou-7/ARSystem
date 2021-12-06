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

class CalculateRenderer {
    private let device: MTLDevice
    private let library: MTLLibrary
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLComputePipelineState!
    private var viewportSize = CGSize()
    
    private let vertices: MTLBuffer
    private let normals: MTLBuffer
    private let faces: MTLBuffer
    
    init(anchor: ARMeshAnchor, metalDevice device: MTLDevice) {
        self.device = device
        
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        let function = library.makeFunction(name: "calcu")!
        pipeline = try! device.makeComputePipelineState(function: function)
        
        self.vertices = anchor.geometry.vertices.buffer
        self.normals = anchor.geometry.normals.buffer
        self.faces = anchor.geometry.faces.buffer
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    func calcu() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(pipeline)
        
        var inputData:[[Float]] = []
        for i in 0..<2 {
            inputData.append([])
            for _ in 0...100-1 {
                inputData[i].append(Float(arc4random_uniform(UInt32(100))))
            }
        }
        let inputBuffer = device.makeBuffer(bytes: inputData, length: 2 * MemoryLayout<Float>.stride * inputData.count, options:.storageModeShared)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        //let outputData = [Float](repeating: 0, count: inputData.count)
        let outputData = [[Float]](repeating: [Float](repeating: 0, count: inputData[0].count), count:2)
        let outputDataBuffer = device.makeBuffer(bytes: outputData, length: 2 * MemoryLayout<Float>.stride * outputData[0].count, options:.storageModeShared)
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
        let data = Data(bytesNoCopy: outputDataBuffer!.contents(), count: 2 * MemoryLayout<Float>.stride * outputData[0].count, deallocator: .none)
        var resultData = [Float](repeating: 1, count: outputData.count * 2)
        resultData = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Float>(start: $0, count: data.count/MemoryLayout<Float>.size))
        }
        
        for i in 0..<100 {
            print(outputDataBuffer[i])
        }
        //結果の表示
        print("[Input data]: \(inputData)")
        print("[Result data]: \(resultData)")
        
//        encoder.setBuffer(vertices, offset: 0, index: 0)
//        encoder.setBuffer(normals, offset: 0, index: 1)
//        encoder.setBuffer(faces, offset: 0, index: 2)
    }
    
    func read() {
        print(vertices)
    }

}
