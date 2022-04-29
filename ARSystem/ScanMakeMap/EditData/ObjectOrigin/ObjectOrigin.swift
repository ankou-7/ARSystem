//
//  ObjectOrigin.swift
//  ARMesh
//
//  Created by yasue kouki on 2021/10/22.
//

import SceneKit
import RealmSwift

class ObjectOrigin: SCNNode {
    
    private var origin_posi = CGPoint(x: 0, y: 0)
    private var distance: Float = 0.0
    private var pre_screenPos = CGPoint(x: 0, y: 0)
    private var select_node: SCNNode!
    private var start_flag = false
    
    private var sceneView: SCNView
    var choiceNode_name: String
    var posi: SCNVector3
    var euler: SCNVector3
    
    init(sceneView: SCNView, choiceNode_name: String, posi: SCNVector3, euler: SCNVector3) {
        self.sceneView = sceneView
        self.choiceNode_name = choiceNode_name
        self.posi = posi
        self.euler = euler
        super.init()
        
        if let node = sceneView.scene?.rootNode.childNode(withName: "axis", recursively: false) {
            node.removeFromParentNode()
        }
        
        let axis = ObjectOriginAxis(sceneView: sceneView)
        axis.position = posi
        axis.scale = SCNVector3(2.0, 2.0, 2.0)
        axis.eulerAngles = euler
        axis.name = "axis"
        sceneView.scene?.rootNode.addChildNode(axis)
        
    }
    
    func startAxisDrag(result: SCNHitTestResult, screenPos: CGPoint) {
        let posi = sceneView.projectPoint(result.node.parent!.position)
        origin_posi = CGPoint(x: CGFloat(posi.x), y: CGFloat(posi.y))
        distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
        pre_screenPos = screenPos
        select_node = result.node
        start_flag = true
        result.node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
    }
    
    func updateAxisDrag(screenPos: CGPoint, completionHandler: @escaping (SCNNode) -> ()) {
        if start_flag == true {
            let posi = sceneView.projectPoint(select_node.parent!.position)
            let now_distance = sqrt((posi.x - Float(screenPos.x)) * (posi.x - Float(screenPos.x)) + (posi.y - Float(screenPos.y)) * (posi.y - Float(screenPos.y)))
            let diff = now_distance - distance
            let translation = screenPos.y - pre_screenPos.y
            if select_node.name == "XAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: diff * 0.003, y: 0, z: 0))
            }
            else if select_node.name == "YAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: diff * 0.003, z: 0))
            }
            else if select_node.name == "ZAxis" {
                select_node.parent!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localTranslate(by: SCNVector3(x: 0, y: 0, z: diff * 0.003))
            }
            else if select_node.name == "XCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(translation * 0.005, 0, 0, 1))
            }
            else if select_node.name == "YCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, translation * 0.005, 0, 1))
            }
            else if select_node.name == "ZCurve" {
                select_node.parent!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
                sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false)!.localRotate(by: SCNQuaternion(0, 0, translation * 0.005, 1))
            }
            let now_posi = sceneView.projectPoint(select_node.parent!.position)
            origin_posi = CGPoint(x: CGFloat(now_posi.x), y: CGFloat(now_posi.y))
            distance = sqrt((now_posi.x - Float(screenPos.x)) * (now_posi.x - Float(screenPos.x)) + (now_posi.y - Float(screenPos.y)) * (now_posi.y - Float(screenPos.y)))
            pre_screenPos = screenPos
            
            
            if let node = sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                completionHandler(node)
            }
        }
    }
    
    func endAxisDrag(screenPos: CGPoint, completionHandler: @escaping (SCNNode) -> ()) {
        if start_flag == true {
            start_flag = false

            if let node = sceneView.scene?.rootNode.childNode(withName: choiceNode_name, recursively: false) {
                completionHandler(node)
            }

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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

