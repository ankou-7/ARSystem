//
//  Renderer.swift
//  ARMeshNavigation
//
//  Created by 安江洸希 on 2021/01/29.
//

import Metal
import MetalKit
import ARKit

struct Vertex {
    var position: vector_float4
    //var color: vector_float4
    
    init(position: vector_float4){//}, color: vector_float4) {
        self.position = position
        //self.color = color
    }
}
struct Color {
    var color: vector_float4
    
    init(color: vector_float4){
        self.color = color
    }
}
struct Vertex2 {
    var position: vector_float4
    var color: vector_float4
    
    init(position: vector_float4, color: vector_float4) {
        self.position = position
        self.color = color
    }
}

struct PointCloudVertex:Codable {
    var x: Float, y: Float, z: Float
    var r: Float, g: Float, b: Float
}

final class Renderer {
    // Maximum number of points we store in the point cloud
    //private let maxPoints = 10000//10_000_000 //2500_000 //500000
    var maxPoints = 10_000_000 {
        didSet {
            pointCloudUniforms.maxPoints = Int32(maxPoints)
        }
    }
    // Number of sample points on the grid
    var numGridPoints = 1000 {
        didSet {
            pointCloudUniforms.numGridPoints = Int32(numGridPoints)
        }
    }
    //private let numGridPoints = 1000//0//3500//10000//50
    
    // Particle's size in pixels
    //private let particleSize: Float = 10//30
    
    // We only use landscape orientation in this app
    //画面の向きを設定
    private let orientation = UIInterfaceOrientation.portrait//.landscapeRight
    // Camera's threshold values for detecting when the camera moves so that we can accumulate the points
    private let cameraRotationThreshold = cos(2 * .degreesToRadian)
    private let cameraTranslationThreshold: Float = pow(0.02, 2)   // (meter-squared)
    // The max number of command buffers in flight
    private let maxInFlightBuffers = 3
    
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    private let session: ARSession
    
    // Metal objects and textures
    private let device: MTLDevice
    private let library: MTLLibrary
    //private let renderDestination: RenderDestinationProvider
    private let sceneView: ARSCNView
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
//    private lazy var rgbPipelineState = makeRGBPipelineState()!
    private lazy var particlePipelineState = makeParticlePipelineState()!
    
    private lazy var loadmodelPipelineState = makeloadmodelPipelineState()! //追加
    // texture cache for captured image
    private lazy var textureCache = makeTextureCache()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private var depthTexture: CVMetalTexture?
    private var confidenceTexture: CVMetalTexture?
    
    // Multi-buffer rendering pipeline
    private let inFlightSemaphore: DispatchSemaphore
    private var currentBufferIndex = 0
    
    // The current viewport size
    private var viewportSize = CGSize()
    // The grid of sample points
    private lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                                            array: makeGridPoints(),
                                                            index: kGridPoints.rawValue, options: [])
    
//    // RGB buffer
//    private lazy var rgbUniforms: RGBUniforms = {
//        var uniforms = RGBUniforms()
//        uniforms.radius = rgbRadius
//        uniforms.viewToCamera.copy(from: viewToCamera)
//        uniforms.viewRatio = Float(viewportSize.width / viewportSize.height)
//        return uniforms
//    }()
//    private var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
    
    // Point Cloud buffer
    private lazy var pointCloudUniforms: PointCloudUniforms = {
        var uniforms = PointCloudUniforms()
        uniforms.maxPoints = Int32(maxPoints)
        uniforms.confidenceThreshold = Int32(confidenceThreshold)
        uniforms.particleSize = particleSize
        uniforms.cameraResolution = cameraResolution
        
        uniforms.pan_move = Float2(pan_move)
        uniforms.rotate = rotate
        uniforms.scale = scale
        return uniforms
    }()
    private var pointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()
    
//    //move buffer
//    private lazy var moveUniforms: MoveUniforms = {
//        var uniforms = MoveUniforms()
//        uniforms.move_y = Float(rotation)
//        return uniforms
//    }()
//    private var moveUniformsBuffers = [MetalBuffer<MoveUniforms>]()
    
    // Particles buffer
    private var particlesBuffer: MetalBuffer<ParticleUniforms>
    private var currentPointIndex = 0
    private var currentPointCount = 0
    
    //depthデータ取得用
    private var depth_particlesBuffer: MetalBuffer<ParticleUniforms>
    
    // Camera data
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height))
    private lazy var viewToCamera = sampleFrame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
    private lazy var lastCameraTransform = sampleFrame.camera.transform
    //private lazy var lastCameraTransform: simd_float4x4 = matrix_identity_float4x4
    
    // interfaces
    
    var confidenceThreshold = 2 {
        didSet {
            // apply the change for the shader
            pointCloudUniforms.confidenceThreshold = Int32(confidenceThreshold)
        }
    }
    
    var pan_move: Float2 = [0,0] {
        didSet {
            pointCloudUniforms.pan_move = Float2(pan_move)
        }
    }
    
    var rotate: matrix_float4x4 = simd_float4x4(columns: (simd_float4(1,0,0,0),
                                                          simd_float4(0,1,0,0),
                                                          simd_float4(0,0,1,0),
                                                          simd_float4(0,0,0,1))) {
        didSet {
            pointCloudUniforms.rotate = rotate
        }
    }
    
    var scale: Float = 1 {
        didSet {
            pointCloudUniforms.scale = Float(scale)
        }
    }
    
    var particleSize: Float = 10.0 {
        didSet {
            pointCloudUniforms.particleSize = particleSize
        }
    }
    
    //追加
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
            pointCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
//            moveUniformsBuffers.append(.init(device: device, count: 1, index: kmoveUniforms.rawValue))
        }
        particlesBuffer = .init(device: device, count: maxPoints, index: kParticleUniforms.rawValue)
        depth_particlesBuffer = .init(device: device, count: 1440*1920, index: kDepthUniforms.rawValue)
        
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
        print("draw")
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
        pointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms
        
        if shouldAccumulate(frame: currentFrame), updateDepthTextures(frame: currentFrame) {
            accumulatePoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        }
        
        
        //カメラから取得した画像（ARWorldTrackingを使っているから通常のカメラ画像を使用していない）
        // check and render rgb camera image
//        if rgbUniforms.radius > 0 {
//            var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr]
//            commandBuffer.addCompletedHandler { buffer in
//                retainingTextures.removeAll()
//            }
//            rgbUniformsBuffers[currentBufferIndex][0] = rgbUniforms
//
//            renderEncoder.setDepthStencilState(relaxedStencilState)
//            renderEncoder.setRenderPipelineState(rgbPipelineState)
//            renderEncoder.setVertexBuffer(rgbUniformsBuffers[currentBufferIndex])
//            renderEncoder.setFragmentBuffer(rgbUniformsBuffers[currentBufferIndex])
//            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
//            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
//            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
//        }
       
        //取得した特徴点（色付き）
        // render particles
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setRenderPipelineState(particlePipelineState)
        renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentPointCount)
        //renderEncoder.endEncoding()
            
        //commandBuffer.present(renderDestination.currentDrawable!)
        commandBuffer.commit()
    }
    
    //追加
    
    func load(filename: String) -> Bool {
        //プロジェクト内にあるtxtパス取得
//        guard let fileURL = Bundle.main.url(forResource: "art.scnassets/t2", withExtension: "txt")  else {
//            fatalError("ファイルが見つからない")
//        }
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last{
            let fileURL = documentDirectory.appendingPathComponent("\(filename).txt")
            guard let fileContents = try? String(contentsOf: fileURL) else {
                fatalError("ファイル読み込みエラー")
            }
            let row = fileContents.components(separatedBy: "\n")
            print(row.count)
            count = row.count
            for s in row {
                let values = s.components(separatedBy: " ")
                if (Float(values[0]) == nil || Float(values[1]) == nil || Float(values[2]) == nil){
                    break
                } else {
                    let position: vector_float4! = [Float(values[0])!,  Float(values[1])!,  Float(values[2])!,  1.0]
                
                    let color: vector_float4! = [Float(values[3])!/255,  Float(values[4])!/255,  Float(values[5])!/255,  1.0]
                    //let vertex: Vertex = Vertex(position: position)//, color: color)
                    vertexData.append(Vertex(position: position))
                    colorData.append(Color(color: color))
                }
            }
            
            let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
            
            let dataSize2 = colorData.count * MemoryLayout.size(ofValue: colorData[0])
            colorBuffer = device.makeBuffer(bytes: colorData, length: dataSize2, options: [])
            
            print("読み込み準備完了")
            
        }
        return true
    }
    
    func draw2() {
        //load()
        
        guard let currentFrame = session.currentFrame,
              let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderCommandEncoder = sceneView.currentRenderCommandEncoder else {
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
        
        currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
        pointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms
        
        if shouldAccumulate(frame: currentFrame), updateDepthTextures(frame: currentFrame) {
            accumulatePoints(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderCommandEncoder)
        }

        renderCommandEncoder.setDepthStencilState(depthStencilState)
        renderCommandEncoder.setRenderPipelineState(loadmodelPipelineState)
        renderCommandEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        //renderCommandEncoder.setVertexBuffer(renderParams, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
        renderCommandEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 2)
        //renderCommandEncoder.setVertexBuffer(moveUniformsBuffers[currentBufferIndex])
        //.setVertexBuffer(moveUniformsBuffers)
        //renderCommandEncoder.setFragmentTexture(texture, atIndex: 0)
        renderCommandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: count)

        //renderCommandEncoder?.endEncoding()
        //commandBuffer.presentDrawable(drawable)
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
        renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.setVertexBuffer(gridPointsBuffer)
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)
        
        currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % maxPoints
        currentPointCount = min(currentPointCount + gridPointsBuffer.count, maxPoints)
      
        lastCameraTransform = frame.camera.transform
    }
    
    func send_Data(num: Int) -> (Int, Data) {
        var data_array: [PointCloudVertex] = []
        for i in num..<currentPointCount {
            let point = particlesBuffer[i]
            let colors = point.color
            data_array.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: colors.x, g: colors.y, b: colors.z))
        }
        let points_data = try! JSONEncoder().encode(data_array)
        return (currentPointCount, points_data)
    }
    
    func send_Data_String(num: Int) -> (Int, String) {
        var data_String = ""
        for i in num..<currentPointCount {
            let point = particlesBuffer[i]
            let colors = point.color
            //data_array.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: colors.x, g: colors.y, b: colors.z))
            if point.position.x == 0.0 || point.position.y == 0.0 || point.position.z == 0.0 || colors.x == 0.0 || colors.y == 0.0 || colors.z == 0.0 {
                continue
            }
            data_String += "\(point.position.x):\(point.position.y):\(point.position.z):\(colors.x):\(colors.y):\(colors.z):"
        }
        return (currentPointCount, data_String)
    }
    
    func savePointsToFile(failname: String) {
      guard !self.isSavingFile else { return }
      self.isSavingFile = true
        
        // 1
        var fileToWrite = ""
//        let headers = ["ply", "format ascii 1.0", "element vertex \(currentPointCount)", "property float x", "property float y", "property float z", "property uchar red", "property uchar green", "property uchar blue", "property uchar alpha", "element face 0", "property list uchar int vertex_indices", "end_header"]
//        for header in headers {
//            fileToWrite += header
//            fileToWrite += "\r\n"
//        }
        
        // 2
        for i in 0..<currentPointCount {
        
            // 3
            let point = particlesBuffer[i]
            let colors = point.color
            
//            // 4
//            let red = colors.x * 255.0
//            let green = colors.y * 255.0
//            let blue = colors.z * 255.0
//
//            // 5
//            let pvValue = "\(point.position.x) \(point.position.y) \(point.position.z) \(Int(red)) \(Int(green)) \(Int(blue)) 255"
//            fileToWrite += pvValue
//            fileToWrite += "\r\n"
            
            vertice_data.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: colors.x, g: colors.y, b: colors.z))
        }
        
        fileToWrite += String(currentPointCount)
        
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            let targetDataFilePath = documentDirectoryFileURL.appendingPathComponent("\(failname).data")
            let targetTextFilePath = documentDirectoryFileURL.appendingPathComponent("\(failname).txt")
            
            
            //let vertexData = NSData(bytes: vertice_data, length: MemoryLayout<PointCloudVertex>.size * vertice_data.count)
            
            //let vertexData = Data(bytes: vertice_data, count: MemoryLayout<PointCloudVertex>.size * vertice_data.count)
            
            let vertexData = try! JSONEncoder().encode(vertice_data)
            
            do {
                try vertexData.write(to: targetDataFilePath)
                try fileToWrite.write(to: targetTextFilePath, atomically: true, encoding: String.Encoding.ascii)
            } catch {
                print("Failed to write PLY file", error)
            }
            print("保存完了")
        }
        
//        // 6
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        let documentsDirectory = paths[0]
//        //let file = documentsDirectory.appendingPathComponent("ply_\(UUID().uuidString).ply")
//        let file = documentsDirectory.appendingPathComponent("\(failname).txt")
//
//        //let targetTextFilePath = documentsDirectory.appendingPathComponent("try3.scn") //mesh
//
//        do {
//
//            // 7
//            try fileToWrite.write(to: file, atomically: true, encoding: String.Encoding.ascii)
//            //self.sceneView.scene.write(to: targetTextFilePath, options: nil, delegate: nil, progressHandler: nil)
//
//
//            self.isSavingFile = false
//        } catch {
//            print("Failed to write PLY file", error)
//        }
    }
    
    func realtime_vertice(pre_count: Int) -> (Int, [PointCloudVertex]) {
        var points: [PointCloudVertex] = []
        for i in 0..<currentPointCount {
            let point = particlesBuffer[i]
            let colors = point.color
            points.append(PointCloudVertex(x: point.position.x, y: point.position.y, z: point.position.z, r: colors.x, g: colors.y, b: colors.z))
        }
        print(points.count)
        return (currentPointCount, points)
    }
    
}

// MARK: - Metal Helpers

private extension Renderer {
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
    
//    func makeRGBPipelineState() -> MTLRenderPipelineState? {
//        guard let vertexFunction = library.makeFunction(name: "rgbVertex"),
//            let fragmentFunction = library.makeFunction(name: "rgbFragment") else {
//                return nil
//        }
//
//        let descriptor = MTLRenderPipelineDescriptor()
//        descriptor.vertexFunction = vertexFunction
//        descriptor.fragmentFunction = fragmentFunction
//        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
//        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
//        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
//        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
//
//        return try? device.makeRenderPipelineState(descriptor: descriptor)
//    }
    
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
    
    //追加
    func makeloadmodelPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "vertex_func"),
            let fragmentFunction = library.makeFunction(name: "fragment_func") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        //descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm//sceneView.colorPixelFormat
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
        let spacing = sqrt(gridArea / Float(numGridPoints))
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
        //print(points)
        
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
        let status = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                               textureCache,
                                                               pixelBuffer,
                                                               nil,
                                                               pixelFormat,
                                                               width,
                                                               height,
                                                               planeIndex,
                                                               &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }
    
    static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
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
    
    static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
}
