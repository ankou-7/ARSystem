//
//  LightNode.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit

class LightNode: SCNNode {
 
    override init() {
        super.init()
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient //.omni
        addChildNode(lightNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
