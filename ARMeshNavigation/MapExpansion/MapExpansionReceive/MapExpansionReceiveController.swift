//
//  MapExpansionReceiveController.swift
//  ARMeshNavigation
//
//  Created by yasue kouki on 2021/04/19.
//

import UIKit
import SceneKit
import ARKit
import RealmSwift
import MultipeerConnectivity

class MapExpansionReceiveController: UIViewController, ARSCNViewDelegate,  MCBrowserViewControllerDelegate, MCSessionDelegate {

    @IBOutlet weak var sceneView: SCNView!
    let scene = SCNScene()
    
    @IBOutlet weak var browser_button: UIButton!
    @IBOutlet weak var connectInfo_label: UILabel!
    @IBOutlet weak var stop_button: UIButton!
    
    @IBOutlet weak var move_cameraButton: UIButton!
    @IBOutlet weak var move_objectButton: UIButton!
    @IBOutlet weak var move_info_label: UILabel!
    
    let serviceType = "ar-collab"
    @objc var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    
    @IBOutlet var PanGesture: UIPanGestureRecognizer!
    @IBOutlet var TapGesture: UITapGestureRecognizer!
    @IBOutlet var LongPressGesture: UILongPressGestureRecognizer!
    
    var knownAnchors = Dictionary<UUID, SCNNode>()
    var anchor_array: [UUID] = []
    var identifier: UUID!
    var mesh_count = -1
    
    var cameraNode = SCNNode()
    
    var vertex_data: NSData!
    var vertex_count: Int!
    
    var mesh_array: [PointCloudVertex] = []
    var face_array: [Int32] = []
    var points_array: [PointCloudVertex] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self //delegateのセット
        sceneView.scene = scene
        
        sceneView.allowsCameraControl = true //カメラ位置をタップでコントロール可能にする
        //sceneView.showsStatistics = true
        
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        //sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.0
        cameraNode.opacity = 0 //透明化
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1.5)
//        print(cameraNode.simdWorldPosition)
//        print(cameraNode.simdEulerAngles)
        scene.rootNode.addChildNode(cameraNode)
        
        move_objectButton.isHidden = true
        PanGesture.isEnabled = false
        TapGesture.isEnabled = false
        LongPressGesture.isEnabled = false
        
        //座標軸
        let axis = ObjectOriginAxis(sceneView: sceneView)//.makeAxisNode()
        scene.rootNode.addChildNode(axis)
        
        self.stop_button.isHidden = true
        
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self

        // create the browser viewcontroller with a unique service name
        self.browser = MCBrowserViewController(serviceType:serviceType,
                                               session:self.session)
        self.browser.delegate = self;
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType,
                                               discoveryInfo:nil, session:self.session)
        self.assistant.start()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    @IBAction func move_cameraButton(_ sender: UIButton) {
        move_cameraButton.isHidden = true
        move_objectButton.isHidden = false
        sceneView.allowsCameraControl = false
        move_info_label.text = "オブジェクト移動"
        PanGesture.isEnabled = true
        TapGesture.isEnabled = true
        LongPressGesture.isEnabled = true
    }
    
    @IBAction func move_objectButton(_ sender: UIButton) {
        move_cameraButton.isHidden = false
        move_objectButton.isHidden = true
        sceneView.allowsCameraControl = true
        move_info_label.text = "カメラ移動"
        PanGesture.isEnabled = false
        TapGesture.isEnabled = false
        LongPressGesture.isEnabled = false
    }
    
    
    @IBAction func didTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            tap_flash(screenPos: sender.location(in: sceneView))
        }
    }
    
    private var flashTimer: Timer?
    private var flashDuration = 0.1
    
    func tap_flash(screenPos: CGPoint) {
        let hitResults = sceneView.hitTest(screenPos, options: [:])
        for result in hitResults {
            if result.node.parent?.name! == "axis" {
                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                
                //0.1秒間悪を開けて元の色に戻す
                self.flashTimer?.invalidate()
                self.flashTimer = Timer.scheduledTimer(withTimeInterval: flashDuration, repeats: false) { _ in
                    if result.node.name! == "XAxis" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                    }
                    else if result.node.name! == "YAxis" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
                    }
                    else if result.node.name! == "ZAxis" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
                    }
                    else if result.node.name! == "XCurve" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                    }
                    else if result.node.name! == "YCurve" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
                    }
                    else if result.node.name! == "ZCurve" {
                        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
                    }
                }
            }
        }
    }
    
    @IBAction func didLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .possible:
            break
        case .began:
            startAxisDrag(screenPos: sender.location(in: sceneView))
        case .changed:
            updateAxisDrag(screenPos: sender.location(in: sceneView))
        case .failed, .cancelled, .ended:
            endAxisDrag(screenPos: sender.location(in: sceneView))
        @unknown default:
            break
        }
    }
    
    
    @IBAction func didOneFingerPan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .possible:
            break
        case .began:
            startAxisDrag(screenPos: sender.location(in: sceneView))
        case .changed:
            updateAxisDrag(screenPos: sender.location(in: sceneView))
        case .failed, .cancelled, .ended:
            endAxisDrag(screenPos: sender.location(in: sceneView))
        @unknown default:
            break
        }
    }
    
    
    @IBAction func tap(_ sender: Any) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "axis", recursively: false) {
            print(node.position)
            let origin_posi = sceneView.projectPoint(node.position)
            print(origin_posi)
            
            //print(node.simdTransform)
            //node.childNode(withName: "XAxis", recursively: false)?.localTranslate(by: SCNVector3(x: 0.1, y: 0, z: 0))
            //node.childNode(withName: "YAxis", recursively: false)?.localTranslate(by: SCNVector3(x: 0.1, y: 0, z: 0))
            //node.childNode(withName: "ZAxis", recursively: false)?.localTranslate(by: SCNVector3(x: 0.1, y: 0, z: 0))
            //nodeのラーカル座標を基準に移動
            //node.localTranslate(by: SCNVector3(x: 0.1, y: 0, z: 0))
            //node.simdLocalTranslate(by: simd_float3(x: 0.1, y: 0, z: 0))
        }
    }
    
    @IBAction func rotate(_ sender: UIButton) {
        if let node = self.sceneView.scene!.rootNode.childNode(withName: "axis", recursively: false) {
            node.localRotate(by: SCNQuaternion(0, 0.1, 0, Float.pi/2))
        }
    }
    
    var origin_posi = CGPoint(x: 0, y: 0)
    var distance: Float = 0.0
    var pre_screenPos = CGPoint(x: 0, y: 0)
    var select_node: SCNNode!
    var start_flag = false
    
    func startAxisDrag(screenPos: CGPoint) {
        let hitResults = sceneView.hitTest(screenPos, options: [:])
        for result in hitResults {
            
            if result.node.parent?.name! == "axis" {
                let posi = sceneView.projectPoint(result.node.parent!.position)
                origin_posi = CGPoint(x: CGFloat(posi.x), y: CGFloat(posi.y))
                distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
                pre_screenPos = screenPos
                select_node = result.node
                start_flag = true
                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            }
        }
    }
    
    func updateAxisDrag(screenPos: CGPoint) {
        //print(screenPos)
        if start_flag == true {
            let posi = sceneView.projectPoint(select_node.parent!.position)
            //print(posi)
            let now_distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
            let diff = now_distance - distance
            let translation = screenPos.y - pre_screenPos.y
            if select_node.name == "XAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: diff * 0.001, y: 0, z: 0))
            }
            else if select_node.name == "YAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.001, z: 0))
            }
            else if select_node.name == "ZAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.001))
            }
            else if select_node.name == "XCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
            }
            else if select_node.name == "YCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
            }
            else if select_node.name == "ZCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
            }
            let now_posi = sceneView.projectPoint(select_node.parent!.position)
            origin_posi = CGPoint(x: CGFloat(now_posi.x), y: CGFloat(now_posi.y))
            distance = sqrt((now_posi.x - Float(screenPos.x)) * (now_posi.x - Float(screenPos.x)) + (now_posi.y - Float(screenPos.y)) * (now_posi.y - Float(screenPos.y)))
            pre_screenPos = screenPos
        }
    }
    
    //PanGestureで指を離したときに元の色に戻す
    func endAxisDrag(screenPos: CGPoint) {
        if start_flag == true {
            start_flag = false
//            select_node.childNode(withName: "XAxis", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = UIColor.red
//            select_node.childNode(withName: "YAxis", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = UIColor.green
//            select_node.childNode(withName: "ZAxis", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            if select_node.name == "XAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZAxis" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
            else if select_node.name == "XCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
            }
            else if select_node.name == "YCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
            else if select_node.name == "ZCurve" {
                select_node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            }
        }
    }
    
    //タッチしたとき
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        //print("touches began")
//        let touch = touches.first!
//        let location = touch.location(in: sceneView)
//        print(location)
//
//        let hitResults = sceneView.hitTest(location, options: [:])
//        print(hitResults)
//        for result in hitResults {
//            print(result.node.parent?.name)
//            print(result.node.name)
//            if result.node.parent?.name! == "axis" {
//                //result.node.geometry?.materials.first?.emission.contents = UIColor.white
//                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
//            }
//        }
//
//        guard let camera = sceneView.pointOfView else {
//            return
//        }
//        print(camera.simdWorldPosition)
//        print(camera.simdEulerAngles)
//    }
//    //タッチを動かしたとき
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        //print("touches moved")
////        let touch = touches.first!
////        let location = touch.location(in: sceneView)
////        print(location)
//    }
//    //タッチが終わったとき
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        print("touches ended")
//        let touch = touches.first!
//        let location = touch.location(in: sceneView)
//
//        let hitResults = sceneView.hitTest(location, options: [:])
//        for result in hitResults {
//            if result.node.name! == "XAxis" {
//                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
//            }
//            else if result.node.name! == "YAxis" {
//                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
//            }
//            else if result.node.name! == "ZAxis" {
//                result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
//            }
//        }
//    }
    
    
    @IBAction func showBrowser(_ sender: UIButton) {
        self.present(self.browser, animated: true, completion: nil)
    }
    
    @IBAction func stop_button(_ sender: UIButton) {
        self.session.disconnect()
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //dataを受信した際に呼び出し
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        DispatchQueue.main.async { [self] in
            do {
                //メッシュ受信
                if let meshAnchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARMeshAnchor.self, from: data) {
                    print("meshAnchor受信")
                    let geometry = meshAnchor.geometry
                    let vertices = geometry.vertices
                    let faces = geometry.faces
                    print("頂点数：\(vertices.count)")
                    print("面数：\(faces.count)")
                    //print(faces.bytesPerIndex) //4
                    
                    let index = anchor_array.firstIndex(of: meshAnchor.identifier)
                    if index != nil {
                        if let node = self.sceneView.scene!.rootNode.childNode(withName: "\(index)", recursively: false) {
                            node.removeFromParentNode()
                        }
                        
                        for i in 0..<vertices.count {
                            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * i))
                            let vertex = vertexPointer.assumingMemoryBound(to: (simd_float3).self).pointee
                            mesh_array.append(PointCloudVertex(x: vertex.x, y: vertex.y, z: vertex.z, r: 0, g:255, b: 0))
                        }
                        //print(mesh_array)
                        //print(mesh_array.count)
                        
                        for index in 0..<faces.count {
                            let indicesPerFace = faces.indexCountPerPrimitive
                            for offset in 0..<indicesPerFace {
                                let vertexIndexAddress = faces.buffer.contents().advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                                face_array.append(Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
                            }
                        }
                        //print(face_array)
                        //print(face_array.count)
                        
                        let node = self.build_meshNode(points: self.mesh_array, faces: self.face_array)
                        node.simdTransform = meshAnchor.transform
                        node.name = "\(index)"
                        self.scene.rootNode.addChildNode(node)
                        self.mesh_array = []
                        self.face_array = []
                    }
                    else if index == nil {
                        anchor_array.append(meshAnchor.identifier)
                        mesh_count += 1
                        
                        for i in 0..<vertices.count {
                            let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * i))
                            let vertex = vertexPointer.assumingMemoryBound(to: (simd_float3).self).pointee
                            mesh_array.append(PointCloudVertex(x: vertex.x, y: vertex.y, z: vertex.z, r: 0, g:255, b: 0))
                        }
                        //print(mesh_array)
                        //print(mesh_array.count)
                        
                        for index in 0..<faces.count {
                            let indicesPerFace = faces.indexCountPerPrimitive
                            for offset in 0..<indicesPerFace {
                                let vertexIndexAddress = faces.buffer.contents().advanced(by: (index * indicesPerFace + offset) * MemoryLayout<UInt32>.size)
                                //vertexIndices.append(Int(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
                                face_array.append(Int32(vertexIndexAddress.assumingMemoryBound(to: UInt32.self).pointee))
                            }
                            //face_array.append(vertexIndices)
                        }
                        //print(face_array)
                        //print(face_array.count)
                        
                        let node = self.build_meshNode(points: self.mesh_array, faces: self.face_array)
                        node.simdTransform = meshAnchor.transform
                        node.name = "\(mesh_count)"
                        self.scene.rootNode.addChildNode(node)
                        self.mesh_array = []
                        self.face_array = []
                    }
                }
    
                
                //点群受信
//                if let str = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
//                    if let node = self.sceneView.scene!.rootNode.childNode(withName: "points", recursively: false) {
//                        node.removeFromParentNode()
//                    }
//                    print("point受信")
//                    let all_str = str as String
//                    let str_array = all_str.components(separatedBy: "point")
//                    for (i,s) in str_array.enumerated() {
//                        if i == 0 {
//                            continue
//                        }
//                        let a = s.components(separatedBy: ":")
//                        if (Float(a[1]) == nil) || (Float(a[2]) == nil) || (Float(a[3]) == nil) || (Float(a[4]) == nil) || (Float(a[5]) == nil) || (Float(a[6]) == nil) {
//                            continue
//                        }
//                        points_array.append(PointCloudVertex(x: Float(a[1])!, y: Float(a[2])!, z: Float(a[3])!, r: Float(a[4])!, g: Float(a[5])!, b: Float(a[6])!))
//                    }
//                    let node = self.build_pointsNode(points: self.points_array)
//                    node.name = "points"
//                    node.position = SCNVector3(x: 0, y: 0, z: 0)
//                    self.scene.rootNode.addChildNode(node)
//                }
                
                
//                if let data = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSData.self, from: data) {
//                    print("point受信")
//                    if let node = self.sceneView.scene!.rootNode.childNode(withName: "points", recursively: false) {
//                        node.removeFromParentNode()
//                    }
//                    let decoder = JSONDecoder()
//                    guard let points = try? decoder.decode([PointCloudVertex].self, from: data as Data) else {
//                        fatalError("JSON読み込みエラー")
//                    }
//                    points_array.append(contentsOf: points)
//                    let node = self.build_pointsNode(points: points_array)
//                    node.name = "points"
//                    node.position = SCNVector3(x: 0, y: 0, z: 0)
//                    self.scene.rootNode.addChildNode(node)
//                }
                
                if let data = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSData.self, from: data) {
                    guard let uncompressedNSData: Data = try? data.decompressed(using: .zlib) as Data else {
                        fatalError("Fail to Decompress Data")
                    }
                    guard let string = String(data: uncompressedNSData, encoding: .utf8) else {
                        fatalError("Fail to Encoading Data")
                    }
                    if let node = self.sceneView.scene!.rootNode.childNode(withName: "points", recursively: false) {
                        node.removeFromParentNode()
                    }
                    print("point受信")
                    var str_array = string.components(separatedBy: ":")
                    str_array.removeLast()
                    print(str_array.count)
                    print(str_array.count / 6)
                    //print(str_array)
                    for i in 0..<str_array.count/6 {
                        if (Float(str_array[0 + i*6]) == nil) || (Float(str_array[1 + i*6]) == nil) || (Float(str_array[2 + i*6]) == nil) || (Float(str_array[3 + i*6]) == nil) || (Float(str_array[4 + i*6]) == nil) || (Float(str_array[5 + i*6]) == nil) {
                            continue
                        }
                        points_array.append(PointCloudVertex(x: Float(str_array[0 + i*6])!, y: Float(str_array[1 + i*6])!, z: Float(str_array[2 + i*6])!, r: Float(str_array[3 + i*6])!, g: Float(str_array[4 + i*6])!, b: Float(str_array[5 + i*6])!))
                    }
                    let node = self.build_pointsNode(points: self.points_array)
                    node.name = "points"
                    node.position = SCNVector3(x: 0, y: 0, z: 0)
                    self.scene.rootNode.addChildNode(node)
                }
                
            } catch {
                print("can't decode data recieved from \(peerID.displayName)")
            }
        }
    }
    
    private func build_meshNode(points: [PointCloudVertex], faces: [Int32]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        
        let faceData = NSData(
            bytes: faces,
            length: 4 * faces.count
        )
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        
        let element = SCNGeometryElement(
            data: faceData as Data,
            primitiveType: .triangles,
            primitiveCount: faces.count/3,
            bytesPerIndex: 4
        )

        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = UIColor.green //UIColor(displayP3Red:1, green:1, blue:1, alpha:0.7)
        pointsGeometry.materials = [defaultMaterial]
        
        return SCNNode(geometry: pointsGeometry)
    }
    
    private func build_pointsNode(points: [PointCloudVertex]) -> SCNNode {
        let vertexData = NSData(
            bytes: points,
            length: MemoryLayout<PointCloudVertex>.size * points.count
        )
        
        let positionSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.vertex,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let colorSource = SCNGeometrySource(
            data: vertexData as Data,
            semantic: SCNGeometrySource.Semantic.color,
            vectorCount: points.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: MemoryLayout<Float>.size * 3,
            dataStride: MemoryLayout<PointCloudVertex>.size
        )
        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: points.count,
            bytesPerIndex: MemoryLayout<Int>.size
        )
        // for bigger dots
        element.pointSize = 1
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 7

        let pointsGeometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        
        return SCNNode(geometry: pointsGeometry)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        //code
        DispatchQueue.main.async() { [self] in
            switch state {
                case MCSessionState.connected: //接続中
                    print("Connected: \(peerID.displayName)")
                    self.connectInfo_label.text = "Connecting: \(peerID.displayName)"
                    browser_button.isHidden = true
                    stop_button.isHidden = false
                case MCSessionState.connecting: //接続開始時
                    print("Connecting: \(peerID.displayName)")
                    self.connectInfo_label.text = "Connecting: \(peerID.displayName)"
                case MCSessionState.notConnected: //接続中断
                    print("Not Connected: \(peerID.displayName)")
                    self.connectInfo_label.text = "Not Connect"
                    browser_button.isHidden = false
                    stop_button.isHidden = true
                @unknown default:
                    self.connectInfo_label.text = "Not Connect"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        //code
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        //code
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        //code
    }
    
    @IBAction func back(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
}
