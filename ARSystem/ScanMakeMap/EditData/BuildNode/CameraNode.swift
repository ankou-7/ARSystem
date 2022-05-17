//
//  CameraNode.swift
//  ARSystem
//
//  Created by yasue kouki on 2022/05/18.
//

import SceneKit

class CameraNode: SCNNode {
    
    override init() {
        super.init()
        
        //カメラ設定
        let sphereCamera:SCNGeometry = SCNSphere(radius: 0.01)
        //sphereCamera.firstMaterial?.diffuse.contents = UIColor.green
        let cameraNode = SCNNode(geometry: sphereCamera)
        cameraNode.camera = SCNCamera()
        cameraNode.opacity = 0
        cameraNode.camera?.zNear = 0.0
        
        addChildNode(cameraNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

