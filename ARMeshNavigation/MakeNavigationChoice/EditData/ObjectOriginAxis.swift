//
//  ObjectOriginAxis.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/19.
//

import SceneKit

class ObjectOriginAxis: SCNNode {
    
    private var sceneView: SCNView
    
    init(sceneView: SCNView) {
        self.sceneView = sceneView
        super.init()
        
        let node = SCNNode()
        node.name = "axis"
        
        // x軸
        node.addChildNode(makeXAxisNode())
        // y軸
        node.addChildNode(makeYAxisNode())
        // z軸
        node.addChildNode(makeZAxisNode())
        
        node.addChildNode(makeXAxisCurveNode())
        node.addChildNode(makeYAxisCurveNode())
        node.addChildNode(makeZAxisCurveNode())
        
        addChildNode(node)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 原点を作成する
    func makeOriginNode() -> SCNNode {
        let sphere = makeSphereNode(radius: 0.005)
        sphere.position = SCNVector3(0, 0, 0)
        return sphere
    }
    
    /// スフィア(球体)ノードを追加する
    func makeSphereNode(radius: CGFloat = 1.0) -> SCNNode {
        let sphere: SCNGeometry = SCNSphere(radius: radius)
        //sphere.firstMaterial?.diffuse.contents = UIColor.blue
        let sphereNode = SCNNode(geometry: sphere)
        return sphereNode
    }
    
    
    /// 座標軸ノードを作成する
    func makeAxisNode() -> SCNNode {
        let node = SCNNode()
        node.name = "axis"
        
        // x軸
        node.addChildNode(makeXAxisNode())
        // y軸
        node.addChildNode(makeYAxisNode())
        // z軸
        node.addChildNode(makeZAxisNode())
        
        node.addChildNode(makeXAxisCurveNode())
        node.addChildNode(makeYAxisCurveNode())
        node.addChildNode(makeZAxisCurveNode())
        
        return node
    }
    
    /// x軸ノードを作成する
    func makeXAxisNode(radius: CGFloat = 0.005, height: CGFloat = 0.25, color: UIColor = .red) -> SCNNode {
        let cylinderNode = makeCylinderNode(radius: radius, height: height, color: color)
        cylinderNode.name = ("XAxis")
        // z軸を基準に90度(0.5π)回転する
        cylinderNode.simdRotate(
            by: simd_quatf(
                angle: .pi * 0.5, // 回転角
                axis: simd_normalize(simd_float3(0, 0, 1)) // 回転軸
            ),
            aroundTarget: simd_float3(0, 0, 0)
        )
        // 原点まで移動する
        cylinderNode.position = SCNVector3(height * 0.5, 0, 0)
        return cylinderNode
    }
    
    /// y軸ノードを作成する
    func makeYAxisNode(radius: CGFloat = 0.005, height: CGFloat = 0.25, color: UIColor = .green) -> SCNNode {
        let cylinderNode = makeCylinderNode(radius: radius, height: height, color: color)
        cylinderNode.name = ("YAxis")
        // 原点まで移動する
        cylinderNode.position = SCNVector3(0, height * 0.5, 0)
        return cylinderNode
    }
    
    /// z軸ノードを作成する
    func makeZAxisNode(radius: CGFloat = 0.005, height: CGFloat = 0.25, color: UIColor = .blue) -> SCNNode {
        let cylinderNode = makeCylinderNode(radius: radius, height: height, color: color)
        cylinderNode.name = ("ZAxis")
        // x軸を基準に90度(0.5π)回転する
        cylinderNode.simdRotate(
            by: simd_quatf(
                angle: .pi * 0.5, // 回転角
                axis: simd_normalize(simd_float3(1, 0, 0)) // 回転軸
            ),
            aroundTarget: simd_float3(0, 0, 0)
        )
        // 原点まで移動する
        cylinderNode.position = SCNVector3(0, 0, height * 0.5)
        return cylinderNode
    }
    
    /// シリンダー(円柱)ノードを作成する
    func makeCylinderNode(radius: CGFloat, height: CGFloat, color: UIColor = .white) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        let node = SCNNode(geometry: cylinder)
        let material = SCNMaterial()
        material.diffuse.contents = color
        node.geometry?.firstMaterial = material
        return node
    }
    
    
    func makeXAxisCurveNode() -> SCNNode {
        let curveNode = makeCurveNode(color: .red)
        curveNode.name = "XCurve"
        // z軸を基準に90度(0.5π)回転する
            curveNode.simdRotate(
            by: simd_quatf(
                angle: -.pi * 0.5, // 回転角
                axis: simd_normalize(simd_float3(0, 1, 0)) // 回転軸
            ),
            aroundTarget: simd_float3(0, 0, 0)
        )
        
        return curveNode
    }
    
    func makeYAxisCurveNode() -> SCNNode {
        let curveNode = makeCurveNode(color: .green)
        curveNode.name = "YCurve"
        // x軸を基準に90度(0.5π)回転する
        curveNode.simdRotate(
            by: simd_quatf(
                angle: .pi * 0.5, // 回転角
                axis: simd_normalize(simd_float3(1, 0, 0)) // 回転軸
            ),
            aroundTarget: simd_float3(0, 0, 0)
        )
        
        return curveNode
    }
    
    func makeZAxisCurveNode() -> SCNNode {
        let curveNode = makeCurveNode(color: .blue)
        curveNode.name = "ZCurve"
        
        return curveNode
    }
    
    func makeCurveNode(color: UIColor) -> SCNNode {
        
        //let path = UIBezierPath(arcCenter: CGPoint(x: 0, y: 0), radius: 0.25, startAngle: 0, endAngle: CGFloat(Float.pi)*2, clockwise: true)
        let path = UIBezierPath()
        //path.move(to: CGPoint(x: 1, y: 0))
        path.addArc(withCenter: CGPoint(x: 0, y: 0), radius: 0.25, startAngle: 0, endAngle: CGFloat(Float.pi)/2, clockwise: true)
        path.flatness = 0
        //path.lineWidth = 2
        //path.fill(with: .clear, alpha: 1.0)
        //path.stroke()
        //path.stroke(with: .clear, alpha: 0)
        //path.close()
    
        // pathを渡してジオメトリ作成
        let geometry = SCNShape(path: path, extrusionDepth: 0.005)
        // マテリアルを当てる
        geometry.firstMaterial?.diffuse.contents = color
        // Nodeに渡してNodeをイニシャライズ
        let node = SCNNode(geometry: geometry)
        node.opacity = 0.3
        
        return node
    }
}

