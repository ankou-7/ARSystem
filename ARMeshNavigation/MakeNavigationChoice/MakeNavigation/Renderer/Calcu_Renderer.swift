//
//  Calcu_Renderer.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/12/13.
//

import Metal
import MetalKit
import ARKit
import SwiftUI

final class Calcu_Renderer {
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
    private lazy var particlePipelineState = makeParticlePipelineState()!

    private lazy var textureCache = makeTextureCache()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private var depthTexture: CVMetalTexture?
    private var confidenceTexture: CVMetalTexture?

    private let inFlightSemaphore: DispatchSemaphore
    private var currentBufferIndex = 0

    private var viewportSize = CGSize()

//    // Particles buffer
//    private var particlesBuffer: MetalBuffer<ParticleUniforms>
    private var currentPointIndex = 0
    private var currentPointCount = 0
    
//    private var particlesDepthBuffer: MetalBuffer<DepthUniforms>

    // Camera data
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height))
    private lazy var viewToCamera = sampleFrame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
    private lazy var lastCameraTransform = sampleFrame.camera.transform

    var confidenceThreshold = 2

    private var anchorUniformsBuffer: MetalBuffer<realAnchorUniforms>

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
        
        anchorUniformsBuffer = .init(device: device, count: 1, index: 2)

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
    
    private func update(frame: ARFrame, anchor: ARMeshAnchor) {
        // frame dependent info
        let camera = frame.camera
        //let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        //let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
      
        anchorUniformsBuffer[0].viewProjectionMatrix = projectionMatrix * viewMatrix
        
        anchorUniformsBuffer[0].transform = anchor.transform
    }

    func drawMesh(anchor: ARMeshAnchor) {
        print(anchor)
        guard let currentFrame = session.currentFrame,
              let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = sceneView.currentRenderCommandEncoder else {
                print("return")
                return
        }
        
        print("実行")

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
        update(frame: currentFrame, anchor: anchor)

        //取得した特徴点（色付き）
        //renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(particlePipelineState)
        renderEncoder.setVertexBuffer(anchor.geometry.vertices.buffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(anchor.geometry.faces.buffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(anchorUniformsBuffer)
        
        let tryBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.vertices.count, options: [])
        renderEncoder.setVertexBuffer(tryBuffer, offset: 0, index: 3)
        
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: anchor.geometry.vertices.count)

        commandBuffer.commit()
        
        let tryData = Data(bytesNoCopy: tryBuffer!.contents(), count: MemoryLayout<SIMD3<Float>>.stride * anchor.geometry.vertices.count, deallocator: .none)
        var trys = [SIMD3<Float>](repeating: SIMD3<Float>(0,0,0), count: anchor.geometry.vertices.count)
        trys = tryData.withUnsafeBytes {
            Array(UnsafeBufferPointer<SIMD3<Float>>(start: $0, count: tryData.count/MemoryLayout<SIMD3<Float>>.size))
        }
        print(trys[0...30])
    }
}

//// MARK: - Metal Helpers

private extension Calcu_Renderer {
    func makeParticlePipelineState() -> MTLRenderPipelineState? {
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
