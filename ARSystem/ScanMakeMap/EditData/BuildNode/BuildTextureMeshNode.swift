//
//  BuildTextureMeshNode.swift
//  ARMesh
//
//  Created by yasue kouki on 2022/04/20.
//

import SceneKit
import ARKit
import RealmSwift

class BuildTextureMeshNode: SCNNode {
    private var result: List<anchor_data>
    private var texImage: UIImage
    
    let decoder = JSONDecoder()
    let tex_node = SCNNode()
    
    init(result: List<anchor_data>, texImage: UIImage) {
        self.result = result
        self.texImage = texImage
        super.init()
        
        buildTexMesh()
        tex_node.name = "meshNode"
        addChildNode(tex_node)
    }
    
    func buildTexMesh() {
        for i in 0..<result.count {
            let vertexData = result[i].vertices!
            let normalData = result[i].normals!
            let count = result[i].vertice_count
            
            let faces = (try? decoder.decode([Int32].self, from: result[i].faces))!
            let texcoords = (try? decoder.decode([SIMD2<Float>].self, from: result[i].texcoords))!
            
            print("vertexData\(i) : \(vertexData)")
            print("normalData\(i) : \(normalData)")
            print("faceData\(i) : \(result[i].faces!)")
            print("texData\(i) : \(result[i].texcoords!)")
            
            let verticeSource = SCNGeometrySource(
                data: vertexData,
                semantic: SCNGeometrySource.Semantic.vertex,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let normalSource = SCNGeometrySource(
                data: normalData,
                semantic: SCNGeometrySource.Semantic.normal,
                vectorCount: count,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: MemoryLayout<Float>.size * 3,
                dataStride: MemoryLayout<SIMD3<Float>>.size
            )
            let faceSource = SCNGeometryElement(indices: faces, primitiveType: .triangles)
            let textureCoordinates = SCNGeometrySource(textureCoordinates: texcoords)

            let nodeGeometry = SCNGeometry(sources: [verticeSource, normalSource, textureCoordinates], elements: [faceSource])
            nodeGeometry.firstMaterial?.diffuse.contents = texImage
            

            let node = SCNNode(geometry: nodeGeometry)
            tex_node.addChildNode(node)
        }
        print("load完了")
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
