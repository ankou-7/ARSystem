//
//  depth_Renderer.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/11/28.
//

import Metal
import MetalKit
import ARKit
import SwiftUI

struct depthPosition:Codable {
    var x: Float, y: Float, z: Float
}

final class depth_Renderer {
    var maxPoints: Int32 = 128*96//256*192
    var numPoints: Int = 128*96//256*192
    var particleSize: Float = 10.0
    //画面の向きを設定
    private let orientation = UIInterfaceOrientation.portrait
    private let cameraRotationThreshold = cos(2 * .degreesToRadian)
    private let cameraTranslationThreshold: Float = pow(0.02, 2)
    private let maxInFlightBuffers = 3
    private lazy var rotateToARCamera = Self.depth_makeRotateToARCameraMatrix(orientation: orientation)
    private let session: ARSession

    private let device: MTLDevice
    private let library: MTLLibrary
    private let sceneView: ARSCNView
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    private let commandQueue: MTLCommandQueue
    private let commandQueue2: MTLCommandQueue
    private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
    private lazy var particlePipelineState = makeParticlePipelineState()!
    
    private lazy var depthPipelineState = makeDepthPipelineState()!
    private lazy var meshPipelineState = makeMeshPipelineState()!
    private lazy var meshPipelineState2 = makeMeshPipelineState2()!
    private var meshPipeline: MTLComputePipelineState!

    private lazy var textureCache = makeTextureCache()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private var depthTexture: CVMetalTexture?
    private var confidenceTexture: CVMetalTexture?

    private let inFlightSemaphore: DispatchSemaphore
    private var currentBufferIndex = 0

    private var viewportSize = CGSize()
    private lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                                            array: makeGridPoints(),
                                                            index: kGridPoints.rawValue, options: [])

    private lazy var pointCloudUniforms: PointCloudUniforms = {
        var uniforms = PointCloudUniforms()
        uniforms.maxPoints = Int32(maxPoints)
        uniforms.confidenceThreshold = Int32(confidenceThreshold)
        uniforms.particleSize = particleSize
        uniforms.cameraResolution = cameraResolution
        return uniforms
    }()
    private var PointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()

    // Particles buffer
    private var particlesBuffer: MetalBuffer<ParticleUniforms>
    private var currentPointIndex = 0
    private var currentPointCount = 0
    
    private var particlesDepthBuffer: MetalBuffer<DepthUniforms>
    
    private var MeshBuffer: MetalBuffer<MeshUniforms>
    private var currentMeshPointIndex = 0
    private var currentMeshPointCount = 0
    private lazy var RealAnchorUniforms = realAnchorUniforms()
    private var AnchorUniformasBuffers = [MetalBuffer<realAnchorUniforms>]()
    private var currentAnchorUniformsBufferIndex = 0
    private var anchorUniformsBuffer: MetalBuffer<realAnchorUniforms>

    // Camera data
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height))
    private lazy var viewToCamera = sampleFrame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
    private lazy var lastCameraTransform = sampleFrame.camera.transform

    var confidenceThreshold = 2

//    //追加
    private var isSavingFile = false
    var vertexData: [Vertex] = []
    var vertexBuffer: MTLBuffer!
    var colorData: [Color] = []
    var colorBuffer: MTLBuffer!
    var count = 0

    var vertice_count = 0
    var vertice_data: [PointCloudVertex] = []

    var send_vertice_data: [PointCloudVertex] = []

    //init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
    init(session: ARSession, metalDevice device: MTLDevice, sceneView: ARSCNView) {
        print("point cloud Renderer initializing")

        self.session = session
        self.device = device
        //self.renderDestination = renderDestination
        self.sceneView = sceneView

        library = device.makeDefaultLibrary()!
        commandQueue2 = device.makeCommandQueue()! //computeCommand用
        commandQueue = sceneView.commandQueue! //sceneView用

        // initialize our buffers
        for _ in 0 ..< maxInFlightBuffers {
//            rgbUniformsBuffers.append(.init(device: device, count: 1, index: 0))
            PointCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
            AnchorUniformasBuffers.append(.init(device: device, count: 1, index: 6))
        }
        particlesBuffer = .init(device: device, count: Int(maxPoints), index: kParticleUniforms.rawValue)
        particlesDepthBuffer = .init(device: device, count: Int(maxPoints), index: kParticleUniforms.rawValue)
        MeshBuffer = .init(device: device, count: 999_999, index: 5)
        
        anchorUniformsBuffer = .init(device: device, count: 1, index: 10)
        let function = library.makeFunction(name: "meshCalculate")!
        meshPipeline = try! device.makeComputePipelineState(function: function)

        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!

        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        //depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.depthCompareFunction = .greaterEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!

        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
    }

    func drawRectResized(size: CGSize) {
        viewportSize = size
    }

    private func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return
        }

        capturedImageTextureY = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }

    private func updateDepthTextures(frame: ARFrame) -> Bool {
        guard let depthMap = frame.sceneDepth?.depthMap,
            let confidenceMap = frame.sceneDepth?.confidenceMap else {
                return false
        }
//        guard let depthMap = frame.smoothedSceneDepth?.depthMap,
//            let confidenceMap = frame.smoothedSceneDepth?.confidenceMap else {
//                return false
//        }

        depthTexture = makeTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
        confidenceTexture = makeTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)

        return true
    }

    private func update(frame: ARFrame) {
        // frame dependent info
        let camera = frame.camera
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)

        pointCloudUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
        pointCloudUniforms.localToWorld = viewMatrixInversed * rotateToARCamera
        pointCloudUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
    }

    func draw() {
        guard let currentFrame = session.currentFrame,
              let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = sceneView.currentRenderCommandEncoder else {
                return
        }
        

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }

        // update frame data
        update(frame: currentFrame)
        updateCapturedImageTextures(frame: currentFrame)

        // handle buffer rotating
        currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
        PointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms

        if shouldAccumulate(frame: currentFrame), updateDepthTextures(frame: currentFrame) {
            accumulatePoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        }

        //取得した特徴点（色付き）
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(particlePipelineState)
        renderEncoder.setVertexBuffer(PointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentPointCount)

        commandBuffer.commit()
    }

    private func shouldAccumulate(frame: ARFrame) -> Bool {
        //return true
        let cameraTransform = frame.camera.transform
        let shouldAccum = currentPointCount == 0
          || dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
          || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3) >= cameraTranslationThreshold

        return shouldAccum
    }

    private func accumulatePoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {

        pointCloudUniforms.pointCloudCurrentIndex = Int32(currentPointIndex)

        var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture]
        commandBuffer.addCompletedHandler { buffer in
            retainingTextures.removeAll()
        }

        renderEncoder.setDepthStencilState(relaxedStencilState)
        renderEncoder.setRenderPipelineState(unprojectPipelineState)
        renderEncoder.setVertexBuffer(PointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.setVertexBuffer(gridPointsBuffer)
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)

        currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % Int(maxPoints)
        currentPointCount = min(currentPointCount + gridPointsBuffer.count, Int(maxPoints))

        lastCameraTransform = frame.camera.transform
    }
    
    //MARK: -計算
    func draw100() {
        guard let currentFrame = session.currentFrame,
              let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = sceneView.currentRenderCommandEncoder else {
                return
        }

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }

        // update frame data
        update(frame: currentFrame)
        updateCapturedImageTextures(frame: currentFrame)

        // handle buffer rotating
        currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
        PointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms

        if updateDepthTextures(frame: currentFrame) {
            accumulateDepthPoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        }
        
        commandBuffer.commit()
    }
    
    func accumulateDepthPoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {

        pointCloudUniforms.pointCloudCurrentIndex = Int32(currentPointIndex)

        var retainingTextures = [depthTexture, confidenceTexture]
        commandBuffer.addCompletedHandler { buffer in
            retainingTextures.removeAll()
        }

        renderEncoder.setDepthStencilState(relaxedStencilState)
        renderEncoder.setRenderPipelineState(depthPipelineState)
        renderEncoder.setVertexBuffer(PointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesDepthBuffer)
        renderEncoder.setVertexBuffer(gridPointsBuffer)
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)

        currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % Int(maxPoints)
        currentPointCount = min(currentPointCount + gridPointsBuffer.count, Int(maxPoints))

        lastCameraTransform = frame.camera.transform
    }
    
    //depthデータ取得用
    func depthData() -> Data {
//        print(particlesDepthBuffer.count)
        //print(particlesDepthBuffer[100])
//        print(particlesDepthBuffer[100].confidence)
        for i in 0...30 {
            print(MeshBuffer[i])
        }
        
        var depth_array: [depthPosition] = []
        for i in 0..<currentPointCount {
            let point = particlesDepthBuffer[i]
            //depth_array.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: 255, g: 255, b: 255))
            depth_array.append(depthPosition(x: point.position.x, y: point.position.y, z: point.position.z))
        }

        let depthData = try! JSONEncoder().encode(depth_array)
        
//        var depth_array: [SCNVector3] = []
//        for i in 0..<currentPointCount {
//            let point = particlesDepthBuffer[i]
//            depth_array.append(SCNVector3(x: point.position.x, y: point.position.y, z: point.position.z))
//        }
//        let depthData = Data(bytes: depth_array, count: MemoryLayout<SCNVector3>.size * depth_array.count)
        
        return depthData
    }
    
    func depth_point() -> [SCNVector3] {
        var depth_array: [SCNVector3] = []
        for i in 0..<currentPointCount {
            let point = particlesDepthBuffer[i]
            depth_array.append(SCNVector3(x: point.position.x, y: point.position.y, z: point.position.z))
        }
        return depth_array
    }
    
    //mesh処理用
    func drawMesh2() {
        guard let currentFrame = session.currentFrame,
              let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = sceneView.currentRenderCommandEncoder else {
                return
        }

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
        updateAnchorUniforms(frame: currentFrame)
        
        currentAnchorUniformsBufferIndex = (currentAnchorUniformsBufferIndex + 1) % 3
        AnchorUniformasBuffers[currentAnchorUniformsBufferIndex][0] = RealAnchorUniforms
        
        //計算
        accumulateMeshPoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(meshPipelineState)
        renderEncoder.setVertexBuffer(MeshBuffer) //5
        renderEncoder.setVertexBuffer(AnchorUniformasBuffers[currentAnchorUniformsBufferIndex]) //6
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: currentMeshPointCount / 3)
        
        commandBuffer.commit()
    }
    
    private func updateAnchorUniforms(frame: ARFrame) {
        // frame dependent info
        let camera = frame.camera
        //let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        //let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
        
        RealAnchorUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
    }
    
    var AnchorsID: UUID!
    
    func accumulateMeshPoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {
        
        //print("-------------------------------------------------------------------------------------------")
        let anchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        //print(anchors.count)
        for anchor in anchors {
            //let anchor = anchors[0]
            if anchor.identifier == AnchorsID {
                let face_count = anchor.geometry.faces.count
                //print("face_count = \(face_count)")
                
                RealAnchorUniforms.maxCount = 999_999//Int32(face_count)
                RealAnchorUniforms.transform = anchor.transform
                //RealAnchorUniforms.currentIndex = Int32(currentMeshPointIndex)
                
                renderEncoder.setDepthStencilState(relaxedStencilState)
                renderEncoder.setRenderPipelineState(meshPipelineState2)
                renderEncoder.setVertexBuffer(anchor.geometry.vertices.buffer, offset: 0, index: 0)
                renderEncoder.setVertexBuffer(anchor.geometry.faces.buffer, offset: 0, index: 1)
                renderEncoder.setVertexBuffer(MeshBuffer) //5
                renderEncoder.setVertexBuffer(AnchorUniformasBuffers[currentAnchorUniformsBufferIndex]) //6
                renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: face_count * 3) //実行回数
                
                //currentMeshPointIndex = (currentMeshPointIndex + face_count * 3) % 999_999
                if face_count * 3 < 999_999 {
                    currentMeshPointCount = max(face_count * 3, currentMeshPointCount)
                } else {
                    currentMeshPointCount = 999_999
                }
                //currentMeshPointCount = min(face_count * 3, 999_999) //min(currentMeshPointCount + face_count * 3, 999_999)
                //print("currentMeshPointCount = \(currentMeshPointCount)")
                
//                var face_array: [Int32] = []
//                for j in 0..<anchor.geometry.faces.count {
//                    let indicesPerFace = anchor.geometry.faces.indexCountPerPrimitive
//                    for offset in 0..<indicesPerFace {
//                        let vertexIndexAddress = anchor.geometry.faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
//                        let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
//                        face_array.append(per_face)
//                    }
//                }
//                print(face_array)
            }
        }
        
        
        //print("face_array.count = \(face_array.count)")

//        let new_verticesBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: [])
//        let new_facesBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride * face_count * 3, options: [])
//        renderEncoder.setVertexBuffer(new_verticesBuffer, offset: 0, index: 2)
//        renderEncoder.setVertexBuffer(new_facesBuffer, offset: 0, index: 3)
//
//        let tryBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride * face_count, options: [])
//        renderEncoder.setVertexBuffer(tryBuffer, offset: 0, index: 11)
//
//        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, deallocator: .none)
//        var vertexs = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
//        vertexs = vertexData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
//        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count * 3, deallocator: .none)
//        var faces = [Int32](repeating: Int32(0), count: face_count * 3)
//        faces = facesData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
//        }
//
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count, deallocator: .none)
//        var trys = [Int32](repeating: Int32(0), count: face_count)
//        trys = tryData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<Int32>(start: $0, count: tryData.count/MemoryLayout<Int32>.size))
//        }
        
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count, deallocator: .none)
//        var trys = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count)
//        trys = tryData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: tryData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
//        print(trys)
        //print(faces)
        //print("faces.count = \(faces.count)")
    }
    
    var knownAnchors = Dictionary<UUID, SCNNode>()
    
    func drawMesh() { //(MTLBuffer?, MTLBuffer?) {
        let currentFrame = session.currentFrame!
        let commandBuffer = commandQueue2.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(meshPipeline)
        
        let anchors = currentFrame.anchors.compactMap { $0 as? ARMeshAnchor }
        print(anchors.count)
        
        let anchor = anchors[0]
        
        print("-------------------------------------------------------------------------------------------")
        print(knownAnchors)
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
//        var face_array: [Int32] = []
//        for j in 0..<anchor.geometry.faces.count {
//            let indicesPerFace = anchor.geometry.faces.indexCountPerPrimitive
//            for offset in 0..<indicesPerFace {
//                let vertexIndexAddress = anchor.geometry.faces.buffer.contents().advanced(by: (j * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
//                let per_face = Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee)
//                face_array.append(per_face)
//            }
//        }
//        print(face_array)
//        print("face_array.count = \(face_array.count)")
        
        encoder.setBuffer(anchor.geometry.vertices.buffer, offset: 0, index: 0)
        encoder.setBuffer(anchor.geometry.faces.buffer, offset: 0, index: 1)
        
        let face_count = anchor.geometry.faces.count
        print("face_count = \(face_count)")
        anchorUniformsBuffer[0].maxCount = Int32(face_count)
        encoder.setBuffer(anchorUniformsBuffer)
        
        let new_verticesBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, options: [])
        let new_facesBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride * face_count * 3, options: [])
        //let texcoordsBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * face_count * 3, options: [])
        encoder.setBuffer(new_verticesBuffer, offset: 0, index: 2)
        encoder.setBuffer(new_facesBuffer, offset: 0, index: 3)
        //encoder.setBuffer(texcoordsBuffer, offset: 0, index: 4)
        
        let width = 1//32
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (anchor.geometry.faces.count + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let vertexData = Data(bytesNoCopy: new_verticesBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * face_count * 3, deallocator: .none)
        var vertexs = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: face_count * 3)
        vertexs = vertexData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: vertexData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        let facesData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count * 3, deallocator: .none)
        var faces = [Int32](repeating: Int32(0), count: face_count * 3)
        faces = facesData.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int32>(start: $0, count: facesData.count/MemoryLayout<Int32>.size))
        }
//
//        let texcoordsData = Data(bytesNoCopy: texcoordsBuffer!.contents(), count: MemoryLayout<SIMD2<Float>>.stride * face_count * 3, deallocator: .none)
//        var texcoords = [SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: face_count * 3)
//        texcoords = texcoordsData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD2<Float>>(start: $0, count: texcoordsData.count/MemoryLayout<SIMD2<Float>>.size))
//        }
//        print(faces)
        
        let vertexSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: face_count * 3,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)

//        //geometry作成
//        let vertexSource = SCNGeometrySource(buffer: new_verticesBuffer!, vertexFormat: .float3, semantic: .vertex, vertexCount: face_count*3, dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride)
//        let faceData = Data(bytesNoCopy: new_facesBuffer!.contents(), count: MemoryLayout<Int32>.stride * face_count * 3, deallocator: .none)
//        let faceSource = SCNGeometryElement(data: faceData, primitiveType: .triangles, primitiveCount: face_count, bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [faceSource])
        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = UIColor.blue //UIColor(displayP3Red:1, green:1, blue:1, alpha:0.7)
        geometry.materials = [defaultMaterial]
        
        let node = knownAnchors[anchor.identifier]
        node!.geometry = geometry
        node!.simdTransform = anchor.transform

//        //return tex
//        return geometry
//        //return (new_verticesBuffer, new_facesBuffer)
    }
    
    
    
    
//    private func updateMesh(frame: ARFrame, anchor: ARMeshAnchor) {
//        // frame dependent info
//        let camera = frame.camera
//        //let cameraIntrinsicsInversed = camera.intrinsics.inverse
//        let viewMatrix = camera.viewMatrix(for: orientation)
//        //let viewMatrixInversed = viewMatrix.inverse
//        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
//
//        anchorUniformsBuffer[0].viewProjectionMatrix = projectionMatrix * viewMatrix
//        anchorUniformsBuffer[0].transform = anchor.transform
//    }
//
//    func drawMesh() {
//        guard let currentFrame = session.currentFrame else {
//            print("currentError")
//            return
//        }
//        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
//            print("commandError")
//            return
//        }
//        guard let renderEncoder = sceneView.currentRenderCommandEncoder else {
//            print(sceneView.currentRenderCommandEncoder)
//            print("renderError")
//            return
//        }
//        let anchors = currentFrame.anchors.compactMap { $0 as? ARMeshAnchor }
//        print("実行")
//
//        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
//        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
//            if let self = self {
//                self.inFlightSemaphore.signal()
//            }
//        }
//
//
//
//        updateMesh(frame: currentFrame, anchor: anchor)
//
//        //取得した特徴点（色付き）
//        renderEncoder.setDepthStencilState(depthStencilState)
//        renderEncoder.setRenderPipelineState(meshPipelineState)
//        renderEncoder.setVertexBuffer(anchor.geometry.vertices.buffer, offset: 0, index: 0)
//        renderEncoder.setVertexBuffer(anchor.geometry.faces.buffer, offset: 0, index: 1)
//        renderEncoder.setVertexBuffer(anchorUniformsBuffer)
//
//        let tryBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.vertices.count, options: [])
//        renderEncoder.setVertexBuffer(tryBuffer, offset: 0, index: 3)
//
//
//        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: anchor.geometry.vertices.count)
//
//        commandBuffer.commit()
//
//        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.vertices.count, deallocator: .none)
//        var trys = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: anchor.geometry.vertices.count)
//        trys = tryData.withUnsafeBytes {
//            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: tryData.count/MemoryLayout<SIMD3<Float>>.size))
//        }
//        print(trys[0...30])
//    }
}

//// MARK: - Metal Helpers

private extension depth_Renderer {
    func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "unprojectVertex") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeDepthPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "depth") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeMeshPipelineState2() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "meshCalculate2") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeMeshPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "meshVertex"),
            let fragmentFunction = library.makeFunction(name: "meshFragment") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func makeParticlePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
            let fragmentFunction = library.makeFunction(name: "particleFragment") else {
                return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    /// Makes sample points on camera image, also precompute the anchor point for animation
    func makeGridPoints() -> [Float2] {
        let gridArea = cameraResolution.x * cameraResolution.y
        let spacing = sqrt(gridArea / Float(numPoints))
        let deltaX = Int(round(cameraResolution.x / spacing))
        let deltaY = Int(round(cameraResolution.y / spacing))

        var points = [Float2]()
        for gridY in 0 ..< deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0 ..< deltaX {
                let cameraPoint = Float2(alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)

                points.append(cameraPoint)
            }
        }

        return points
    }

    func makeTextureCache() -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)

        return cache
    }

    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    static func depth_cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }

    static func depth_makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(depth_cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
}
