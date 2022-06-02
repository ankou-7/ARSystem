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
    private var models: Navi_Modelname //List<anchor_data>
    private var texImage: UIImage
    
    let decoder = JSONDecoder()
    let tex_node = SCNNode()
    
    private var url: URL!
    
    init(models: Navi_Modelname, texImage: UIImage) {
        self.models = models
        self.texImage = texImage
        super.init()
        
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        buildTexMesh()
        tex_node.name = "meshNode"
        addChildNode(tex_node)
    }
    
    func buildTexMesh() {
        
        for i in 0..<models.meshNum {
            let texcoordsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/texcoords\(i).data")
            let vertexPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/vertex\(i).data")
            let normalsPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/normals\(i).data")
            let facesPath = url.appendingPathComponent("\(models.dayString)/\(ModelManagement.modelID)/faces\(i).data")
            
            let vertexData = try! Data(contentsOf: vertexPath) //result[i].vertices!
            let normalData = try! Data(contentsOf: normalsPath) //result[i].normals!
            
            let faces = (try? decoder.decode([Int32].self, from: try! Data(contentsOf: facesPath)))!
            let texcoords = (try? decoder.decode([SIMD2<Float>].self, from: try! Data(contentsOf: texcoordsPath)))!
            
            let count = faces.count
            
//            print("vertexData\(i) : \(vertexData)")
//            print("normalData\(i) : \(normalData)")
//            print("faceData\(i) : \(faces)")
//            print("texData\(i) : \(texcoords)")
            
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
