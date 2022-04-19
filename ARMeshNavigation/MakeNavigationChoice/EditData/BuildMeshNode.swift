//
//  BuildMeshNode.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import ARKit

class BuildMeshNode: SCNNode {
    private var anchors: [ARMeshAnchor]
    let tex_node = SCNNode()
    
    init(anchors: [ARMeshAnchor]) {
        self.anchors = anchors
        super.init()
        
        build()
        tex_node.name = "meshNode"
        addChildNode(tex_node)
    }
    
    func build() {
        for mesh_anchor in anchors {
            let verticles = mesh_anchor.geometry.vertices
            let normals = mesh_anchor.geometry.normals
            let faces = mesh_anchor.geometry.faces
            
            let verticesSource = SCNGeometrySource(buffer: verticles.buffer, vertexFormat: verticles.format, semantic: .vertex, vertexCount: verticles.count, dataOffset: verticles.offset, dataStride: verticles.stride)
            let normalsSource = SCNGeometrySource(buffer: normals.buffer, vertexFormat: normals.format, semantic: .normal, vertexCount: normals.count, dataOffset: normals.offset, dataStride: normals.stride)
            let data = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
            let facesElement = SCNGeometryElement(data: data, primitiveType: SCNGeometryPrimitiveType.of(faces.primitiveType), primitiveCount: faces.count, bytesPerIndex: faces.bytesPerIndex)
            let sources = [verticesSource, normalsSource]
            
            let nodeGeometry = SCNGeometry(sources: sources, elements: [facesElement])
            
            let defaultMaterial = SCNMaterial()
            defaultMaterial.fillMode = .lines
            defaultMaterial.diffuse.contents = UIColor.green
            nodeGeometry.materials = [defaultMaterial]
            
            let node = SCNNode(geometry: nodeGeometry)
            node.simdTransform = mesh_anchor.transform
            tex_node.addChildNode(node)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
