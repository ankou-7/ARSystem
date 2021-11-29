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
    private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
    private lazy var particlePipelineState = makeParticlePipelineState()!
    
    private lazy var depthPipelineState = makeDepthPipelineState()!

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
        //commandQueue = device.makeCommandQueue()!
        commandQueue = sceneView.commandQueue!

        // initialize our buffers
        for _ in 0 ..< maxInFlightBuffers {
//            rgbUniformsBuffers.append(.init(device: device, count: 1, index: 0))
            PointCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
        }
        particlesBuffer = .init(device: device, count: Int(maxPoints), index: kParticleUniforms.rawValue)
        particlesDepthBuffer = .init(device: device, count: Int(maxPoints), index: kParticleUniforms.rawValue)

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
        print(particlesDepthBuffer.count)
        print(particlesDepthBuffer[100])
        print(particlesDepthBuffer[100].confidence)
        var depth_array: [PointCloudVertex] = []
        for i in 0..<currentPointCount {
            let point = particlesDepthBuffer[i]
            depth_array.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: 255, g: 255, b: 255))
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
