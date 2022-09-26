//
//  ArrowNode.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit

class ArrowNode: SCNNode {
    var sceneView: SCNView
    
    var data_array: [Data] = []
    var startPointCoord: SCNVector3!
    var endPointCoord: SCNVector3!
    let arrowNode = SCNNode()
    
    init(sceneView: SCNView) {
        self.sceneView = sceneView
        
        super.init()
        
        setup()
        makeArrowNode()
        addChildNode(arrowNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        if let node = sceneView.scene?.rootNode.childNode(withName: "startPoint", recursively: false) {
            startPointCoord = node.position
            arrowNode.addChildNode(node)
            saveNodeInfo(node: node)
        }
        if let node = sceneView.scene?.rootNode.childNode(withName: "endPoint", recursively: false) {
            endPointCoord = SCNVector3(node.position.x - startPointCoord.x, node.position.y - startPointCoord.y, node.position.z - startPointCoord.z)
            arrowNode.addChildNode(node)
            saveNodeInfo(node: node)
        }
    }
    
    func makeArrowNode() {
        let thita_xz: Float = atan(endPointCoord.z / endPointCoord.x)
        //print(thita_xz)
        
        let thita_zy: Float = atan(endPointCoord.y / endPointCoord.z)
        //print("thita_zy : \(thita_zy)")
        
        let thita_xy: Float = atan(endPointCoord.y / endPointCoord.x)
        //print("thita_xy : \(thita_xy)")
        
        var arrow_y: Float = 0
        if endPointCoord.x >= 0 {
            arrow_y = -1.57 - thita_xz
        } else if endPointCoord.x < 0 {
            arrow_y = 1.57 - thita_xz
        }
        
        var arrow_x: Float = 0
        if endPointCoord.y <= 0 && endPointCoord.z >= 0 && endPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_zy
        } else if endPointCoord.y <= 0 && endPointCoord.z < 0 && endPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_xy
        } else if endPointCoord.y <= 0 && endPointCoord.z >= 0 && endPointCoord.x < 0 {
            arrow_x = -1.57 - thita_xy
        } else if endPointCoord.y <= 0 && endPointCoord.z < 0 && endPointCoord.x < 0 {
            arrow_x = -1.57 - thita_zy
        }
        else if endPointCoord.y > 0 && endPointCoord.z >= 0 && endPointCoord.x < 0 {
            arrow_x = -1.57 - thita_xy
        } else if endPointCoord.y > 0 && endPointCoord.z < 0 && endPointCoord.x < 0 {
            arrow_x = -1.57 - thita_zy
        } else if endPointCoord.y > 0 && endPointCoord.z >= 0 && endPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_zy
        } else if endPointCoord.y > 0 && endPointCoord.z < 0 && endPointCoord.x >= 0 {
            arrow_x = -1.57 + thita_xy
        }
        
        
        let distance = sqrt(endPointCoord.x * endPointCoord.x + endPointCoord.y * endPointCoord.y + endPointCoord.z * endPointCoord.z)
        //print(distance * 100)
        let num = Int((distance * 100 ) / 10)
        let s: Float = 1/4
        
        for i in 1..<num {
            let posi = SCNVector3((startPointCoord.x + Float(i) * endPointCoord.x * s) - (endPointCoord.x * 0.1),
                                  (startPointCoord.y + Float(i) * endPointCoord.y * s) - (endPointCoord.y * 0.1),
                                  (startPointCoord.z + Float(i) * endPointCoord.z * s) - (endPointCoord.z * 0.1))
            let scene = SCNScene(named: "art.scnassets/arrow.scn")
            let node = (scene?.rootNode.childNode(withName: "arrow", recursively: false))!
            node.position = posi
            node.scale = SCNVector3(0.1, 0.1, 0.1) //SCNVector3(0.05, 0.05, 0.05)
            node.eulerAngles.y = arrow_y
            node.eulerAngles.x = arrow_x
            //node.eulerAngles.x += 1.57
            //node.eulerAngles.y -= 1.57
            node.name = "child_arrow"
            arrowNode.addChildNode(node)
            
            let now_dis = sqrt((Float(i+1) * endPointCoord.x * s) * (Float(i+1) * endPointCoord.x * s) +
                               (Float(i+1) * endPointCoord.y * s) * (Float(i+1) * endPointCoord.y * s) +
                               (Float(i+1) * endPointCoord.z * s) * (Float(i+1) * endPointCoord.z * s))
            if now_dis > distance {
                break
            }
        }
    }
    
    func saveNodeInfo(node: SCNNode) {
        let entity = ObjectInfo_data(Position: Vector3Entity(x: node.position.x,
                                                             y: node.position.y,
                                                             z: node.position.z),
                                     Scale: Vector3Entity(x: (node.scale.x),
                                                          y: (node.scale.y),
                                                          z: (node.scale.z)),
                                     EulerAngles: Vector3Entity(x: (node.eulerAngles.x),
                                                                y: (node.eulerAngles.y),
                                                                z: (node.eulerAngles.z)))
        let json_data = try! JSONEncoder().encode(entity)
        data_array.append(json_data)
    }
}
